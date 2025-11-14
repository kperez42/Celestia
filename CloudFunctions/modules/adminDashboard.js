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

    // Get refund stats
    const refundedPurchases = purchases.filter(p => p.refunded === true);
    const refundCount = refundedPurchases.length;
    const refundRate = purchases.length > 0 ? (refundCount / purchases.length * 100).toFixed(2) : 0;

    // Get fraud stats
    const fraudLogsSnapshot = await db.collection('fraud_logs')
      .where('timestamp', '>', thirtyDaysAgo)
      .where('eventType', '==', 'fraud_attempt')
      .get();

    const fraudAttempts = fraudLogsSnapshot.size;

    // Get high-risk transactions
    const flaggedTransactionsSnapshot = await db.collection('flagged_transactions')
      .where('reviewed', '==', false)
      .get();

    const pendingFraudReviews = flaggedTransactionsSnapshot.size;

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
        averageRevenuePerUser: totalUsers > 0 ? (revenue.total / totalUsers).toFixed(2) : 0,
        totalPurchases: purchases.length,
        refundCount,
        refundRate: parseFloat(refundRate),
        refundedRevenue: calculateRefundedRevenue(refundedPurchases)
      },
      security: {
        fraudAttempts,
        pendingFraudReviews,
        highRiskTransactions: pendingFraudReviews
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
    // Skip refunded purchases
    if (purchase.refunded) {
      return;
    }

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

function calculateRefundedRevenue(refundedPurchases) {
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

  refundedPurchases.forEach(purchase => {
    const price = pricing[purchase.productId] || 0;
    total += price;
  });

  return parseFloat(total.toFixed(2));
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

/**
 * Gets subscription analytics and monitoring data
 * @param {object} options - Query options
 * @returns {object} Subscription analytics
 */
async function getSubscriptionAnalytics(options = {}) {
  const db = admin.firestore();
  const {
    period = 30 // days
  } = options;

  try {
    const periodStart = new Date(Date.now() - period * 24 * 60 * 60 * 1000);

    // Get all purchases in period
    const purchasesSnapshot = await db.collection('purchases')
      .where('purchaseDate', '>', periodStart)
      .get();

    const purchases = purchasesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Analyze subscriptions
    const subscriptionPurchases = purchases.filter(p => p.isSubscription);
    const newSubscriptions = subscriptionPurchases.filter(p => !p.isPromotional);
    const promotionalSubscriptions = subscriptionPurchases.filter(p => p.isPromotional);
    const trialSubscriptions = subscriptionPurchases.filter(p => p.isTrialPeriod);

    // Churn analysis
    const cancelledSubscriptions = purchases.filter(p => p.cancelled);
    const refundedSubscriptions = purchases.filter(p => p.refunded);

    // Fraud analysis
    const highRiskPurchases = purchases.filter(p => p.fraudScore > 50);
    const flaggedPurchases = purchases.filter(p => p.fraudScore > 75);

    // Revenue breakdown
    const subscriptionRevenue = calculateRevenue(subscriptionPurchases);
    const refundedRevenue = calculateRefundedRevenue(refundedSubscriptions);

    // Calculate metrics
    const churnRate = subscriptionPurchases.length > 0
      ? (cancelledSubscriptions.length / subscriptionPurchases.length * 100).toFixed(2)
      : 0;

    const refundRate = purchases.length > 0
      ? (refundedSubscriptions.length / purchases.length * 100).toFixed(2)
      : 0;

    const fraudRate = purchases.length > 0
      ? (flaggedPurchases.length / purchases.length * 100).toFixed(2)
      : 0;

    return {
      period,
      totalPurchases: purchases.length,
      subscriptions: {
        total: subscriptionPurchases.length,
        new: newSubscriptions.length,
        promotional: promotionalSubscriptions.length,
        trial: trialSubscriptions.length,
        cancelled: cancelledSubscriptions.length,
        refunded: refundedSubscriptions.length
      },
      metrics: {
        churnRate: parseFloat(churnRate),
        refundRate: parseFloat(refundRate),
        fraudRate: parseFloat(fraudRate)
      },
      revenue: {
        total: subscriptionRevenue.total,
        refunded: refundedRevenue,
        net: parseFloat((subscriptionRevenue.total - refundedRevenue).toFixed(2))
      },
      risk: {
        highRiskPurchases: highRiskPurchases.length,
        flaggedPurchases: flaggedPurchases.length,
        averageFraudScore: purchases.length > 0
          ? parseFloat((purchases.reduce((sum, p) => sum + (p.fraudScore || 0), 0) / purchases.length).toFixed(2))
          : 0
      },
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    functions.logger.error('Get subscription analytics error', { error: error.message });
    throw error;
  }
}

/**
 * Gets fraud detection dashboard data
 * @returns {object} Fraud detection data
 */
async function getFraudDashboard() {
  const db = admin.firestore();

  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    // Get fraud logs
    const fraudLogsSnapshot = await db.collection('fraud_logs')
      .where('timestamp', '>', thirtyDaysAgo)
      .orderBy('timestamp', 'desc')
      .limit(100)
      .get();

    const fraudLogs = fraudLogsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    // Get flagged transactions
    const flaggedTransactionsSnapshot = await db.collection('flagged_transactions')
      .where('reviewed', '==', false)
      .orderBy('fraudScore', 'desc')
      .limit(50)
      .get();

    const flaggedTransactions = await Promise.all(flaggedTransactionsSnapshot.docs.map(async (doc) => {
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
          email: userData.email || 'Unknown'
        },
        timestamp: data.timestamp?.toDate().toISOString()
      };
    }));

    // Get refund abuse cases
    const refundHistorySnapshot = await db.collection('refund_history')
      .where('timestamp', '>', thirtyDaysAgo)
      .get();

    const refundHistory = refundHistorySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    // Identify users with multiple refunds
    const userRefundCounts = {};
    refundHistory.forEach(refund => {
      userRefundCounts[refund.userId] = (userRefundCounts[refund.userId] || 0) + 1;
    });

    const refundAbusers = Object.entries(userRefundCounts)
      .filter(([_, count]) => count > 2)
      .map(([userId, count]) => ({ userId, refundCount: count }));

    // Get admin alerts
    const adminAlertsSnapshot = await db.collection('admin_alerts')
      .where('acknowledged', '==', false)
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();

    const adminAlerts = adminAlertsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    // Calculate fraud statistics
    const fraudAttemptsByType = {};
    fraudLogs.forEach(log => {
      const type = log.fraudType || 'unknown';
      fraudAttemptsByType[type] = (fraudAttemptsByType[type] || 0) + 1;
    });

    return {
      fraudLogs: fraudLogs.slice(0, 20), // Latest 20
      flaggedTransactions,
      refundAbusers,
      adminAlerts,
      statistics: {
        totalFraudAttempts: fraudLogs.length,
        totalFlaggedTransactions: flaggedTransactions.length,
        totalRefundAbusers: refundAbusers.length,
        pendingAlerts: adminAlerts.length,
        fraudAttemptsByType
      },
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    functions.logger.error('Get fraud dashboard error', { error: error.message });
    throw error;
  }
}

/**
 * Gets refund tracking data
 * @param {object} options - Query options
 * @returns {array} Refund data
 */
async function getRefundTracking(options = {}) {
  const db = admin.firestore();
  const {
    limit = 50,
    period = 30 // days
  } = options;

  try {
    const periodStart = new Date(Date.now() - period * 24 * 60 * 60 * 1000);

    const refundsSnapshot = await db.collection('purchases')
      .where('refunded', '==', true)
      .where('refundDate', '>', periodStart)
      .orderBy('refundDate', 'desc')
      .limit(limit)
      .get();

    const refunds = await Promise.all(refundsSnapshot.docs.map(async (doc) => {
      const data = doc.data();

      // Get user info
      const userDoc = await db.collection('users').doc(data.userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      // Check if user has multiple refunds
      const userRefundsSnapshot = await db.collection('purchases')
        .where('userId', '==', data.userId)
        .where('refunded', '==', true)
        .get();

      const userRefundCount = userRefundsSnapshot.size;

      return {
        id: doc.id,
        ...data,
        user: {
          id: data.userId,
          fullName: userData.fullName || 'Unknown',
          email: userData.email || 'Unknown',
          totalRefunds: userRefundCount,
          suspended: userData.suspended || false
        },
        refundDate: data.refundDate?.toDate().toISOString(),
        purchaseDate: data.purchaseDate?.toDate().toISOString()
      };
    }));

    return refunds;

  } catch (error) {
    functions.logger.error('Get refund tracking error', { error: error.message });
    throw error;
  }
}

/**
 * Review and approve/reject flagged transaction
 * @param {string} transactionId - Flagged transaction ID
 * @param {string} decision - 'approve' or 'reject'
 * @param {string} adminNote - Admin's note
 */
async function reviewFlaggedTransaction(transactionId, decision, adminNote = '') {
  const db = admin.firestore();

  try {
    const transactionRef = db.collection('flagged_transactions').doc(transactionId);
    const transactionDoc = await transactionRef.get();

    if (!transactionDoc.exists) {
      throw new Error('Flagged transaction not found');
    }

    await transactionRef.update({
      reviewed: true,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      decision,
      adminNote
    });

    if (decision === 'reject') {
      const data = transactionDoc.data();

      // Revoke access and suspend user
      await db.collection('users').doc(data.userId).update({
        isPremium: false,
        premiumTier: null,
        suspended: true,
        suspensionReason: `Fraudulent transaction: ${adminNote}`,
        suspendedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.warn('Fraudulent transaction confirmed - user suspended', {
        transactionId,
        userId: data.userId
      });
    }

    return { success: true };

  } catch (error) {
    functions.logger.error('Review flagged transaction error', { transactionId, error: error.message });
    throw error;
  }
}

module.exports = {
  getStats,
  getFlaggedContent,
  moderateContent,
  getUserDetails,
  suspendUser,
  unsuspendUser,
  getSubscriptionAnalytics,
  getFraudDashboard,
  getRefundTracking,
  reviewFlaggedTransaction
};
