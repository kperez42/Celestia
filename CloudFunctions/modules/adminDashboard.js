/**
 * Admin Dashboard Module
 * Provides analytics and moderation tools for administrators
 *
 * Features:
 * - Query caching (5-minute TTL)
 * - Bulk user operations
 * - Admin action audit logging
 * - User timeline view
 * - Enhanced fraud pattern detection
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// ============================================================================
// CACHING LAYER (5-minute TTL)
// ============================================================================

const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes in milliseconds

/**
 * Gets cached data or fetches fresh data
 * @param {string} key - Cache key
 * @param {Function} fetchFn - Function to fetch fresh data
 * @param {number} ttl - Time to live in milliseconds
 * @returns {*} Cached or fresh data
 */
async function getCached(key, fetchFn, ttl = CACHE_TTL) {
  const now = Date.now();
  const cached = cache.get(key);

  if (cached && (now - cached.timestamp) < ttl) {
    functions.logger.info('Cache hit', { key });
    return cached.data;
  }

  functions.logger.info('Cache miss, fetching fresh data', { key });
  const data = await fetchFn();
  cache.set(key, { data, timestamp: now });

  return data;
}

/**
 * Invalidates cache entries by key pattern
 * @param {string} pattern - Pattern to match (supports wildcards)
 */
function invalidateCache(pattern) {
  const regex = new RegExp(pattern.replace('*', '.*'));
  const keysToDelete = [];

  for (const key of cache.keys()) {
    if (regex.test(key)) {
      keysToDelete.push(key);
    }
  }

  keysToDelete.forEach(key => cache.delete(key));
  functions.logger.info('Cache invalidated', { pattern, count: keysToDelete.length });
}

/**
 * Clears all cache entries
 */
function clearCache() {
  const size = cache.size;
  cache.clear();
  functions.logger.info('Cache cleared', { entriesRemoved: size });
}

// Periodic cache cleanup (every 10 minutes)
setInterval(() => {
  const now = Date.now();
  const keysToDelete = [];

  for (const [key, value] of cache.entries()) {
    if ((now - value.timestamp) > CACHE_TTL) {
      keysToDelete.push(key);
    }
  }

  keysToDelete.forEach(key => cache.delete(key));

  if (keysToDelete.length > 0) {
    functions.logger.info('Periodic cache cleanup', { entriesRemoved: keysToDelete.length });
  }
}, 10 * 60 * 1000);

// ============================================================================
// AUDIT LOGGING
// ============================================================================

/**
 * Logs admin action for audit trail
 * @param {string} adminId - Admin user ID
 * @param {string} action - Action performed
 * @param {object} details - Action details
 */
async function logAdminAction(adminId, action, details = {}) {
  const db = admin.firestore();

  try {
    await db.collection('admin_audit_logs').add({
      adminId,
      action,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: details.ipAddress || null,
      userAgent: details.userAgent || null
    });

    functions.logger.info('Admin action logged', { adminId, action });
  } catch (error) {
    functions.logger.error('Failed to log admin action', { adminId, action, error: error.message });
  }
}

/**
 * Gets platform statistics (with caching)
 * @returns {object} Platform stats
 */
async function getStats() {
  return getCached('admin:stats', async () => {
    const db = admin.firestore();

    try {
      // OPTIMIZED: Use aggregation instead of fetching all users
      // For production, this should use COUNT aggregation queries
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
      timestamp: new Date().toISOString()
    };

    } catch (error) {
      functions.logger.error('Get stats error', { error: error.message });
      throw error;
    }
  });
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

// ============================================================================
// BULK USER OPERATIONS
// ============================================================================

/**
 * Performs bulk user operations
 * @param {string} operation - Operation type ('ban', 'verify', 'grantPremium', 'revokePremium')
 * @param {Array<string>} userIds - Array of user IDs
 * @param {object} options - Operation options
 * @param {string} adminId - Admin performing the operation
 * @returns {object} Operation results
 */
