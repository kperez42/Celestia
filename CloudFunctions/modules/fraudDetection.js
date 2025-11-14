/**
 * Fraud Detection Module
 * Advanced fraud detection and prevention for payment systems
 *
 * SECURITY CRITICAL: This module prevents revenue theft through:
 * - Refund abuse detection
 * - Jailbreak/modified app detection
 * - Receipt reuse prevention
 * - Promotional code abuse prevention
 * - Behavioral pattern analysis
 * - Device fingerprinting
 * - Velocity checks
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const crypto = require('crypto');

// Fraud detection thresholds
const FRAUD_THRESHOLDS = {
  // Refund patterns
  MAX_REFUNDS_WARNING: 2,
  MAX_REFUNDS_CRITICAL: 3,
  REFUND_RATE_SUSPICIOUS: 0.5, // 50% of purchases refunded

  // Account age (days)
  NEW_ACCOUNT_HIGH_RISK: 1,
  NEW_ACCOUNT_MEDIUM_RISK: 7,

  // Validation failures
  MAX_VALIDATION_FAILURES_WARNING: 3,
  MAX_VALIDATION_FAILURES_CRITICAL: 5,

  // Promotional abuse
  MAX_PROMO_CODES_PER_USER: 3,

  // Fraud scores
  FRAUD_SCORE_LOW: 30,
  FRAUD_SCORE_MEDIUM: 50,
  FRAUD_SCORE_HIGH: 70,
  FRAUD_SCORE_CRITICAL: 85,

  // Jailbreak detection
  JAILBREAK_RISK_MEDIUM: 0.4,
  JAILBREAK_RISK_HIGH: 0.7,

  // Velocity checks (time-based limits)
  MAX_PURCHASES_PER_HOUR: 3,
  MAX_PURCHASES_PER_DAY: 10,

  // Device fingerprint
  MAX_USERS_PER_DEVICE: 3,

  // Geographic anomalies
  RAPID_LOCATION_CHANGE_HOURS: 2, // Flag if location changes too fast
};

/**
 * Calculate comprehensive fraud score for a user/transaction
 * @param {string} userId - User ID
 * @param {object} context - Transaction context
 * @returns {Promise<number>} Fraud score 0-100
 */
