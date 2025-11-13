/**
 * Admin Dashboard Module
 * Provides analytics and moderation tools for administrators
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Gets platform statistics
 * @returns {object} Platform stats
 */
async function getStats() {
  const db = admin.firestore();

  try {
    // Get user stats
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs.map(doc => doc.data());

    const totalUsers = users.length;
    const activeUsers = users.filter(u => {
      const lastActive = u.lastActive?.toDate();
      const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      return lastActive && lastActive > dayAgo;
    }).length;

    const premiumUsers = users.filter(u => u.isPremium === true).length;
    const verifiedUsers = users.filter(u => u.isVerified === true).length;
    const suspendedUsers = users.filter(u => u.suspended === true).length;

    // Get match stats
    const matchesSnapshot = await db.collection('matches')
      .where('isActive', '==', true)
      .get();

    const totalMatches = matchesSnapshot.size;

    // Get message stats (last 24h)
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const messagesSnapshot = await db.collection('messages')
      .where('timestamp', '>', yesterday)
      .get();

    const messagesLast24h = messagesSnapshot.size;

    // Get revenue stats (last 30 days)
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const purchasesSnapshot = await db.collection('purchases')
      .where('purchaseDate', '>', thirtyDaysAgo)
      .where('validated', '==', true)
      .get();

    const purchases = purchasesSnapshot.docs.map(doc => doc.data());
    const revenue = calculateRevenue(purchases);

    // Get moderation stats
    const flaggedContentSnapshot = await db.collection('flagged_content')
      .where('reviewed', '==', false)
      .get();

    const pendingReviews = flaggedContentSnapshot.size;

    const warningsSnapshot = await db.collection('user_warnings')
      .where('acknowledged', '==', false)
      .get();

    const pendingWarnings = warningsSnapshot.size;

    // User growth (last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const newUsers = users.filter(u => {
      const timestamp = u.timestamp?.toDate();
      return timestamp && timestamp > sevenDaysAgo;
    }).length;

    // Match rate
    const matchRate = totalUsers > 0 ? (totalMatches / totalUsers * 2).toFixed(2) : 0;

    return {
      users: {
        total: totalUsers,
        active: activeUsers,
        premium: premiumUsers,
        verified: verifiedUsers,
        suspended: suspendedUsers,
        newLast7Days: newUsers
      },
      engagement: {
        totalMatches,
        matchRate: parseFloat(matchRate),
        messagesLast24h,
        averageMessagesPerMatch: totalMatches > 0 ? (messagesLast24h / totalMatches).toFixed(2) : 0
      },
      revenue: {
        last30Days: revenue.total,
        subscriptions: revenue.subscriptions,
        consumables: revenue.consumables,
        averageRevenuePerUser: totalUsers > 0 ? (revenue.total / totalUsers).toFixed(2) : 0
      },
      moderation: {
        pendingReviews,
        pendingWarnings,
        suspendedUsers
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

  } catch (error) {
    functions.logger.error('Get stats error', { error: error.message });
    throw error;
  }
}

/**
 * Gets flagged content for review
 * @param {object} options - Query options
 * @returns {array} Flagged content items
 */