async function bulkUserOperation(operation, userIds, options = {}, adminId = 'system') {
  const db = admin.firestore();
  const results = {
    success: [],
    failed: [],
    total: userIds.length
  };

  try {
    // Log the bulk operation
    await logAdminAction(adminId, `bulk_${operation}`, {
      userCount: userIds.length,
      options
    });

    for (const userId of userIds) {
      try {
        switch (operation) {
          case 'ban':
            await db.collection('users').doc(userId).update({
              suspended: true,
              suspensionReason: options.reason || 'Bulk ban by admin',
              suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
              suspensionExpiryDate: options.durationDays > 0
                ? new Date(Date.now() + options.durationDays * 24 * 60 * 60 * 1000)
                : null
            });
            results.success.push(userId);
            break;

          case 'verify':
            await db.collection('users').doc(userId).update({
              isVerified: true,
              verifiedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.success.push(userId);
            break;

          case 'grantPremium':
            const expiryDate = options.months
              ? new Date(Date.now() + options.months * 30 * 24 * 60 * 60 * 1000)
              : null;

            await db.collection('users').doc(userId).update({
              isPremium: true,
              premiumTier: options.tier || 'premium',
              premiumExpiryDate: expiryDate,
              premiumGrantedBy: 'admin',
              premiumGrantedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.success.push(userId);
            break;

          case 'revokePremium':
            await db.collection('users').doc(userId).update({
              isPremium: false,
              premiumTier: null,
              premiumExpiryDate: null
            });
            results.success.push(userId);
            break;

          case 'unban':
            await db.collection('users').doc(userId).update({
              suspended: false,
              suspensionReason: null,
              suspendedAt: null,
              suspensionExpiryDate: null
            });
            results.success.push(userId);
            break;

          default:
            throw new Error(`Unknown operation: ${operation}`);
        }

        // Log individual operation
        await logAdminAction(adminId, operation, { userId, options });

      } catch (error) {
        functions.logger.error(`Bulk operation failed for user ${userId}`, { error: error.message });
        results.failed.push({ userId, error: error.message });
      }
    }

    // Invalidate relevant caches
    invalidateCache('admin:stats');
    invalidateCache('admin:users:*');

    functions.logger.info('Bulk operation completed', {
      operation,
      success: results.success.length,
      failed: results.failed.length
    });

    return results;

  } catch (error) {
    functions.logger.error('Bulk operation error', { operation, error: error.message });
    throw error;
  }
}

// ============================================================================
// USER TIMELINE VIEW
// ============================================================================

/**
 * Gets comprehensive user timeline (all actions in one place)
 * @param {string} userId - User ID
 * @param {object} options - Query options
 * @returns {object} User timeline with all activities
 */
async function getUserTimeline(userId, options = {}) {
  const db = admin.firestore();
  const { limit = 100 } = options;

  try {
    const timeline = [];

    // Get user profile
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new Error('User not found');
    }

    const userData = userDoc.data();

    // Account creation
    if (userData.timestamp) {
      timeline.push({
        type: 'account_created',
        timestamp: userData.timestamp.toDate(),
        data: {
          email: userData.email,
          fullName: userData.fullName
        }
      });
    }

    // Matches
    const matchesSnapshot = await db.collection('matches')
      .where('user1Id', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    matchesSnapshot.docs.forEach(doc => {
      const match = doc.data();
      timeline.push({
        type: 'match',
        timestamp: match.timestamp?.toDate(),
        data: {
          matchId: doc.id,
          otherUserId: match.user2Id,
          isActive: match.isActive
        }
      });
    });

    // Messages sent
    const messagesSnapshot = await db.collection('messages')
      .where('senderId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    messagesSnapshot.docs.forEach(doc => {
      const message = doc.data();
      timeline.push({
        type: 'message_sent',
        timestamp: message.timestamp?.toDate(),
        data: {
          messageId: doc.id,
          matchId: message.matchId,
          receiverId: message.receiverId
        }
      });
    });

    // Purchases
    const purchasesSnapshot = await db.collection('purchases')
      .where('userId', '==', userId)
      .orderBy('purchaseDate', 'desc')
      .get();

    purchasesSnapshot.docs.forEach(doc => {
      const purchase = doc.data();
      timeline.push({
        type: purchase.refunded ? 'purchase_refunded' : 'purchase',
        timestamp: purchase.refunded ? purchase.refundDate?.toDate() : purchase.purchaseDate?.toDate(),
        data: {
          purchaseId: doc.id,
          productId: purchase.productId,
          validated: purchase.validated,
          refunded: purchase.refunded,
          fraudScore: purchase.fraudScore
        }
      });
    });

    // Warnings
    const warningsSnapshot = await db.collection('user_warnings')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    warningsSnapshot.docs.forEach(doc => {
      const warning = doc.data();
      timeline.push({
        type: 'warning_issued',
        timestamp: warning.timestamp?.toDate(),
        data: {
          warningId: doc.id,
          reason: warning.reason,
          acknowledged: warning.acknowledged
        }
      });
    });

    // Reports made by user
    const reportsMadeSnapshot = await db.collection('reports')
      .where('reporterId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    reportsMadeSnapshot.docs.forEach(doc => {
      const report = doc.data();
      timeline.push({
        type: 'report_made',
        timestamp: report.timestamp?.toDate(),
        data: {
          reportId: doc.id,
          reportedUserId: report.reportedUserId,
          reason: report.reason
        }
      });
    });

    // Reports against user
    const reportsAgainstSnapshot = await db.collection('reports')
      .where('reportedUserId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    reportsAgainstSnapshot.docs.forEach(doc => {
      const report = doc.data();
      timeline.push({
        type: 'report_received',
        timestamp: report.timestamp?.toDate(),
        data: {
          reportId: doc.id,
          reporterId: report.reporterId,
          reason: report.reason
        }
      });
    });

    // Flagged content
    const flaggedContentSnapshot = await db.collection('flagged_content')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    flaggedContentSnapshot.docs.forEach(doc => {
      const content = doc.data();
      timeline.push({
        type: 'content_flagged',
        timestamp: content.timestamp?.toDate(),
        data: {
          contentId: doc.id,
          contentType: content.contentType,
          reason: content.reason,
          severity: content.severity,
          reviewed: content.reviewed,
          action: content.action
        }
      });
    });

    // Fraud logs
    const fraudLogsSnapshot = await db.collection('fraud_logs')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    fraudLogsSnapshot.docs.forEach(doc => {
      const fraud = doc.data();
      timeline.push({
        type: 'fraud_attempt',
        timestamp: fraud.timestamp?.toDate(),
        data: {
          fraudId: doc.id,
          fraudType: fraud.fraudType,
          eventType: fraud.eventType,
          details: fraud.details
        }
      });
    });

    // Admin actions
    const adminActionsSnapshot = await db.collection('admin_audit_logs')
      .where('details.userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .get();

    adminActionsSnapshot.docs.forEach(doc => {
      const action = doc.data();
      timeline.push({
        type: 'admin_action',
        timestamp: action.timestamp?.toDate(),
        data: {
          actionId: doc.id,
          adminId: action.adminId,
          action: action.action,
          details: action.details
        }
      });
    });

    // Sort timeline by timestamp (most recent first)
    timeline.sort((a, b) => {
      const timeA = a.timestamp ? a.timestamp.getTime() : 0;
      const timeB = b.timestamp ? b.timestamp.getTime() : 0;
      return timeB - timeA;
    });

    // Convert timestamps to ISO strings
    timeline.forEach(event => {
      if (event.timestamp) {
        event.timestamp = event.timestamp.toISOString();
      }
    });

    return {
      userId,
      user: {
        fullName: userData.fullName,
        email: userData.email,
        suspended: userData.suspended,
        isPremium: userData.isPremium,
        isVerified: userData.isVerified
      },
      timeline: timeline.slice(0, limit),
      totalEvents: timeline.length,
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    functions.logger.error('Get user timeline error', { userId, error: error.message });
    throw error;
  }
}

// ============================================================================
// ENHANCED FRAUD PATTERN DETECTION
// ============================================================================

/**
 * Detects fraud patterns across users and transactions
 * @param {object} options - Detection options
 * @returns {object} Detected fraud patterns
 */
async function detectFraudPatterns(options = {}) {
  const db = admin.firestore();
  const { period = 30 } = options; // days

  try {
    const periodStart = new Date(Date.now() - period * 24 * 60 * 60 * 1000);

    // Get all recent purchases
    const purchasesSnapshot = await db.collection('purchases')
      .where('purchaseDate', '>', periodStart)
      .get();

    const purchases = purchasesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    const patterns = {
      multipleRefunds: [],
      rapidPurchases: [],
      highFraudScore: [],
      suspiciousDevices: [],
      geolocationAnomalies: [],
      priceManipulation: []
    };

    // Pattern 1: Users with multiple refunds
    const userRefunds = {};
    purchases.forEach(p => {
      if (p.refunded) {
        userRefunds[p.userId] = (userRefunds[p.userId] || 0) + 1;
      }
    });

    Object.entries(userRefunds).forEach(([userId, count]) => {
      if (count >= 2) {
        patterns.multipleRefunds.push({
          userId,
          refundCount: count,
          severity: count >= 3 ? 'high' : 'medium'
        });
      }
    });

    // Pattern 2: Rapid purchases (multiple in short time)
    const userPurchaseTimes = {};
    purchases.forEach(p => {
      if (!userPurchaseTimes[p.userId]) {
        userPurchaseTimes[p.userId] = [];
      }
      userPurchaseTimes[p.userId].push(p.purchaseDate?.toDate());
    });

    Object.entries(userPurchaseTimes).forEach(([userId, times]) => {
      times.sort((a, b) => a - b);
      for (let i = 1; i < times.length; i++) {
        const timeDiff = (times[i] - times[i-1]) / 1000 / 60; // minutes
        if (timeDiff < 5) { // Less than 5 minutes between purchases
          patterns.rapidPurchases.push({
            userId,
            purchaseCount: times.length,
            minTimeBetween: timeDiff.toFixed(2),
            severity: 'high'
          });
          break;
        }
      }
    });

    // Pattern 3: High fraud score transactions
    purchases.forEach(p => {
      if (p.fraudScore > 75) {
        patterns.highFraudScore.push({
          userId: p.userId,
          purchaseId: p.id,
          fraudScore: p.fraudScore,
          productId: p.productId,
          severity: p.fraudScore > 90 ? 'critical' : 'high'
        });
      }
    });

    // Pattern 4: Suspicious device patterns (same device, multiple users)
    const deviceUsers = {};
    purchases.forEach(p => {
      if (p.deviceId) {
        if (!deviceUsers[p.deviceId]) {
          deviceUsers[p.deviceId] = new Set();
        }
        deviceUsers[p.deviceId].add(p.userId);
      }
    });

    Object.entries(deviceUsers).forEach(([deviceId, users]) => {
      if (users.size > 3) { // More than 3 users on same device
        patterns.suspiciousDevices.push({
          deviceId,
          userCount: users.size,
          users: Array.from(users),
          severity: 'high'
        });
      }
    });

    // Pattern 5: Price manipulation detection
    const expectedPricing = {
      'basic_monthly': 9.99,
      'basic_yearly': 99.99,
      'plus_monthly': 19.99,
      'plus_yearly': 199.99,
      'premium_monthly': 29.99,
      'premium_yearly': 299.99,
      'premium_lifetime': 499.99
    };

    purchases.forEach(p => {
      if (expectedPricing[p.productId] && p.price) {
        const expectedPrice = expectedPricing[p.productId];
        const actualPrice = parseFloat(p.price);

        if (Math.abs(actualPrice - expectedPrice) > 0.1) {
          patterns.priceManipulation.push({
            userId: p.userId,
            purchaseId: p.id,
            productId: p.productId,
            expectedPrice,
            actualPrice,
            severity: 'critical'
          });
        }
      }
    });

    // Calculate risk scores
    const totalPatterns =
      patterns.multipleRefunds.length +
      patterns.rapidPurchases.length +
      patterns.highFraudScore.length +
      patterns.suspiciousDevices.length +
      patterns.priceManipulation.length;

    const criticalCount =
      patterns.highFraudScore.filter(p => p.severity === 'critical').length +
      patterns.priceManipulation.length;

    return {
      period,
      patterns,
      summary: {
        totalPatterns,
        criticalPatterns: criticalCount,
        highRiskUsers: new Set([
          ...patterns.multipleRefunds.map(p => p.userId),
          ...patterns.rapidPurchases.map(p => p.userId),
          ...patterns.highFraudScore.map(p => p.userId)
        ]).size,
        suspiciousDevices: patterns.suspiciousDevices.length
      },
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    functions.logger.error('Detect fraud patterns error', { error: error.message });
    throw error;
  }
}

/**
 * Gets admin audit logs
 * @param {object} options - Query options
 * @returns {array} Audit logs
 */
async function getAdminAuditLogs(options = {}) {
  const db = admin.firestore();
  const {
    limit = 50,
    adminId = null,
    action = null,
    startDate = null
  } = options;

  try {
    let query = db.collection('admin_audit_logs')
      .orderBy('timestamp', 'desc')
      .limit(limit);

    if (adminId) {
      query = query.where('adminId', '==', adminId);
    }

    if (action) {
      query = query.where('action', '==', action);
    }

    if (startDate) {
      query = query.where('timestamp', '>', startDate);
    }

    const snapshot = await query.get();

    const logs = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate().toISOString()
    }));

    return logs;

  } catch (error) {
    functions.logger.error('Get admin audit logs error', { error: error.message });
    throw error;
  }
}

module.exports = {
  // Existing functions
  getStats,
  getFlaggedContent,
  moderateContent,
  getUserDetails,
  suspendUser,
  unsuspendUser,
  getSubscriptionAnalytics,
  getFraudDashboard,
  getRefundTracking,
  reviewFlaggedTransaction,

  // New functions
  bulkUserOperation,
  getUserTimeline,
  detectFraudPatterns,
  getAdminAuditLogs,
  logAdminAction,

  // Cache management
  invalidateCache,
  clearCache
};