async function calculateFraudScore(userId, context = {}) {
  const db = admin.firestore();
  let score = 0;
  const reasons = [];

  try {
    // 1. REFUND HISTORY ANALYSIS (0-30 points)
    const refundCount = await getRefundCount(userId);
    if (refundCount > FRAUD_THRESHOLDS.MAX_REFUNDS_CRITICAL) {
      score += 30;
      reasons.push(`Critical refund count: ${refundCount}`);
    } else if (refundCount > FRAUD_THRESHOLDS.MAX_REFUNDS_WARNING) {
      score += 20;
      reasons.push(`High refund count: ${refundCount}`);
    } else if (refundCount > 0) {
      score += 10;
      reasons.push(`Previous refunds: ${refundCount}`);
    }

    // 2. VALIDATION FAILURE HISTORY (0-20 points)
    const validationFailures = await getValidationFailureCount(userId);
    if (validationFailures > FRAUD_THRESHOLDS.MAX_VALIDATION_FAILURES_CRITICAL) {
      score += 20;
      reasons.push(`Critical validation failures: ${validationFailures}`);
    } else if (validationFailures > FRAUD_THRESHOLDS.MAX_VALIDATION_FAILURES_WARNING) {
      score += 10;
      reasons.push(`Multiple validation failures: ${validationFailures}`);
    }

    // 3. ACCOUNT AGE ANALYSIS (0-15 points)
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const accountAge = Date.now() - userDoc.data().timestamp?.toDate().getTime();
      const daysSinceCreation = accountAge / (1000 * 60 * 60 * 24);

      if (daysSinceCreation < FRAUD_THRESHOLDS.NEW_ACCOUNT_HIGH_RISK) {
        score += 15;
        reasons.push(`Brand new account (<1 day)`);
      } else if (daysSinceCreation < FRAUD_THRESHOLDS.NEW_ACCOUNT_MEDIUM_RISK) {
        score += 10;
        reasons.push(`New account (<7 days)`);
      }
    }

    // 4. JAILBREAK/MODIFIED APP DETECTION (0-25 points)
    if (context.jailbreakRisk !== undefined) {
      if (context.jailbreakRisk > FRAUD_THRESHOLDS.JAILBREAK_RISK_HIGH) {
        score += 25;
        reasons.push(`High jailbreak risk: ${context.jailbreakRisk.toFixed(2)}`);
      } else if (context.jailbreakRisk > FRAUD_THRESHOLDS.JAILBREAK_RISK_MEDIUM) {
        score += 15;
        reasons.push(`Medium jailbreak risk: ${context.jailbreakRisk.toFixed(2)}`);
      }
    }

    // 5. PROMOTIONAL CODE ABUSE (0-20 points)
    if (context.isPromotional) {
      const promoCount = await getPromotionalPurchaseCount(userId);
      if (promoCount > FRAUD_THRESHOLDS.MAX_PROMO_CODES_PER_USER) {
        score += 20;
        reasons.push(`Excessive promo code use: ${promoCount}`);
      } else if (promoCount > 2) {
        score += 10;
        reasons.push(`Multiple promo codes: ${promoCount}`);
      }
    }

    // 6. RAPID PURCHASE/REFUND CYCLES (0-30 points)
    const rapidCycleDetected = await detectRapidPurchaseRefundCycle(userId);
    if (rapidCycleDetected) {
      score += 30;
      reasons.push('Rapid purchase/refund cycle detected');
    }

    // 7. PREVIOUS FRAUD ATTEMPTS (0-25 points)
    const fraudAttempts = await getFraudAttemptCount(userId);
    if (fraudAttempts > 0) {
      score += 25 * Math.min(fraudAttempts, 3);
      reasons.push(`Previous fraud attempts: ${fraudAttempts}`);
    }

    // 8. VELOCITY CHECKS (0-20 points)
    const velocityRisk = await checkVelocity(userId);
    if (velocityRisk > 0) {
      score += velocityRisk;
      reasons.push(`Velocity anomaly detected`);
    }

    // 9. DEVICE FINGERPRINT ANALYSIS (0-15 points)
    if (context.deviceFingerprint) {
      const deviceRisk = await analyzeDeviceFingerprint(context.deviceFingerprint);
      score += deviceRisk;
      if (deviceRisk > 0) {
        reasons.push(`Suspicious device fingerprint`);
      }
    }

    // 10. BEHAVIORAL ANOMALIES (0-15 points)
    const behaviorScore = await analyzeBehavioralPatterns(userId, context);
    score += behaviorScore;
    if (behaviorScore > 0) {
      reasons.push(`Behavioral anomalies detected`);
    }

    // Cap at 100
    const finalScore = Math.min(score, 100);

    // Log fraud score calculation
    functions.logger.info('Fraud score calculated', {
      userId,
      score: finalScore,
      reasons,
      context: {
        transactionId: context.transactionId,
        productId: context.productId
      }
    });

    return finalScore;

  } catch (error) {
    functions.logger.error('Error calculating fraud score', {
      error: error.message,
      userId
    });
    return 0; // Fail open - don't block legitimate users on error
  }
}

/**
 * Enhanced jailbreak detection with multiple indicators
 * @param {object} receipt - Receipt data from Apple
 * @param {object} deviceInfo - Optional device information
 * @returns {number} Risk score 0-1
 */
function detectJailbreakIndicators(receipt, deviceInfo = null) {
  let riskScore = 0;
  const indicators = [];

  // 1. Check bundle ID for suspicious patterns
  const bundleId = receipt?.bundle_id || '';
  const suspiciousPatterns = [
    'cracked', 'hacked', 'pirate', 'modded', 'jailbreak',
    'cydia', 'sileo', 'unc0ver', 'checkra1n', 'taurine'
  ];

  for (const pattern of suspiciousPatterns) {
    if (bundleId.toLowerCase().includes(pattern)) {
      riskScore += 0.5;
      indicators.push(`Suspicious bundle ID: ${pattern}`);
      break;
    }
  }

  // 2. Environment mismatch detection
  const environment = receipt?.environment;
  if (environment === 'Sandbox' && process.env.NODE_ENV === 'production') {
    riskScore += 0.3;
    indicators.push('Environment mismatch: sandbox in production');
  }

  // 3. Check for missing or suspicious receipt fields
  if (!receipt?.receipt_creation_date) {
    riskScore += 0.2;
    indicators.push('Missing receipt creation date');
  }

  // 4. Check for unusual in_app structure (common in cracked receipts)
  if (receipt?.in_app && Array.isArray(receipt.in_app) && receipt.in_app.length > 50) {
    riskScore += 0.3;
    indicators.push('Abnormally large in_app array');
  }

  // 5. Device information analysis (if provided)
  if (deviceInfo) {
    // Check for common jailbreak detection bypass indicators
    if (deviceInfo.isJailbroken === true) {
      riskScore += 0.8;
      indicators.push('Device reports jailbreak');
    }

    // Check for suspicious app file paths
    const suspiciousPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt'
    ];

    if (deviceInfo.suspiciousPaths && deviceInfo.suspiciousPaths.some(path =>
      suspiciousPaths.some(sp => path.includes(sp))
    )) {
      riskScore += 0.6;
      indicators.push('Jailbreak files detected');
    }

    // Check for URL scheme manipulation
    if (deviceInfo.canOpenCydia) {
      riskScore += 0.7;
      indicators.push('Can open Cydia URL scheme');
    }
  }

  // 6. Receipt age anomaly
  if (receipt?.receipt_creation_date_ms) {
    const receiptAge = Date.now() - parseInt(receipt.receipt_creation_date_ms);
    const daysSinceCreation = receiptAge / (1000 * 60 * 60 * 24);

    // Very old receipts being reused
    if (daysSinceCreation > 365) {
      riskScore += 0.2;
      indicators.push(`Very old receipt: ${daysSinceCreation.toFixed(0)} days`);
    }
  }

  // 7. Check for duplicate original_transaction_id across different bundle IDs
  // (This would be checked in the calling function with database access)

  const finalScore = Math.min(riskScore, 1.0);

  if (indicators.length > 0) {
    functions.logger.warn('Jailbreak indicators detected', {
      riskScore: finalScore,
      indicators,
      bundleId
    });
  }

  return finalScore;
}

