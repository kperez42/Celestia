/**
 * Photo Verification Module (Manual Review Only)
 *
 * NOTE: Automated face verification has been removed.
 * ID verification is now handled through manual admin review.
 *
 * This module provides utilities for:
 * - Rate limiting verification attempts
 * - Recording verification attempts
 * - Tracking verification stats
 * - Managing verification expiry
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Firestore and Storage instances
const db = admin.firestore();
const storage = admin.storage();

// Constants
const MAX_VERIFICATION_ATTEMPTS_PER_DAY = 3;
const VERIFICATION_EXPIRY_DAYS = 365; // Re-verify yearly

/**
 * Check if user can attempt verification (rate limiting)
 * @param {string} userId - User ID
 * @returns {boolean} Can verify
 */
async function checkVerificationRateLimit(userId) {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const attemptsSnapshot = await db.collection('verification_attempts')
    .where('userId', '==', userId)
    .where('timestamp', '>', oneDayAgo)
    .get();

  const attemptCount = attemptsSnapshot.size;

  functions.logger.info('Verification rate limit check', {
    userId,
    attempts: attemptCount,
    limit: MAX_VERIFICATION_ATTEMPTS_PER_DAY
  });

  return attemptCount < MAX_VERIFICATION_ATTEMPTS_PER_DAY;
}

/**
 * Record verification attempt
 * @param {string} userId - User ID
 * @param {boolean} success - Was verification successful
 * @param {string} reason - Reason for failure or success
 */
async function recordVerificationAttempt(userId, success, reason) {
  await db.collection('verification_attempts').add({
    userId,
    success,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  });

  // Log to analytics
  if (!success) {
    functions.logger.warning('Verification attempt failed', {
      userId,
      reason
    });
  }
}

/**
 * Check if user's verification has expired
 * @param {string} userId - User ID
 * @returns {boolean} Has verification expired
 */
async function isVerificationExpired(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return true;
  }

  const userData = userDoc.data();

  if (!userData.isVerified || !userData.verificationExpiry) {
    return true;
  }

  const expiryDate = userData.verificationExpiry.toDate();
  return new Date() > expiryDate;
}

/**
 * Get verification statistics
 * @param {number} days - Number of days to look back
 * @returns {object} Verification stats
 */
async function getVerificationStats(days = 30) {
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const attemptsSnapshot = await db.collection('verification_attempts')
    .where('timestamp', '>', startDate)
    .get();

  const attempts = attemptsSnapshot.docs.map(doc => doc.data());

  const totalAttempts = attempts.length;
  const successfulAttempts = attempts.filter(a => a.success).length;
  const failedAttempts = totalAttempts - successfulAttempts;
  const successRate = totalAttempts > 0 ? (successfulAttempts / totalAttempts) * 100 : 0;

  // Group failures by reason
  const failureReasons = {};
  attempts.filter(a => !a.success).forEach(attempt => {
    failureReasons[attempt.reason] = (failureReasons[attempt.reason] || 0) + 1;
  });

  // Get verified users count
  const verifiedUsersSnapshot = await db.collection('users')
    .where('isVerified', '==', true)
    .get();

  // Get pending verifications count
  const pendingVerificationsSnapshot = await db.collection('pendingVerifications')
    .where('status', '==', 'pending')
    .get();

  return {
    totalAttempts,
    successfulAttempts,
    failedAttempts,
    successRate: successRate.toFixed(2),
    failureReasons,
    verifiedUsers: verifiedUsersSnapshot.size,
    pendingVerifications: pendingVerificationsSnapshot.size
  };
}

/**
 * Approve a pending verification (admin function)
 * @param {string} userId - User ID to approve
 * @param {string} adminId - Admin performing the approval
 * @returns {object} Result
 */
async function approveVerification(userId, adminId) {
  try {
    functions.logger.info('Approving verification', { userId, adminId });

    // Update user's verification status
    await db.collection('users').doc(userId).update({
      isVerified: true,
      idVerified: true,
      idVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationExpiry: new Date(Date.now() + VERIFICATION_EXPIRY_DAYS * 24 * 60 * 60 * 1000),
      verificationMethods: admin.firestore.FieldValue.arrayUnion(['manual_id']),
      verificationStatus: 'verified',
      trustScore: 70 // Base (20) + ID verification (50)
    });

    // Update pending verification record
    await db.collection('pendingVerifications').doc(userId).update({
      status: 'approved',
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: adminId
    });

    // Record the approval
    await recordVerificationAttempt(userId, true, 'manual_approved');

    functions.logger.info('✅ Verification approved', { userId, adminId });

    return {
      success: true,
      message: 'Verification approved successfully'
    };
  } catch (error) {
    functions.logger.error('Failed to approve verification', {
      userId,
      adminId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Reject a pending verification (admin function)
 * @param {string} userId - User ID to reject
 * @param {string} adminId - Admin performing the rejection
 * @param {string} reason - Reason for rejection
 * @returns {object} Result
 */
async function rejectVerification(userId, adminId, reason) {
  try {
    functions.logger.info('Rejecting verification', { userId, adminId, reason });

    // Update user's verification status
    await db.collection('users').doc(userId).update({
      idVerificationRejected: true,
      idVerificationRejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      idVerificationRejectionReason: reason
    });

    // Update pending verification record
    await db.collection('pendingVerifications').doc(userId).update({
      status: 'rejected',
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: adminId,
      rejectionReason: reason
    });

    // Record the rejection
    await recordVerificationAttempt(userId, false, `manual_rejected: ${reason}`);

    functions.logger.info('❌ Verification rejected', { userId, adminId, reason });

    return {
      success: true,
      message: 'Verification rejected'
    };
  } catch (error) {
    functions.logger.error('Failed to reject verification', {
      userId,
      adminId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get pending verifications for admin review
 * @param {number} limit - Max number to return
 * @returns {Array} Pending verifications
 */
async function getPendingVerifications(limit = 50) {
  const snapshot = await db.collection('pendingVerifications')
    .where('status', '==', 'pending')
    .orderBy('submittedAt', 'asc')
    .limit(limit)
    .get();

  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
}

module.exports = {
  checkVerificationRateLimit,
  recordVerificationAttempt,
  isVerificationExpired,
  getVerificationStats,
  approveVerification,
  rejectVerification,
  getPendingVerifications
};