async function getFlaggedContent(options = {}) {
  const db = admin.firestore();
  const {
    limit = 50,
    offset = 0,
    reviewed = false,
    severity = null
  } = options;

  try {
    let query = db.collection('flagged_content')
      .where('reviewed', '==', reviewed)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .offset(offset);

    if (severity) {
      query = query.where('severity', '==', severity);
    }

    const snapshot = await query.get();

    const items = await Promise.all(snapshot.docs.map(async (doc) => {
      const data = doc.data();

      // Get user info
      const userDoc = await db.collection('users').doc(data.userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      return {
        id: doc.id,
        ...data,
        user: {
          id: data.userId,
          fullName: userData.fullName || 'Unknown',
          email: userData.email || 'Unknown',
          warningCount: await getUserWarningCount(data.userId)
        },
        timestamp: data.timestamp?.toDate().toISOString()
      };
    }));

    return items;

  } catch (error) {
    functions.logger.error('Get flagged content error', { error: error.message });
    throw error;
  }
}

/**
 * Moderates flagged content (approve or reject)
 * @param {string} contentId - Flagged content ID
 * @param {string} action - 'approve' or 'reject'
 * @param {string} adminNote - Admin's note
 */
async function moderateContent(contentId, action, adminNote = '') {
  const db = admin.firestore();

  try {
    const contentRef = db.collection('flagged_content').doc(contentId);
    const contentDoc = await contentRef.get();

    if (!contentDoc.exists) {
      throw new Error('Content not found');
    }

    const contentData = contentDoc.data();

    // Update flagged content
    await contentRef.update({
      reviewed: true,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      action,
      adminNote
    });

    if (action === 'reject') {
      // Content is indeed inappropriate - take action
      if (contentData.contentType === 'photo') {
        // Remove photo from storage
        const contentModeration = require('./contentModeration');
        await contentModeration.removePhoto(contentData.contentUrl);

        // Remove from user's photos array
        await db.collection('users').doc(contentData.userId).update({
          photos: admin.firestore.FieldValue.arrayRemove(contentData.contentUrl)
        });
      }

      // Issue warning to user
      await db.collection('user_warnings').add({
        userId: contentData.userId,
        reason: contentData.reason,
        contentId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        acknowledged: false
      });

      // Check if user should be suspended
      await checkAndSuspendUser(contentData.userId);

    } else if (action === 'approve') {
      // Content is fine - no action needed
      functions.logger.info('Content approved', { contentId });
    }

    return { success: true };

  } catch (error) {
    functions.logger.error('Moderate content error', { contentId, error: error.message });
    throw error;
  }
}

/**
 * Gets user details for admin review
 * @param {string} userId - User ID
 * @returns {object} User details with additional admin info
 */
async function getUserDetails(userId) {
  const db = admin.firestore();

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new Error('User not found');
    }

    const userData = userDoc.data();

    // Get warnings
    const warningsSnapshot = await db.collection('user_warnings')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    const warnings = warningsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    // Get reports against this user
    const reportsSnapshot = await db.collection('reports')
      .where('reportedUserId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    const reports = reportsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    // Get recent matches
    const matchesSnapshot = await db.collection('matches')
      .where('user1Id', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    const matches = matchesSnapshot.size;

    // Get recent messages
    const messagesSnapshot = await db.collection('messages')
      .where('senderId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    const recentMessages = messagesSnapshot.size;

    return {
      id: userId,
      ...userData,
      adminInfo: {
        warnings,
        warningCount: warnings.length,
        reports,
        reportCount: reports.length,
        matches,
        recentMessages,
        lastActive: userData.lastActive?.toDate().toISOString(),
        accountCreated: userData.timestamp?.toDate().toISOString()
      }
    };

  } catch (error) {
    functions.logger.error('Get user details error', { userId, error: error.message });
    throw error;
  }
}

/**
 * Suspends a user
 * @param {string} userId - User ID
 * @param {string} reason - Suspension reason
 * @param {number} durationDays - Duration in days (0 = permanent)
 */
async function suspendUser(userId, reason, durationDays = 0) {
  const db = admin.firestore();

  try {
    const updates = {
      suspended: true,
      suspensionReason: reason,
      suspendedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (durationDays > 0) {
      const expiryDate = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);
      updates.suspensionExpiryDate = expiryDate;
    }

    await db.collection('users').doc(userId).update(updates);

    functions.logger.warn('User suspended', { userId, reason, durationDays });

    return { success: true };

  } catch (error) {
    functions.logger.error('Suspend user error', { userId, error: error.message });
    throw error;
  }
}

/**
 * Unsuspends a user
 * @param {string} userId - User ID
 */
async function unsuspendUser(userId) {
  const db = admin.firestore();

  try {
    await db.collection('users').doc(userId).update({
      suspended: false,
      suspensionReason: null,
      suspendedAt: null,
      suspensionExpiryDate: null
    });

    functions.logger.info('User unsuspended', { userId });

    return { success: true };

  } catch (error) {
    functions.logger.error('Unsuspend user error', { userId, error: error.message });
    throw error;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function calculateRevenue(purchases) {
  const pricing = {
    'basic_monthly': 9.99,
    'basic_yearly': 99.99,
    'plus_monthly': 19.99,
    'plus_yearly': 199.99,
    'premium_monthly': 29.99,
    'premium_yearly': 299.99,
    'premium_lifetime': 499.99,
    'super_like_pack': 4.99,
    'boost_pack': 9.99,
    'rewind_pack': 2.99
  };

  let total = 0;
  let subscriptions = 0;
  let consumables = 0;

  purchases.forEach(purchase => {
    const price = pricing[purchase.productId] || 0;
    total += price;

    if (purchase.productId.includes('monthly') || purchase.productId.includes('yearly') || purchase.productId.includes('lifetime')) {
      subscriptions += price;
    } else {
      consumables += price;
    }
  });

  return {
    total: parseFloat(total.toFixed(2)),
    subscriptions: parseFloat(subscriptions.toFixed(2)),
    consumables: parseFloat(consumables.toFixed(2))
  };
}

async function getUserWarningCount(userId) {
  const db = admin.firestore();

  try {
    const warningsSnapshot = await db.collection('user_warnings')
      .where('userId', '==', userId)
      .get();

    return warningsSnapshot.size;
  } catch (error) {
    return 0;
  }
}

async function checkAndSuspendUser(userId) {
  const db = admin.firestore();

  try {
    const warningsSnapshot = await db.collection('user_warnings')
      .where('userId', '==', userId)
      .where('acknowledged', '==', false)
      .get();

    if (warningsSnapshot.size >= 3) {
      await suspendUser(userId, 'Multiple violations', 7); // 7-day suspension
    }
  } catch (error) {
    functions.logger.error('Check and suspend error', { userId, error: error.message });
  }
}

module.exports = {
  getStats,
  getFlaggedContent,
  moderateContent,
  getUserDetails,
  suspendUser,
  unsuspendUser
};