/**
 * Check for rapid purchase/refund cycles (fraud pattern)
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} True if pattern detected
 */
async function detectRapidPurchaseRefundCycle(userId) {
  const db = admin.firestore();

  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const recentPurchases = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('purchaseDate', '>', thirtyDaysAgo)
      .get();

    const refundedPurchases = recentPurchases.docs.filter(doc =>
      doc.data().refunded === true
    );

    // Pattern 1: More than 50% of purchases were refunded (minimum 3 purchases)
    if (recentPurchases.size >= 3 &&
        refundedPurchases.length / recentPurchases.size > FRAUD_THRESHOLDS.REFUND_RATE_SUSPICIOUS) {
      functions.logger.warn('Rapid refund pattern detected', {
        userId,
        totalPurchases: recentPurchases.size,
        refundedPurchases: refundedPurchases.length,
        refundRate: (refundedPurchases.length / recentPurchases.size * 100).toFixed(2) + '%'
      });
      return true;
    }

    // Pattern 2: Purchase-refund within 24 hours (multiple times)
    let rapidRefunds = 0;
    for (const purchaseDoc of recentPurchases.docs) {
      const data = purchaseDoc.data();
      if (data.refunded && data.refundDate && data.purchaseDate) {
        const timeDiff = data.refundDate.toDate().getTime() - data.purchaseDate.toDate().getTime();
        const hoursDiff = timeDiff / (1000 * 60 * 60);

        if (hoursDiff < 24) {
          rapidRefunds++;
        }
      }
    }

    if (rapidRefunds >= 2) {
      functions.logger.warn('Multiple rapid refunds detected', {
        userId,
        rapidRefunds
      });
      return true;
    }

    return false;

  } catch (error) {
    functions.logger.error('Error detecting rapid cycles', { error: error.message });
    return false;
  }
}

/**
 * Check velocity (purchase frequency) for suspicious patterns
 * @param {string} userId - User ID
 * @returns {Promise<number>} Risk score 0-20
 */
async function checkVelocity(userId) {
  const db = admin.firestore();
  let riskScore = 0;

  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Check purchases in last hour
    const hourlyPurchases = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('purchaseDate', '>', oneHourAgo)
      .get();

    if (hourlyPurchases.size > FRAUD_THRESHOLDS.MAX_PURCHASES_PER_HOUR) {
      riskScore += 15;
      functions.logger.warn('Velocity: Too many purchases per hour', {
        userId,
        count: hourlyPurchases.size
      });
    }

    // Check purchases in last 24 hours
    const dailyPurchases = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('purchaseDate', '>', oneDayAgo)
      .get();

    if (dailyPurchases.size > FRAUD_THRESHOLDS.MAX_PURCHASES_PER_DAY) {
      riskScore += 10;
      functions.logger.warn('Velocity: Too many purchases per day', {
        userId,
        count: dailyPurchases.size
      });
    }

    return riskScore;

  } catch (error) {
    functions.logger.error('Error checking velocity', { error: error.message });
    return 0;
  }
}

/**
 * Analyze device fingerprint for suspicious patterns
 * @param {string} deviceFingerprint - Device fingerprint hash
 * @returns {Promise<number>} Risk score 0-15
 */
async function analyzeDeviceFingerprint(deviceFingerprint) {
  const db = admin.firestore();
  let riskScore = 0;

  try {
    // Check how many users are using this device
    const deviceUsers = await db.collection('users')
      .where('deviceFingerprint', '==', deviceFingerprint)
      .get();

    if (deviceUsers.size > FRAUD_THRESHOLDS.MAX_USERS_PER_DEVICE) {
      riskScore += 15;
      functions.logger.warn('Device fingerprint: Multiple users on same device', {
        deviceFingerprint: deviceFingerprint.substring(0, 8) + '...',
        userCount: deviceUsers.size
      });
    } else if (deviceUsers.size > 2) {
      riskScore += 8;
    }

    return riskScore;

  } catch (error) {
    functions.logger.error('Error analyzing device fingerprint', { error: error.message });
    return 0;
  }
}

/**
 * Analyze behavioral patterns for anomalies
 * @param {string} userId - User ID
 * @param {object} context - Current context
 * @returns {Promise<number>} Risk score 0-15
 */
async function analyzeBehavioralPatterns(userId, context) {
  const db = admin.firestore();
  let riskScore = 0;

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return 0;
    }

    const userData = userDoc.data();

    // 1. Purchase before profile completion (suspicious)
    if (!userData.profileComplete && !userData.photos?.length) {
      riskScore += 10;
      functions.logger.info('Behavioral: Purchase before profile completion', { userId });
    }

    // 2. No prior app usage before purchase (bot-like behavior)
    if (!userData.lastActive) {
      riskScore += 8;
      functions.logger.info('Behavioral: No prior app usage', { userId });
    }

    // 3. High-value purchase on first transaction
    if (context.productId && context.productId.includes('lifetime')) {
      const previousPurchases = await db.collection('purchases')
        .where('userId', '==', userId)
        .get();

      if (previousPurchases.size === 0) {
        riskScore += 5;
        functions.logger.info('Behavioral: High-value first purchase', { userId });
      }
    }

    return riskScore;

  } catch (error) {
    functions.logger.error('Error analyzing behavioral patterns', { error: error.message });
    return 0;
  }
}

/**
 * Get refund count for user
 */
async function getRefundCount(userId) {
  const db = admin.firestore();
  const refunds = await db.collection('purchases')
    .where('userId', '==', userId)
    .where('refunded', '==', true)
    .get();
  return refunds.size;
}

/**
 * Get validation failure count for user
 */
async function getValidationFailureCount(userId) {
  const db = admin.firestore();
  const failures = await db.collection('fraud_logs')
    .where('userId', '==', userId)
    .where('eventType', '==', 'validation_failure')
    .get();
  return failures.size;
}

/**
 * Get promotional purchase count for user
 */
async function getPromotionalPurchaseCount(userId) {
  const db = admin.firestore();
  const promos = await db.collection('purchases')
    .where('userId', '==', userId)
    .where('isPromotional', '==', true)
    .get();
  return promos.size;
}

/**
 * Get fraud attempt count for user
 */
async function getFraudAttemptCount(userId) {
  const db = admin.firestore();
  const attempts = await db.collection('fraud_logs')
    .where('userId', '==', userId)
    .where('eventType', '==', 'fraud_attempt')
    .get();
  return attempts.size;
}

/**
 * Check for duplicate receipt usage
 * @param {string} transactionId - Transaction ID
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} True if duplicate
 */
async function checkReceiptDuplicate(transactionId, userId) {
  const db = admin.firestore();

  try {
    const existingPurchase = await db.collection('purchases')
      .where('transactionId', '==', transactionId)
      .get();

    if (!existingPurchase.empty) {
      const existingUserId = existingPurchase.docs[0].data().userId;

      // Same user re-validating is OK, different user is fraud
      if (existingUserId !== userId) {
        functions.logger.error('FRAUD: Receipt used by different user', {
          transactionId,
          originalUser: existingUserId,
          fraudUser: userId
        });
        return true;
      }
    }

    return false;
  } catch (error) {
    functions.logger.error('Error checking receipt duplicate', { error: error.message });
    return false;
  }
}

/**
 * Check for promotional code abuse
 * @param {string} userId - User ID
 * @param {string} promoCode - Promotional code
 * @returns {Promise<boolean>} True if abuse detected
 */
async function checkPromotionalCodeAbuse(userId, promoCode) {
  const db = admin.firestore();

  try {
    // Check how many times this user has used promotional codes
    const promoUsage = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('isPromotional', '==', true)
      .get();

    // Flag if user has used more than threshold
    if (promoUsage.size > FRAUD_THRESHOLDS.MAX_PROMO_CODES_PER_USER) {
      functions.logger.warn('Promo code abuse detected', {
        userId,
        promoCount: promoUsage.size
      });
      return true;
    }

    // Check if the same promo code was used multiple times (shouldn't happen)
    const samePromoUsage = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('promotionalOfferId', '==', promoCode)
      .get();

    if (samePromoUsage.size > 1) {
      functions.logger.warn('Same promo code used multiple times', {
        userId,
        promoCode
      });
      return true;
    }

    // Check rapid promotional purchases (within 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentPromoUsage = promoUsage.docs.filter(doc => {
      const purchaseDate = doc.data().purchaseDate?.toDate();
      return purchaseDate && purchaseDate > oneDayAgo;
    });

    if (recentPromoUsage.length > 2) {
      functions.logger.warn('Rapid promo code usage detected', {
        userId,
        count: recentPromoUsage.length
      });
      return true;
    }

    return false;
  } catch (error) {
    functions.logger.error('Error checking promo code abuse', { error: error.message });
    return false;
  }
}

/**
 * Track fraud attempt in logs
 * @param {string} userId - User ID
 * @param {string} fraudType - Type of fraud detected
 * @param {object} details - Additional details
 */
async function trackFraudAttempt(userId, fraudType, details) {
  const db = admin.firestore();

  try {
    await db.collection('fraud_logs').add({
      userId,
      eventType: 'fraud_attempt',
      fraudType,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      severity: 'high'
    });

    // Create critical admin alert
    await db.collection('admin_alerts').add({
      alertType: 'fraud_detected',
      details: {
        userId,
        fraudType,
        details
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false,
      priority: 'critical'
    });

    functions.logger.error('🚨 FRAUD ATTEMPT LOGGED', {
      userId,
      fraudType,
      details
    });

  } catch (error) {
    functions.logger.error('Error tracking fraud attempt', { error: error.message });
  }
}

/**
 * Track validation failure
 * @param {string} userId - User ID
 * @param {number} statusCode - Status code
 * @param {string} reason - Reason
 * @param {string} details - Additional details
 */
async function trackValidationFailure(userId, statusCode, reason, details = null) {
  const db = admin.firestore();

  try {
    await db.collection('fraud_logs').add({
      userId,
      eventType: 'validation_failure',
      statusCode,
      reason,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    functions.logger.error('Error tracking validation failure', { error: error.message });
  }
}

/**
 * Flag transaction for manual review
 * @param {string} userId - User ID
 * @param {object} transaction - Transaction data
 * @param {number} fraudScore - Fraud score
 */
async function flagTransactionForReview(userId, transaction, fraudScore) {
  const db = admin.firestore();

  try {
    await db.collection('flagged_transactions').add({
      userId,
      transactionId: transaction.transaction_id,
      productId: transaction.product_id,
      fraudScore,
      details: transaction,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      reviewed: false,
      status: 'pending'
    });

    // Alert admins for high-risk transactions
    if (fraudScore > FRAUD_THRESHOLDS.FRAUD_SCORE_HIGH) {
      await db.collection('admin_alerts').add({
        alertType: 'high_risk_transaction',
        details: {
          userId,
          transactionId: transaction.transaction_id,
          fraudScore
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        acknowledged: false,
        priority: 'critical'
      });
    }

    functions.logger.warn('Transaction flagged for review', {
      userId,
      transactionId: transaction.transaction_id,
      fraudScore
    });

  } catch (error) {
    functions.logger.error('Error flagging transaction', { error: error.message });
  }
}

/**
 * Generate device fingerprint from device information
 * @param {object} deviceInfo - Device information
 * @returns {string} Device fingerprint hash
 */
function generateDeviceFingerprint(deviceInfo) {
  const {
    deviceModel,
    osVersion,
    appVersion,
    locale,
    timezone,
    vendorId
  } = deviceInfo;

  const fingerprintString = `${deviceModel}|${osVersion}|${appVersion}|${locale}|${timezone}|${vendorId}`;

  return crypto
    .createHash('sha256')
    .update(fingerprintString)
    .digest('hex');
}

module.exports = {
  calculateFraudScore,
  detectJailbreakIndicators,
  detectRapidPurchaseRefundCycle,
  checkVelocity,
  analyzeDeviceFingerprint,
  analyzeBehavioralPatterns,
  checkReceiptDuplicate,
  checkPromotionalCodeAbuse,
  trackFraudAttempt,
  trackValidationFailure,
  flagTransactionForReview,
  generateDeviceFingerprint,
  FRAUD_THRESHOLDS
};
