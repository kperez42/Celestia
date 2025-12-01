/**
 * Celestia Backend API - Cloud Functions
 * Handles server-side validation, moderation, and admin operations
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { RateLimiterMemory } = require('rate-limiter-flexible');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// Import modules
const receiptValidation = require('./modules/receiptValidation');
const contentModeration = require('./modules/contentModeration');
const rateLimiting = require('./modules/rateLimiting');
const adminDashboard = require('./modules/adminDashboard');
const moderationQueue = require('./modules/moderationQueue');
const notifications = require('./modules/notifications');
const webhooks = require('./modules/webhooks');
const fraudDetection = require('./modules/fraudDetection');
const adminSecurity = require('./modules/adminSecurity');
const photoVerification = require('./modules/photoVerification');
const performanceMonitoring = require('./modules/performanceMonitoring');
const imageOptimization = require('./modules/imageOptimization');
const stripeIdentity = require('./modules/stripeIdentity');

// ============================================================================
// API ENDPOINTS
// ============================================================================

// Express app for HTTP endpoints
const app = express();

// CORS must come first to handle preflight OPTIONS requests
app.use(cors({ origin: true }));

// Security middleware - Helmet adds various HTTP headers for security
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://*.googleapis.com", "https://*.firebaseio.com"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // Allow embedding for Firebase
  crossOriginResourcePolicy: { policy: "cross-origin" }, // Allow cross-origin requests
}));

app.use(express.json());

// ============================================================================
// RECEIPT VALIDATION
// ============================================================================

/**
 * Validates App Store receipts for in-app purchases
 * Prevents fraud by verifying transactions server-side
 * SECURITY: Enhanced with fraud detection and duplicate prevention
 */
exports.validateReceipt = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { receiptData, productId } = data;
  const userId = context.auth.uid;

  try {
    // Validate the receipt with Apple (includes fraud detection)
    const validationResult = await receiptValidation.validateAppleReceipt(receiptData, userId);

    if (!validationResult.isValid) {
      functions.logger.warn('Receipt validation failed', {
        userId,
        error: validationResult.error,
        fraudScore: validationResult.fraudScore
      });

      throw new functions.https.HttpsError('invalid-argument', validationResult.error || 'Invalid receipt');
    }

    // Check if receipt matches the product
    if (validationResult.productId !== productId) {
      throw new functions.https.HttpsError('invalid-argument', 'Product ID mismatch');
    }

    // SECURITY: Fraud score check - reject high-risk transactions
    if (validationResult.fraudScore > fraudDetection.FRAUD_THRESHOLDS.FRAUD_SCORE_HIGH) {
      functions.logger.error('CRITICAL: High fraud score - transaction rejected', {
        userId,
        fraudScore: validationResult.fraudScore,
        transactionId: validationResult.transactionId
      });

      throw new functions.https.HttpsError('permission-denied', 'Transaction flagged for security review');
    }

    // Record the purchase with fraud metadata
    const purchaseRef = await db.collection('purchases').add({
      userId,
      productId,
      transactionId: validationResult.transactionId,
      originalTransactionId: validationResult.originalTransactionId,
      purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: validationResult.expiryDate || null,
      isSubscription: validationResult.isSubscription,
      isPromotional: validationResult.isPromotional || false,
      promotionalOfferId: validationResult.promotionalOfferId || null,
      isTrialPeriod: validationResult.isTrialPeriod || false,
      isInIntroOfferPeriod: validationResult.isInIntroOfferPeriod || false,
      autoRenewStatus: validationResult.autoRenewStatus,
      receiptData: validationResult.receipt,
      validated: true,
      refunded: false,
      fraudScore: validationResult.fraudScore,
      jailbreakRisk: validationResult.jailbreakRisk
    });

    // Update user's subscription status
    await updateUserSubscription(userId, productId, validationResult);

    functions.logger.info(`✅ Receipt validated for user ${userId}`, {
      productId,
      transactionId: validationResult.transactionId,
      fraudScore: validationResult.fraudScore
    });

    return {
      success: true,
      isValid: true,
      purchaseId: purchaseRef.id,
      expiryDate: validationResult.expiryDate,
      fraudScore: validationResult.fraudScore
    };

  } catch (error) {
    functions.logger.error('Receipt validation error', { userId, error: error.message });

    // Re-throw HttpsError as-is, wrap other errors
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Webhook for App Store Server Notifications V2
 * Handles subscription renewals, cancellations, refunds
 * SECURITY: Implements signature verification to prevent spoofing
 */
exports.appleWebhook = functions.https.onRequest(async (req, res) => {
  try {
    functions.logger.info('Apple webhook received', {
      ip: req.ip,
      headers: req.headers['x-forwarded-for'] || 'unknown'
    });

    // SECURITY: Verify webhook signature (CRITICAL for production)
    const verifiedPayload = await webhooks.verifyWebhookSignature(req);

    if (!verifiedPayload) {
      functions.logger.error('⛔ Webhook signature verification failed - potential spoofing attempt', {
        ip: req.ip
      });
      return res.status(401).send('Invalid signature');
    }

    functions.logger.info('✅ Webhook signature verified - processing notification');

    // Handle the verified webhook notification
    await webhooks.handleWebhookNotification(verifiedPayload);

    res.status(200).send('OK');
  } catch (error) {
    functions.logger.error('Apple webhook error', {
      error: error.message,
      stack: error.stack
    });
    res.status(500).send('Error processing webhook');
  }
});

// ============================================================================
// CONTENT MODERATION
// ============================================================================

/**
 * Moderates photo uploads using AI/ML
 * Checks for inappropriate content, fake profiles, etc.
 */
exports.moderatePhoto = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { photoUrl, userId } = data;

  try {
    // Run moderation checks
    const moderationResult = await contentModeration.moderateImage(photoUrl);

    // Log moderation result
    await db.collection('moderation_logs').add({
      userId,
      photoUrl,
      result: moderationResult,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // If content is inappropriate, flag it
    if (!moderationResult.isApproved) {
      await db.collection('flagged_content').add({
        userId,
        contentType: 'photo',
        contentUrl: photoUrl,
        reason: moderationResult.reason,
        severity: moderationResult.severity,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        reviewed: false
      });

      // Auto-remove if high severity
      if (moderationResult.severity === 'high') {
        await contentModeration.removePhoto(photoUrl);

        // Warn or suspend user
        await warnUser(userId, moderationResult.reason);
      }
    }

    return {
      approved: moderationResult.isApproved,
      reason: moderationResult.reason,
      confidence: moderationResult.confidence
    };

  } catch (error) {
    functions.logger.error('Photo moderation error', { userId, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Moderates text content (bio, messages, prompts)
 */
exports.moderateText = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { text, contentType, userId } = data;

  try {
    const moderationResult = await contentModeration.moderateText(text);

    // Log moderation
    await db.collection('moderation_logs').add({
      userId,
      contentType,
      text: text.substring(0, 500), // Store truncated version
      result: moderationResult,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    if (!moderationResult.isApproved) {
      await db.collection('flagged_content').add({
        userId,
        contentType,
        text,
        reason: moderationResult.reason,
        categories: moderationResult.categories,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        reviewed: false
      });

      if (moderationResult.severity === 'high') {
        await warnUser(userId, moderationResult.reason);
      }
    }

    return {
      approved: moderationResult.isApproved,
      reason: moderationResult.reason,
      suggestions: moderationResult.suggestions
    };

  } catch (error) {
    functions.logger.error('Text moderation error', { userId, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// RATE LIMITING
// ============================================================================

/**
 * Rate-limited action endpoint
 * Prevents abuse for actions like likes, messages, reports
 */
exports.recordAction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { actionType } = data;
  const userId = context.auth.uid;

  try {
    // Check rate limit
    const isAllowed = await rateLimiting.checkRateLimit(userId, actionType);

    if (!isAllowed) {
      const limits = rateLimiting.getLimits(actionType);
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again later.`,
        { limit: limits.points, duration: limits.duration }
      );
    }

    // Record the action
    await rateLimiting.recordAction(userId, actionType);

    // Get remaining quota
    const remaining = await rateLimiting.getRemainingQuota(userId, actionType);

    return {
      success: true,
      remaining
    };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error('Action recording error', { userId, actionType, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Validate action before performing it (backend validation)
 * Returns whether action is allowed and remaining quota
 */
exports.validateRateLimit = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { actionType } = data;
  const userId = context.auth.uid;

  try {
    const result = await rateLimiting.validateAction(userId, actionType);
    return result;
  } catch (error) {
    functions.logger.error('Rate limit validation error', { userId, actionType, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get user's rate limit status for all actions
 */
exports.getRateLimitStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  try {
    const status = await rateLimiting.getUserRateLimitStatus(userId);
    return status;
  } catch (error) {
    functions.logger.error('Get rate limit status error', { userId, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// ADMIN DASHBOARD API
// ============================================================================

app.get('/admin/stats', async (req, res) => {
  try {
    // Verify admin token
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const stats = await adminDashboard.getStats();
    res.json(stats);
  } catch (error) {
    functions.logger.error('Admin stats error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/admin/flagged-content', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const flaggedContent = await adminDashboard.getFlaggedContent();
    res.json(flaggedContent);
  } catch (error) {
    functions.logger.error('Admin flagged content error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/admin/moderate-content', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { contentId, action, reason } = req.body;
    await adminDashboard.moderateContent(contentId, action, reason);

    res.json({ success: true });
  } catch (error) {
    functions.logger.error('Admin moderate content error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// NEW ENDPOINTS FOR SUBSCRIPTION MONITORING & FRAUD DETECTION

app.get('/admin/subscription-analytics', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const period = parseInt(req.query.period) || 30;
    const analytics = await adminDashboard.getSubscriptionAnalytics({ period });
    res.json(analytics);
  } catch (error) {
    functions.logger.error('Admin subscription analytics error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/admin/fraud-dashboard', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const fraudData = await adminDashboard.getFraudDashboard();
    res.json(fraudData);
  } catch (error) {
    functions.logger.error('Admin fraud dashboard error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/admin/refund-tracking', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const limit = parseInt(req.query.limit) || 50;
    const period = parseInt(req.query.period) || 30;
    const refunds = await adminDashboard.getRefundTracking({ limit, period });
    res.json(refunds);
  } catch (error) {
    functions.logger.error('Admin refund tracking error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/admin/review-transaction', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { transactionId, decision, adminNote } = req.body;
    await adminDashboard.reviewFlaggedTransaction(transactionId, decision, adminNote);
    res.json({ success: true });
  } catch (error) {
    functions.logger.error('Admin review transaction error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// NEW ENHANCED ADMIN ENDPOINTS

// Bulk User Operations
app.post('/admin/bulk-operation', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { operation, userIds, options } = req.body;
    const adminId = req.adminId || 'unknown'; // Set by verifyAdminToken

    const results = await adminDashboard.bulkUserOperation(operation, userIds, options, adminId);
    res.json(results);
  } catch (error) {
    functions.logger.error('Admin bulk operation error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// User Timeline
app.get('/admin/user-timeline/:userId', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 100;

    const timeline = await adminDashboard.getUserTimeline(userId, { limit });
    res.json(timeline);
  } catch (error) {
    functions.logger.error('Admin user timeline error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Fraud Pattern Detection
app.get('/admin/fraud-patterns', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const period = parseInt(req.query.period) || 30;
    const patterns = await adminDashboard.detectFraudPatterns({ period });
    res.json(patterns);
  } catch (error) {
    functions.logger.error('Admin fraud patterns error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Admin Audit Logs
app.get('/admin/audit-logs', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const options = {
      limit: parseInt(req.query.limit) || 50,
      adminId: req.query.adminId || null,
      action: req.query.action || null
    };

    const logs = await adminDashboard.getAdminAuditLogs(options);
    res.json(logs);
  } catch (error) {
    functions.logger.error('Admin audit logs error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Cache Management
app.post('/admin/clear-cache', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { pattern } = req.body;

    if (pattern) {
      adminDashboard.invalidateCache(pattern);
    } else {
      adminDashboard.clearCache();
    }

    res.json({ success: true, message: 'Cache cleared' });
  } catch (error) {
    functions.logger.error('Admin clear cache error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// ============================================================================
// MODERATION QUEUE API
// ============================================================================

// Get Moderation Queue
app.get('/admin/moderation-queue', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const options = {
      limit: parseInt(req.query.limit) || 50,
      status: req.query.status || 'pending',
      assignedTo: req.query.assignedTo || null,
      priorityLevel: req.query.priorityLevel || null
    };

    const queue = await moderationQueue.getQueue(options);
    res.json(queue);
  } catch (error) {
    functions.logger.error('Get moderation queue error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Add to Moderation Queue
app.post('/admin/moderation-queue', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const queueItemId = await moderationQueue.addToQueue(req.body);
    res.json({ success: true, queueItemId });
  } catch (error) {
    functions.logger.error('Add to moderation queue error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Assign Queue Item
app.post('/admin/moderation-queue/:itemId/assign', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { itemId } = req.params;
    const { moderatorId } = req.body;

    const result = await moderationQueue.assignToModerator(itemId, moderatorId);
    res.json(result);
  } catch (error) {
    functions.logger.error('Assign queue item error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Auto-Assign Items
app.post('/admin/moderation-queue/auto-assign', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const results = await moderationQueue.autoAssignItems();
    res.json(results);
  } catch (error) {
    functions.logger.error('Auto-assign queue items error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Complete Moderation
app.post('/admin/moderation-queue/:itemId/complete', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const { itemId } = req.params;
    const { decision, moderatorNote } = req.body;
    const moderatorId = req.adminId || 'unknown';

    const result = await moderationQueue.completeModeration(itemId, decision, moderatorNote, moderatorId);
    res.json(result);
  } catch (error) {
    functions.logger.error('Complete moderation error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Get Queue Statistics
app.get('/admin/moderation-queue/stats', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const stats = await moderationQueue.getQueueStats();
    res.json(stats);
  } catch (error) {
    functions.logger.error('Get queue stats error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// Escalate Stale Items
app.post('/admin/moderation-queue/escalate', async (req, res) => {
  try {
    const isAdmin = await verifyAdminToken(req.headers.authorization);
    if (!isAdmin) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const results = await moderationQueue.escalateStaleItems();
    res.json(results);
  } catch (error) {
    functions.logger.error('Escalate stale items error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

exports.adminApi = functions.https.onRequest(app);

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

async function updateUserSubscription(userId, productId, validationResult) {
  const subscriptionTier = getSubscriptionTier(productId);
  const expiryDate = validationResult.expiryDate;

  await db.collection('users').doc(userId).update({
    isPremium: true,
    premiumTier: subscriptionTier,
    subscriptionExpiryDate: expiryDate,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Grant consumables based on tier
  const consumables = getConsumablesForTier(subscriptionTier);
  await db.collection('users').doc(userId).update(consumables);
}

async function warnUser(userId, reason) {
  await db.collection('user_warnings').add({
    userId,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    acknowledged: false
  });

  // Check warning count
  const warnings = await db.collection('user_warnings')
    .where('userId', '==', userId)
    .where('acknowledged', '==', false)
    .get();

  // Suspend if too many warnings
  if (warnings.size >= 3) {
    await db.collection('users').doc(userId).update({
      suspended: true,
      suspensionReason: 'Multiple violations',
      suspendedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.warn('User suspended', { userId, warningCount: warnings.size });
  }
}

async function verifyAdminToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return false;
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await auth.verifyIdToken(token);

    // Check if user has admin claim
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();
    return userDoc.exists && userDoc.data().isAdmin === true;
  } catch (error) {
    functions.logger.error('Admin token verification failed', { error: error.message });
    return false;
  }
}

function getSubscriptionTier(productId) {
  if (productId.includes('premium')) return 'premium';
  if (productId.includes('plus')) return 'plus';
  return 'basic';
}

function getConsumablesForTier(tier) {
  const consumables = {
    basic: { superLikesRemaining: 1, boostsRemaining: 0, rewindsRemaining: 0 },
    plus: { superLikesRemaining: 5, boostsRemaining: 1, rewindsRemaining: 3 },
    premium: { superLikesRemaining: 999, boostsRemaining: 999, rewindsRemaining: 999 }
  };
  return consumables[tier] || consumables.basic;
}

// ============================================================================
// PUSH NOTIFICATIONS
// ============================================================================

/**
 * Sends a match notification
 */
exports.sendMatchNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, matchData } = data;

  try {
    await notifications.sendMatchNotification(userId, matchData);
    return { success: true };
  } catch (error) {
    functions.logger.error('Send match notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a message notification
 */
exports.sendMessageNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, messageData } = data;

  try {
    await notifications.sendMessageNotification(userId, messageData);
    return { success: true };
  } catch (error) {
    functions.logger.error('Send message notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a like notification (premium users only)
 */
exports.sendLikeNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, likeData } = data;

  try {
    await notifications.sendLikeNotification(userId, likeData);
    return { success: true };
  } catch (error) {
    functions.logger.error('Send like notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a warning notification to a user
 * Called by admin when issuing a warning
 */
exports.sendWarningNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, reason, warningCount } = data;

  try {
    await notifications.sendWarningNotification(userId, { reason, warningCount });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send warning notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a suspension notification to a user
 * Called by admin when suspending an account
 */
exports.sendSuspensionNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, reason, days, suspendedUntil } = data;

  try {
    await notifications.sendSuspensionNotification(userId, { reason, days, suspendedUntil });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send suspension notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a ban notification to a user
 * Called by admin when permanently banning an account
 */
exports.sendBanNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, reason } = data;

  try {
    await notifications.sendBanNotification(userId, { reason });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send ban notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a notification to the reporter when their report is resolved
 * Called by admin after reviewing a report
 */
exports.sendReportResolvedNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { reporterId, action, reportId } = data;

  try {
    await notifications.sendReportResolvedNotification(reporterId, { action, reportId });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send report resolved notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends an appeal resolution notification to a user
 * Called when admin approves or rejects an appeal
 */
exports.sendAppealResolvedNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, approved, response } = data;

  try {
    await notifications.sendAppealResolvedNotification(userId, approved, response);
    return { success: true };
  } catch (error) {
    functions.logger.error('Send appeal resolved notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends a profile status notification to a user
 * Called when profile is approved or rejected
 */
exports.sendProfileStatusNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, status, reason, reasonCode } = data;

  try {
    await notifications.sendProfileStatusNotification(userId, { status, reason, reasonCode });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send profile status notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Sends an ID verification rejection notification to a user
 * Called by admin when rejecting ID verification
 */
exports.sendIDVerificationRejectionNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, reason } = data;

  try {
    await notifications.sendIDVerificationRejectionNotification(userId, { reason });
    return { success: true };
  } catch (error) {
    functions.logger.error('Send ID verification rejection notification error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Scheduled function to send daily engagement reminders
 * Runs daily at 9 AM and 7 PM
 */
exports.sendDailyReminders = functions.pubsub
  .schedule('0 9,19 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    try {
      const result = await notifications.sendDailyEngagementReminders();
      functions.logger.info('Daily reminders sent', result);
      return result;
    } catch (error) {
      functions.logger.error('Daily reminders error', { error: error.message });
      return { error: error.message };
    }
  });

// ============================================================================
// PERFORMANCE MONITORING
// ============================================================================

/**
 * Get performance dashboard (admin only)
 * Returns API performance, query performance, and slow queries
 */
exports.getPerformanceDashboard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  // Check admin permissions
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const { days } = data;
    const dashboard = await performanceMonitoring.getPerformanceDashboard(days || 7);

    return dashboard;
  } catch (error) {
    functions.logger.error('Get performance dashboard error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Track slow query (for manual reporting from client)
 */
exports.reportSlowQuery = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { collection, operation, duration, resultCount } = data;

  if (!collection || !operation || !duration) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    await performanceMonitoring.trackQuery(collection, operation, duration, resultCount || 0);

    return { success: true };
  } catch (error) {
    functions.logger.error('Report slow query error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// PHOTO VERIFICATION
// ============================================================================

/**
 * Verify user photo using AI face matching
 * Compares selfie with profile photos to prevent catfishing
 * SECURITY: Rate limited to 3 attempts per day
 */
exports.verifyPhoto = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { selfieBase64 } = data;
  const userId = context.auth.uid;

  // Validate input
  if (!selfieBase64) {
    throw new functions.https.HttpsError('invalid-argument', 'Selfie image is required');
  }

  try {
    functions.logger.info('Photo verification requested', { userId });

    // Perform verification
    const result = await photoVerification.verifyUserPhoto(userId, selfieBase64);

    return result;

  } catch (error) {
    functions.logger.error('Photo verification error', {
      userId,
      error: error.message
    });

    // Return user-friendly error
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Photo verification failed'
    );
  }
});

/**
 * Check if user's verification has expired
 */
exports.checkVerificationStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  try {
    const isExpired = await photoVerification.isVerificationExpired(userId);

    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    return {
      isVerified: userData?.isVerified || false,
      isExpired,
      verifiedAt: userData?.verifiedAt || null,
      verificationExpiry: userData?.verificationExpiry || null,
      verificationConfidence: userData?.verificationConfidence || 0
    };
  } catch (error) {
    functions.logger.error('Check verification status error', { userId, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get verification statistics (admin only)
 */
exports.getVerificationStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  // Check admin permissions
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const { days } = data;
    const stats = await photoVerification.getVerificationStats(days || 30);

    return stats;
  } catch (error) {
    functions.logger.error('Get verification stats error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// IMAGE OPTIMIZATION - CDN & RESPONSIVE IMAGES
// ============================================================================

/**
 * Optimize and upload photo to CDN
 * Processes photo: WebP conversion, responsive variants, CDN upload
 * Returns optimized URLs for all sizes
 */
exports.optimizePhoto = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { photoBase64, folder = 'profile-photos', useCDN = true } = data;

  if (!photoBase64) {
    throw new functions.https.HttpsError('invalid-argument', 'Photo data is required');
  }

  try {
    functions.logger.info('Optimizing photo', { userId, useCDN });

    const result = await imageOptimization.processUploadedPhoto(
      userId,
      photoBase64,
      { folder, useCDN }
    );

    functions.logger.info('Photo optimized successfully', {
      userId,
      cdnUrl: result.photoData.cdnUrl || 'local'
    });

    return result;
  } catch (error) {
    functions.logger.error('Photo optimization error', {
      userId,
      error: error.message
    });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get optimized image URL with custom transformations
 * Supports responsive sizing, quality adjustment, format conversion
 */
exports.getOptimizedImageURL = functions.https.onCall(async (data, context) => {
  const { publicId, width, height, quality, format } = data;

  if (!publicId) {
    throw new functions.https.HttpsError('invalid-argument', 'Public ID is required');
  }

  try {
    const url = imageOptimization.getOptimizedURL(publicId, {
      width,
      height,
      quality,
      format
    });

    return { url };
  } catch (error) {
    functions.logger.error('Get optimized URL error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Migrate existing Firebase Storage images to Cloudinary CDN
 * Admin only - for batch migration of existing photos
 */
exports.migrateImageToCDN = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  // Check admin permissions
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { firebaseUrl } = data;

  if (!firebaseUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'Firebase URL is required');
  }

  try {
    functions.logger.info('Migrating image to CDN', { firebaseUrl });

    const result = await imageOptimization.migrateToCloudinary(firebaseUrl);

    return result;
  } catch (error) {
    functions.logger.error('Migration error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Delete image from CDN
 */
exports.deleteOptimizedImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { publicId } = data;

  if (!publicId) {
    throw new functions.https.HttpsError('invalid-argument', 'Public ID is required');
  }

  try {
    // Verify user owns the image (publicId should contain userId)
    if (!publicId.includes(userId)) {
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You can only delete your own images'
        );
      }
    }

    const result = await imageOptimization.deleteFromCloudinary(publicId);

    functions.logger.info('Image deleted from CDN', { userId, publicId });

    return result;
  } catch (error) {
    functions.logger.error('Image deletion error', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// PHONE VERIFICATION
// ============================================================================

/**
 * Verify phone number status
 * Returns verification details for a user
 */
exports.getPhoneVerificationStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();

    return {
      phoneVerified: userData.phoneVerified || false,
      phoneNumber: userData.phoneNumber || null,
      phoneVerifiedAt: userData.phoneVerifiedAt || null,
      verificationMethods: userData.verificationMethods || []
    };
  } catch (error) {
    functions.logger.error('Failed to get phone verification status', { error: error.message, userId });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Admin: Get users by phone verification status
 * Admin-only endpoint for moderation
 */
exports.getUsersByPhoneStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  // Check admin permissions
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { verified, limit = 100 } = data;

  try {
    let query = db.collection('users');

    if (verified !== undefined) {
      query = query.where('phoneVerified', '==', verified);
    }

    const snapshot = await query.limit(limit).get();

    const users = snapshot.docs.map(doc => ({
      userId: doc.id,
      phoneNumber: doc.data().phoneNumber,
      phoneVerified: doc.data().phoneVerified,
      phoneVerifiedAt: doc.data().phoneVerifiedAt,
      createdAt: doc.data().createdAt
    }));

    return {
      users,
      count: users.length,
      verifiedCount: users.filter(u => u.phoneVerified).length,
      unverifiedCount: users.filter(u => !u.phoneVerified).length
    };
  } catch (error) {
    functions.logger.error('Failed to get users by phone status', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Admin: Manually verify/unverify phone number
 * For special cases or dispute resolution
 */
exports.adminUpdatePhoneVerification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const adminId = context.auth.uid;

  // Check admin permissions
  const adminDoc = await db.collection('users').doc(adminId).get();
  if (!adminDoc.exists || !adminDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { userId, phoneVerified, reason } = data;

  if (!userId || phoneVerified === undefined) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and phoneVerified are required');
  }

  try {
    await db.collection('users').doc(userId).update({
      phoneVerified,
      phoneVerificationUpdatedBy: adminId,
      phoneVerificationUpdateReason: reason || 'Manual admin update',
      phoneVerificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Log the admin action
    await db.collection('adminLogs').add({
      adminId,
      action: 'update_phone_verification',
      targetUserId: userId,
      newStatus: phoneVerified,
      reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info('Admin updated phone verification', {
      adminId,
      userId,
      phoneVerified,
      reason
    });

    return {
      success: true,
      message: `Phone verification ${phoneVerified ? 'enabled' : 'disabled'} for user ${userId}`
    };
  } catch (error) {
    functions.logger.error('Failed to update phone verification', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// REPORTING & MODERATION SYSTEM
// ============================================================================

/**
 * Get moderation queue for admin review
 * Returns pending reports and suspicious profiles
 */
exports.getModerationQueue = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const adminId = context.auth.uid;

  // Check admin permissions
  const adminDoc = await db.collection('users').doc(adminId).get();
  if (!adminDoc.exists || !adminDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { status = 'pending', limit = 50, offset = 0 } = data;

  try {
    // Get reports
    let reportsQuery = db.collection('reports');
    if (status) {
      reportsQuery = reportsQuery.where('status', '==', status);
    }

    const reportsSnapshot = await reportsQuery
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .offset(offset)
      .get();

    const reports = await Promise.all(
      reportsSnapshot.docs.map(async (doc) => {
        const reportData = doc.data();

        // Fetch reporter and reported user data
        const [reporterDoc, reportedDoc] = await Promise.all([
          db.collection('users').doc(reportData.reporterId).get(),
          db.collection('users').doc(reportData.reportedUserId).get()
        ]);

        return {
          id: doc.id,
          ...reportData,
          reporter: reporterDoc.exists ? {
            id: reporterDoc.id,
            name: reporterDoc.data().fullName,
            email: reporterDoc.data().email
          } : null,
          reportedUser: reportedDoc.exists ? {
            id: reportedDoc.id,
            name: reportedDoc.data().fullName,
            email: reportedDoc.data().email,
            photoURL: reportedDoc.data().profilePhotoURL
          } : null,
          timestamp: reportData.timestamp?.toDate().toISOString()
        };
      })
    );

    // Get moderation queue (suspicious profiles)
    const moderationSnapshot = await db.collection('moderationQueue')
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    const moderationQueue = await Promise.all(
      moderationSnapshot.docs.map(async (doc) => {
        const queueData = doc.data();
        const userDoc = await db.collection('users').doc(queueData.reportedUserId).get();

        return {
          id: doc.id,
          ...queueData,
          user: userDoc.exists ? {
            id: userDoc.id,
            name: userDoc.data().fullName,
            photoURL: userDoc.data().profilePhotoURL
          } : null,
          timestamp: queueData.timestamp?.toDate().toISOString()
        };
      })
    );

    return {
      reports,
      moderationQueue,
      stats: {
        totalReports: reports.length,
        pendingReports: reports.filter(r => r.status === 'pending').length,
        resolvedReports: reports.filter(r => r.status === 'resolved').length,
        suspiciousProfiles: moderationQueue.length
      }
    };
  } catch (error) {
    functions.logger.error('Failed to get moderation queue', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Admin: Take action on a report
 * Actions: dismiss, warn, suspend, ban
 */
exports.moderateReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const adminId = context.auth.uid;

  // Check admin permissions
  const adminDoc = await db.collection('users').doc(adminId).get();
  if (!adminDoc.exists || !adminDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { reportId, action, reason, duration } = data;

  if (!reportId || !action) {
    throw new functions.https.HttpsError('invalid-argument', 'reportId and action are required');
  }

  try {
    // Get report details
    const reportDoc = await db.collection('reports').doc(reportId).get();
    if (!reportDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Report not found');
    }

    const reportData = reportDoc.data();
    const reportedUserId = reportData.reportedUserId;

    // Update report status
    await db.collection('reports').doc(reportId).update({
      status: 'resolved',
      action,
      moderatedBy: adminId,
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderationReason: reason || ''
    });

    // Take action based on type
    switch (action) {
      case 'dismiss':
        break;

      case 'warn':
        await db.collection('users').doc(reportedUserId).update({
          warnings: admin.firestore.FieldValue.increment(1),
          lastWarnedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        break;

      case 'suspend':
        const suspendUntil = new Date();
        suspendUntil.setDate(suspendUntil.getDate() + (duration || 7));
        await db.collection('users').doc(reportedUserId).update({
          suspended: true,
          suspendedUntil: admin.firestore.Timestamp.fromDate(suspendUntil)
        });
        break;

      case 'ban':
        await db.collection('users').doc(reportedUserId).update({
          banned: true,
          bannedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        await auth.updateUser(reportedUserId, { disabled: true });
        break;
    }

    return { success: true };
  } catch (error) {
    functions.logger.error('Failed to moderate report', { error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Trigger: Auto-notify admins when new report created
 * Sends PUSH notification to admin devices AND creates in-app notification
 */
exports.onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    const reportId = context.params.reportId;

    functions.logger.info('New report created - notifying admins', {
      reportId,
      reason: reportData.reason,
      reportedUserId: reportData.reportedUserId
    });

    try {
      // Get reporter and reported user names for better notification
      let reporterName = 'A user';
      let reportedUserName = 'another user';

      if (reportData.reporterId) {
        const reporterDoc = await db.collection('users').doc(reportData.reporterId).get();
        if (reporterDoc.exists) {
          reporterName = reporterDoc.data().firstName || reporterDoc.data().fullName || 'A user';
        }
      }

      if (reportData.reportedUserId) {
        const reportedDoc = await db.collection('users').doc(reportData.reportedUserId).get();
        if (reportedDoc.exists) {
          reportedUserName = reportedDoc.data().firstName || reportedDoc.data().fullName || 'a user';
        }
      }

      // Send PUSH notification to all admins
      await notifications.sendAdminNotification({
        title: '🚨 New Report Submitted',
        body: `${reporterName} reported ${reportedUserName}: ${reportData.reason || 'No reason provided'}`,
        alertType: 'new_report',
        badge: 1,
        data: {
          reportId: reportId,
          reporterId: reportData.reporterId || '',
          reportedUserId: reportData.reportedUserId || '',
          reason: reportData.reason || ''
        }
      });

      // Also create in-app notifications for admins
      const adminsSnapshot = await db.collection('users').where('isAdmin', '==', true).get();

      await Promise.all(adminsSnapshot.docs.map(adminDoc =>
        db.collection('notifications').add({
          userId: adminDoc.id,
          type: 'new_report',
          title: 'New Report',
          message: `${reporterName} reported ${reportedUserName}: ${reportData.reason}`,
          reportId: reportId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        })
      ));

      functions.logger.info('Admin notifications sent for report', { reportId });

    } catch (error) {
      functions.logger.error('Error notifying admins of new report', {
        reportId,
        error: error.message
      });
    }
  });

/**
 * Trigger: Notify admins when user submits an appeal
 * Sends PUSH notification to admins for review
 */
exports.onAppealSubmitted = functions.firestore
  .document('appeals/{appealId}')
  .onCreate(async (snap, context) => {
    const appealData = snap.data();
    const appealId = context.params.appealId;

    functions.logger.info('New appeal submitted', {
      appealId,
      userId: appealData.userId,
      type: appealData.type
    });

    try {
      const userName = appealData.userName || 'A user';
      const appealType = appealData.type || 'account';

      let title = '📩 New Appeal Submitted';
      let body = `${userName} has appealed their ${appealType} decision`;

      if (appealType === 'suspension') {
        title = '📩 Suspension Appeal';
        body = `${userName} is appealing their account suspension`;
      } else if (appealType === 'ban') {
        title = '📩 Ban Appeal';
        body = `${userName} is appealing their permanent ban`;
      } else if (appealType === 'rejection') {
        title = '📩 Profile Rejection Appeal';
        body = `${userName} is appealing their profile rejection`;
      }

      // Send PUSH notification to all admins
      await notifications.sendAdminNotification({
        title: title,
        body: body,
        alertType: 'new_appeal',
        badge: 1,
        data: {
          appealId: appealId,
          userId: appealData.userId || '',
          userName: userName,
          type: appealType,
          appealMessage: (appealData.appealMessage || '').substring(0, 100)
        }
      });

      functions.logger.info('Admin notified of new appeal', { appealId });

    } catch (error) {
      functions.logger.error('Error notifying admins of appeal', {
        appealId,
        error: error.message
      });
    }
  });

/**
 * Trigger: Notify admins when suspicious profile is detected
 * Sends PUSH notification when content moderation flags a profile
 */
exports.onSuspiciousProfileDetected = functions.firestore
  .document('moderationQueue/{itemId}')
  .onCreate(async (snap, context) => {
    const queueData = snap.data();
    const itemId = context.params.itemId;

    functions.logger.info('Suspicious profile added to moderation queue', {
      itemId,
      type: queueData.type,
      userId: queueData.userId || queueData.reportedUserId
    });

    try {
      const userId = queueData.userId || queueData.reportedUserId;
      let userName = 'Unknown user';

      // Get user info
      if (userId) {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userName = userDoc.data().firstName || userDoc.data().fullName || 'A user';
        }
      }

      // Determine notification title based on type
      let title = '⚠️ Suspicious Activity Detected';
      let body = `${userName} has been flagged for review`;

      if (queueData.type === 'inappropriate_profile_photo') {
        title = '🖼️ Inappropriate Photo Detected';
        body = `${userName} uploaded an inappropriate profile photo`;
      } else if (queueData.type === 'inappropriate_gallery_photo') {
        title = '🖼️ Gallery Photo Flagged';
        body = `${userName} uploaded an inappropriate gallery photo`;
      } else if (queueData.type === 'spam' || queueData.reason?.toLowerCase().includes('spam')) {
        title = '🚫 Spam Detected';
        body = `${userName} has been flagged for spam activity`;
      } else if (queueData.type === 'fake_profile' || queueData.reason?.toLowerCase().includes('fake')) {
        title = '🎭 Possible Fake Profile';
        body = `${userName} may be a fake profile`;
      } else if (queueData.severity === 'high') {
        title = '🔴 High Priority Alert';
        body = `${userName} flagged with high severity: ${queueData.reason || 'Review required'}`;
      }

      // Send PUSH notification to all admins
      await notifications.sendAdminNotification({
        title: title,
        body: body,
        alertType: 'suspicious_profile',
        badge: 1,
        data: {
          queueItemId: itemId,
          userId: userId || '',
          userName: userName,
          type: queueData.type || 'unknown',
          severity: queueData.severity || 'medium',
          reason: queueData.reason || ''
        }
      });

      functions.logger.info('Admin notified of suspicious profile', { itemId, userId });

    } catch (error) {
      functions.logger.error('Error notifying admins of suspicious profile', {
        itemId,
        error: error.message
      });
    }
  });

/**
 * Trigger: Notify admins when flagged content is detected
 * This catches inappropriate photos, text, etc. that were auto-flagged
 */
exports.onFlaggedContentCreated = functions.firestore
  .document('flagged_content/{contentId}')
  .onCreate(async (snap, context) => {
    const contentData = snap.data();
    const contentId = context.params.contentId;

    // Only send push for high severity content
    if (contentData.severity !== 'high') {
      functions.logger.info('Low/medium severity content flagged - skipping push', {
        contentId,
        severity: contentData.severity
      });
      return;
    }

    functions.logger.info('High severity content flagged - notifying admins', {
      contentId,
      type: contentData.contentType,
      severity: contentData.severity
    });

    try {
      const userId = contentData.userId;
      let userName = 'Unknown user';

      if (userId && userId !== 'unknown') {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userName = userDoc.data().firstName || userDoc.data().fullName || 'A user';
        }
      }

      let title = '🔴 Content Violation Detected';
      let body = `High severity ${contentData.contentType || 'content'} flagged from ${userName}`;

      if (contentData.contentType === 'photo') {
        title = '🔴 Inappropriate Photo Detected';
        body = `${userName}'s photo was auto-removed: ${contentData.reason || 'Policy violation'}`;
      } else if (contentData.contentType === 'text' || contentData.contentType === 'message') {
        title = '🔴 Inappropriate Text Detected';
        body = `${userName} sent inappropriate content: ${contentData.reason || 'Policy violation'}`;
      }

      // Send PUSH notification to all admins
      await notifications.sendAdminNotification({
        title: title,
        body: body,
        alertType: 'flagged_content',
        badge: 1,
        data: {
          contentId: contentId,
          userId: userId || '',
          userName: userName,
          contentType: contentData.contentType || 'unknown',
          severity: contentData.severity || 'high',
          reason: contentData.reason || ''
        }
      });

      functions.logger.info('Admin notified of flagged content', { contentId, userId });

    } catch (error) {
      functions.logger.error('Error notifying admins of flagged content', {
        contentId,
        error: error.message
      });
    }
  });

/**
 * Trigger: Auto-set isAdmin for whitelisted email addresses
 * When a user document is created, check if their email is in the admin whitelist
 * and set isAdmin: true if so
 * Also notifies admins when new accounts need approval
 */
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const userId = context.params.userId;

    // Admin email whitelist - must match SettingsView.swift whitelist
    const adminEmails = ['perezkevin640@gmail.com', 'admin@celestia.app'];

    // Check if this is an admin user
    const isAdminUser = userData.email && adminEmails.includes(userData.email.toLowerCase());

    if (isAdminUser) {
      try {
        await snap.ref.update({
          isAdmin: true
        });

        functions.logger.info('Admin access granted to user', {
          userId,
          email: userData.email
        });
      } catch (error) {
        functions.logger.error('Failed to set admin access', {
          userId,
          email: userData.email,
          error: error.message
        });
      }
    }

    // Send push notification to admins when new account needs approval
    // Only for non-admin users with pending status
    if (!isAdminUser && userData.profileStatus === 'pending') {
      try {
        await notifications.sendNewAccountNotification({
          userId: userId,
          firstName: userData.firstName,
          fullName: userData.fullName,
          email: userData.email
        });

        functions.logger.info('Admin notified of new pending account', {
          userId,
          userName: userData.firstName || userData.fullName
        });
      } catch (error) {
        functions.logger.error('Failed to notify admins of new account', {
          userId,
          error: error.message
        });
      }
    }
  });

/**
 * Trigger: Check for admin access on user update (for existing users)
 * If an existing user updates their document and their email is in the admin whitelist
 * but isAdmin is not set, set it automatically
 */
exports.onUserUpdated = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userData = change.after.data();
    const previousData = change.before.data();
    const userId = context.params.userId;

    // Handle profile status changes (approval/rejection notifications)
    if (previousData.profileStatus !== userData.profileStatus) {
      functions.logger.info('Profile status changed', {
        userId,
        from: previousData.profileStatus,
        to: userData.profileStatus
      });

      try {
        // Send notification for approved or rejected profiles
        if (userData.profileStatus === 'active' && previousData.profileStatus === 'pending') {
          await notifications.sendProfileStatusNotification(userId, {
            status: 'approved'
          });
        } else if (userData.profileStatus === 'rejected') {
          await notifications.sendProfileStatusNotification(userId, {
            status: 'rejected',
            reason: userData.profileStatusReason,
            reasonCode: userData.profileStatusReasonCode
          });
        }
        // Notify admins when user resubmits profile for review
        else if (userData.profileStatus === 'pending' && previousData.profileStatus === 'rejected') {
          await notifications.sendAdminNotification({
            title: '🔄 Profile Resubmitted',
            body: `${userData.firstName || userData.fullName || 'A user'} has updated their profile and resubmitted for review`,
            alertType: 'profile_resubmitted',
            badge: 1,
            data: {
              userId: userId,
              userName: userData.firstName || userData.fullName || '',
              userEmail: userData.email || ''
            }
          });
        }
      } catch (error) {
        functions.logger.error('Failed to send profile status notification', {
          userId,
          error: error.message
        });
      }
    }

    // Skip admin check if isAdmin is already true
    if (userData.isAdmin === true) {
      return;
    }

    // Admin email whitelist
    const adminEmails = ['perezkevin640@gmail.com', 'admin@celestia.app'];

    // If email is in whitelist and isAdmin is not set, set it
    if (userData.email && adminEmails.includes(userData.email.toLowerCase())) {
      // Only update if isAdmin field is missing or false
      if (previousData.isAdmin !== true) {
        try {
          await change.after.ref.update({
            isAdmin: true
          });

          functions.logger.info('Admin access granted to existing user', {
            userId,
            email: userData.email
          });
        } catch (error) {
          functions.logger.error('Failed to set admin access on update', {
            userId,
            error: error.message
          });
        }
      }
    }
  });

// ============================================================================
// FIRESTORE TRIGGERS - AUTOMATIC PUSH NOTIFICATIONS
// ============================================================================

/**
 * Firestore Trigger: Send push notifications when a new match is created
 * Triggers automatically on match creation - sends notification to both users
 */
exports.onMatchCreated = functions.firestore
  .document('matches/{matchId}')
  .onCreate(async (snap, context) => {
    try {
      const match = snap.data();
      const matchId = context.params.matchId;

      functions.logger.info('New match created - sending notifications', {
        matchId,
        user1Id: match.user1Id,
        user2Id: match.user2Id
      });

      // Get both users' data
      const [user1Doc, user2Doc] = await Promise.all([
        db.collection('users').doc(match.user1Id).get(),
        db.collection('users').doc(match.user2Id).get()
      ]);

      if (!user1Doc.exists || !user2Doc.exists) {
        functions.logger.error('Match users not found', { matchId });
        return;
      }

      const user1 = user1Doc.data();
      const user2 = user2Doc.data();

      // Send notification to user1 about user2
      const notifyUser1 = notifications.sendMatchNotification(match.user1Id, {
        matchId,
        matchedUserId: match.user2Id,
        matchedUserName: user2.firstName || 'Someone',
        matchedUserPhoto: user2.photos && user2.photos.length > 0 ? user2.photos[0] : null
      }).catch(err => {
        functions.logger.error('Failed to send match notification to user1', {
          userId: match.user1Id,
          error: err.message
        });
      });

      // Send notification to user2 about user1
      const notifyUser2 = notifications.sendMatchNotification(match.user2Id, {
        matchId,
        matchedUserId: match.user1Id,
        matchedUserName: user1.firstName || 'Someone',
        matchedUserPhoto: user1.photos && user1.photos.length > 0 ? user1.photos[0] : null
      }).catch(err => {
        functions.logger.error('Failed to send match notification to user2', {
          userId: match.user2Id,
          error: err.message
        });
      });

      // Send both notifications in parallel
      await Promise.allSettled([notifyUser1, notifyUser2]);

      functions.logger.info('Match notifications sent successfully', { matchId });

    } catch (error) {
      functions.logger.error('onMatchCreated trigger error', {
        matchId: context.params.matchId,
        error: error.message
      });
    }
  });

/**
 * Firestore Trigger: Send push notifications when a new message is created
 * Triggers automatically on message creation - sends notification to recipient
 */
exports.onMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const message = snap.data();
      const messageId = context.params.messageId;

      // Don't send notification if sender is the same as receiver (shouldn't happen)
      if (message.senderId === message.receiverId) {
        return;
      }

      functions.logger.info('New message created - sending notification', {
        messageId,
        senderId: message.senderId,
        receiverId: message.receiverId
      });

      // Get sender's data
      const senderDoc = await db.collection('users').doc(message.senderId).get();

      if (!senderDoc.exists) {
        functions.logger.error('Message sender not found', { messageId, senderId: message.senderId });
        return;
      }

      const sender = senderDoc.data();

      // Send notification to receiver
      await notifications.sendMessageNotification(message.receiverId, {
        matchId: message.matchId,
        messageId,
        senderId: message.senderId,
        senderName: sender.firstName || 'Someone',
        text: message.text || '',
        hasImage: !!message.imageUrl,
        imageUrl: sender.photos && sender.photos.length > 0 ? sender.photos[0] : null
      });

      functions.logger.info('Message notification sent successfully', { messageId });

    } catch (error) {
      functions.logger.error('onMessageCreated trigger error', {
        messageId: context.params.messageId,
        error: error.message
      });
    }
  });

/**
 * Firestore Trigger: Send push notifications when a user receives a like
 * Triggers automatically on like creation - sends notification to liked user (premium only)
 */
exports.onLikeCreated = functions.firestore
  .document('likes/{likeId}')
  .onCreate(async (snap, context) => {
    try {
      const like = snap.data();
      const likeId = context.params.likeId;

      functions.logger.info('New like created - checking if notification needed', {
        likeId,
        likerId: like.userId,
        targetUserId: like.targetUserId
      });

      // Get liker's data
      const likerDoc = await db.collection('users').doc(like.userId).get();

      if (!likerDoc.exists) {
        functions.logger.error('Liker not found', { likeId, likerId: like.userId });
        return;
      }

      const liker = likerDoc.data();

      // Send notification to target user (premium users only - handled in sendLikeNotification)
      await notifications.sendLikeNotification(like.targetUserId, {
        likerId: like.userId,
        likerName: liker.firstName || 'Someone',
        likerPhoto: liker.photos && liker.photos.length > 0 ? liker.photos[0] : null,
        isSuperLike: like.isSuperLike || false
      });

      functions.logger.info('Like notification sent successfully', { likeId });

    } catch (error) {
      functions.logger.error('onLikeCreated trigger error', {
        likeId: context.params.likeId,
        error: error.message
      });
    }
  });

/**
 * Admin Function: Ban user directly (without needing a report)
 * Used from AdminUserInvestigationView and SuspiciousProfileDetailView
 */
exports.banUserDirectly = functions.https.onCall(async (data, context) => {
  // SECURITY: Verify admin access
  const adminId = context.auth?.uid;
  if (!adminId) {
    throw new functions.https.HttpsError('unauthenticated', 'Admin authentication required');
  }

  const adminDoc = await db.collection('users').doc(adminId).get();
  if (!adminDoc.exists || !adminDoc.data().isAdmin) {
    functions.logger.error('Unauthorized ban attempt', { adminId, targetUserId: data.userId });
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { userId, reason } = data;

  if (!userId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and reason are required');
  }

  try {
    functions.logger.info('Admin banning user directly', { adminId, userId, reason });

    // 1. Update user document in Firestore
    await db.collection('users').doc(userId).update({
      banned: true,
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      bannedReason: reason,
      bannedBy: adminId
    });

    // 2. Disable Firebase Authentication account
    try {
      await admin.auth().updateUser(userId, {
        disabled: true
      });
      functions.logger.info('User auth account disabled', { userId });
    } catch (authError) {
      functions.logger.error('Error disabling auth account', { userId, error: authError.message });
      // Continue even if auth disable fails
    }

    // 3. Send notification to banned user
    await db.collection('notifications').add({
      userId: userId,
      type: 'account_banned',
      title: 'Account Banned',
      message: `Your account has been permanently banned. Reason: ${reason}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      data: {
        reason: reason
      }
    });

    // 4. Log admin action
    await db.collection('adminLogs').add({
      adminId: adminId,
      action: 'ban_user_directly',
      targetUserId: userId,
      reason: reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info('User banned successfully', { adminId, userId });

    return {
      success: true,
      message: 'User banned successfully'
    };

  } catch (error) {
    functions.logger.error('Error banning user', { adminId, userId, error: error.message });
    throw new functions.https.HttpsError('internal', `Failed to ban user: ${error.message}`);
  }
});

// ============================================================================
// STRIPE IDENTITY VERIFICATION
// ============================================================================

/**
 * Create a Stripe Identity verification session
 * Called by the iOS app to initiate ID verification
 *
 * SETUP REQUIRED:
 * 1. npm install stripe
 * 2. firebase functions:config:set stripe.secret_key="sk_live_..."
 * 3. firebase functions:config:set stripe.webhook_secret="whsec_..."
 */
exports.createStripeIdentitySession = functions.https.onCall(async (data, context) => {
  return stripeIdentity.createVerificationSession(data, context);
});

/**
 * Check Stripe Identity verification status
 * Called to get the current status of a verification session
 */
exports.checkStripeIdentityStatus = functions.https.onCall(async (data, context) => {
  return stripeIdentity.checkVerificationStatus(data, context);
});

/**
 * Stripe webhook endpoint for verification status updates
 * Called by Stripe when verification status changes
 *
 * SETUP: Configure webhook URL in Stripe Dashboard:
 * https://us-central1-YOUR_PROJECT.cloudfunctions.net/stripeIdentityWebhook
 */
exports.stripeIdentityWebhook = functions.https.onRequest(async (req, res) => {
  return stripeIdentity.handleStripeWebhook(req, res);
});

// ============================================================================
// AUTOMATIC IMAGE MODERATION - STORAGE TRIGGERS
// ============================================================================

/**
 * Storage Trigger: Automatically moderate images when uploaded
 * Checks for nudity, violence, and other inappropriate content
 * Rejects inappropriate images and notifies the user
 */
exports.onPhotoUploaded = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;

  // Only process images
  if (!contentType || !contentType.startsWith('image/')) {
    functions.logger.info('Skipping non-image file', { filePath, contentType });
    return null;
  }

  // Skip already processed files (have _moderated suffix)
  if (filePath.includes('_moderated')) {
    return null;
  }

  // Skip thumbnails and system files
  if (filePath.includes('thumb_') || filePath.includes('.thumbnail')) {
    return null;
  }

  functions.logger.info('Processing uploaded image for moderation', {
    filePath,
    contentType,
    size: object.size
  });

  try {
    const bucket = admin.storage().bucket(object.bucket);
    const file = bucket.file(filePath);

    // Get signed URL for moderation API
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 15 * 60 * 1000 // 15 minutes
    });

    // Run content moderation
    const moderationResult = await contentModeration.moderateImage(signedUrl);

    functions.logger.info('Moderation result', {
      filePath,
      isApproved: moderationResult.isApproved,
      severity: moderationResult.severity,
      reason: moderationResult.reason
    });

    // Extract userId from path
    // Supported paths:
    // - verification/{userId}/... - ID verification photos
    // - profile_images/{userId}/... - Profile photos
    // - gallery_photos/{userId}/... - Gallery photos
    // - chat_images/{matchId}/... - Chat images (matchId, not userId)
    // - photos/{userId}/... - Generic photos
    // - profile-photos/{userId}/... - Alternative profile photos
    // - user-photos/{userId}/... - User photos
    const pathParts = filePath.split('/');
    let userId = null;
    let photoType = 'unknown';

    if (pathParts.length >= 2) {
      const folderName = pathParts[0];

      // Map folder to photo type and extract userId
      const userIdFolders = [
        'verification', 'profile_images', 'gallery_photos',
        'photos', 'profile-photos', 'user-photos'
      ];

      if (userIdFolders.includes(folderName)) {
        userId = pathParts[1];
        photoType = folderName;
      } else if (folderName === 'chat_images') {
        // Chat images use matchId - we'll still moderate but can't link to specific user
        photoType = 'chat';
        // Try to extract userId from metadata if available
      } else if (folderName === 'temp-moderation') {
        // Skip temp files used for pre-checking
        functions.logger.info('Skipping temp moderation file', { filePath });
        return null;
      }
    }

    // Log moderation result
    await db.collection('moderation_logs').add({
      filePath,
      userId: userId || 'unknown',
      photoType,
      result: moderationResult,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      fileSize: object.size,
      contentType
    });

    // If content is NOT approved, take action
    if (!moderationResult.isApproved) {
      functions.logger.warn('Inappropriate content detected - taking action', {
        filePath,
        userId,
        severity: moderationResult.severity,
        reason: moderationResult.reason
      });

      // Delete the inappropriate image
      await file.delete();
      functions.logger.info('Deleted inappropriate image', { filePath });

      // Record in flagged content
      await db.collection('flagged_content').add({
        userId: userId || 'unknown',
        contentType: 'photo',
        photoType,
        filePath,
        reason: moderationResult.reason,
        severity: moderationResult.severity,
        details: moderationResult.details,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        action: 'auto_deleted',
        reviewed: false
      });

      // Handle rejection based on photo type
      if (userId) {
        // Verification photos - update pending verification
        if (photoType === 'verification') {
          await db.collection('pendingVerifications').doc(userId).update({
            status: 'rejected',
            rejectionReason: 'Photo did not pass content moderation: ' + moderationResult.reason,
            reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
            reviewedBy: 'auto_moderation'
          });

          await db.collection('users').doc(userId).update({
            idVerificationRejected: true,
            idVerificationRejectedAt: admin.firestore.FieldValue.serverTimestamp(),
            idVerificationRejectionReason: 'Photo content not appropriate. Please submit appropriate photos.'
          });

          functions.logger.info('Updated verification status to rejected', { userId });
        }

        // Profile photos - flag user for review if severe
        if (photoType === 'profile_images' && moderationResult.severity === 'high') {
          await db.collection('users').doc(userId).update({
            profileFlagged: true,
            profileFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            profileFlagReason: 'Inappropriate profile photo uploaded'
          });

          // Add to moderation queue for admin review
          await db.collection('moderationQueue').add({
            userId,
            type: 'inappropriate_profile_photo',
            reason: moderationResult.reason,
            severity: moderationResult.severity,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'pending'
          });

          functions.logger.info('User profile flagged for review', { userId });
        }

        // Gallery photos - similar handling
        if (photoType === 'gallery_photos' && moderationResult.severity === 'high') {
          await db.collection('moderationQueue').add({
            userId,
            type: 'inappropriate_gallery_photo',
            reason: moderationResult.reason,
            severity: moderationResult.severity,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'pending'
          });
        }

        // Send notification to user
        let notificationMessage = 'Your photo was not accepted because it does not meet our community guidelines.';
        if (photoType === 'profile_images' || photoType === 'gallery_photos') {
          notificationMessage = 'Your profile photo was not accepted. Please upload appropriate photos that show your face clearly and follow our community guidelines.';
        } else if (photoType === 'chat') {
          notificationMessage = 'Your image was not sent because it does not meet our community guidelines.';
        }

        await db.collection('notifications').add({
          userId,
          type: 'photo_rejected',
          title: 'Photo Not Accepted',
          message: notificationMessage,
          photoType,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          data: {
            reason: moderationResult.reason,
            severity: moderationResult.severity,
            photoType
          }
        });
      }

      // If high severity, warn the user (increases warning count)
      if (moderationResult.severity === 'high' && userId) {
        await warnUser(userId, `Inappropriate ${photoType} photo upload: ${moderationResult.reason}`);
      }

      return { approved: false, reason: moderationResult.reason };
    }

    // Content approved
    functions.logger.info('Image passed moderation', { filePath });

    // QUARANTINE SYSTEM: Activate profile when first photo passes moderation
    // This ensures new accounts are only visible after their photos are verified
    if (userId && (photoType === 'profile_images' || photoType === 'profile-photos' || photoType === 'photos')) {
      try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          // Only activate if currently pending (don't reactivate suspended accounts)
          if (userData.profileStatus === 'pending' || !userData.profileStatus) {
            await db.collection('users').doc(userId).update({
              profileStatus: 'active',
              profileStatusReason: 'Photo passed content moderation',
              profileStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            functions.logger.info('Profile activated after photo moderation passed', { userId, photoType });
          }
        }
      } catch (activationError) {
        functions.logger.error('Error activating profile', { userId, error: activationError.message });
        // Don't fail the whole operation - photo is still approved
      }
    }

    return { approved: true };

  } catch (error) {
    functions.logger.error('Image moderation error', {
      filePath,
      error: error.message,
      stack: error.stack
    });

    // Don't delete on error - log and continue
    await db.collection('moderation_errors').add({
      filePath,
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { approved: true, error: 'Moderation check failed' };
  }
});

/**
 * Callable function to check if a photo will pass moderation before upload
 * Can be called from the iOS app to pre-check images
 */
exports.preCheckPhoto = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { photoBase64 } = data;
  const userId = context.auth.uid;

  if (!photoBase64) {
    throw new functions.https.HttpsError('invalid-argument', 'Photo data is required');
  }

  try {
    functions.logger.info('Pre-checking photo for moderation', { userId });

    // Upload temporarily to get a URL for moderation
    const bucket = admin.storage().bucket();
    const tempPath = `temp-moderation/${userId}/${Date.now()}.jpg`;
    const file = bucket.file(tempPath);

    // Decode and upload
    const buffer = Buffer.from(photoBase64, 'base64');
    await file.save(buffer, {
      metadata: { contentType: 'image/jpeg' }
    });

    // Get signed URL
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 5 * 60 * 1000 // 5 minutes
    });

    // Run moderation
    const moderationResult = await contentModeration.moderateImage(signedUrl);

    // Delete temp file
    await file.delete().catch(() => {});

    functions.logger.info('Pre-check result', {
      userId,
      isApproved: moderationResult.isApproved,
      severity: moderationResult.severity
    });

    if (!moderationResult.isApproved) {
      return {
        approved: false,
        reason: moderationResult.reason,
        message: getContentRejectionMessage(moderationResult)
      };
    }

    return {
      approved: true,
      message: 'Photo looks good!'
    };

  } catch (error) {
    functions.logger.error('Pre-check error', { userId, error: error.message });

    // On error, allow upload (will be checked on storage trigger)
    return {
      approved: true,
      message: 'Unable to pre-check, will verify after upload',
      warning: true
    };
  }
});

/**
 * Get user-friendly rejection message based on moderation result
 */
function getContentRejectionMessage(result) {
  const { details } = result;

  if (details && details.scores) {
    if (details.scores.adult >= 4) {
      return 'This photo contains adult content which is not allowed. Please choose a different photo.';
    }
    if (details.scores.violence >= 4) {
      return 'This photo contains violent content which is not allowed. Please choose a different photo.';
    }
    if (details.scores.racy >= 4) {
      return 'This photo is too revealing for our platform. Please choose a photo that follows community guidelines.';
    }
  }

  return 'This photo does not meet our community guidelines. Please choose a different photo.';
}

// ============================================================================
// ADMIN NOTIFICATIONS FOR NEW ACCOUNTS
// ============================================================================

/**
 * Admin emails that should receive notifications for new pending accounts
 */
const ADMIN_EMAILS = ['perezkevin640@gmail.com', 'admin@celestia.app'];

/**
 * Firestore trigger: Notify admin when a new user account is created
 * Sends push notification to admin devices
 */
exports.onNewUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snapshot, context) => {
    const userData = snapshot.data();
    const userId = context.params.userId;

    functions.logger.info('New user created', {
      userId,
      email: userData.email,
      profileStatus: userData.profileStatus
    });

    // Only notify for pending accounts
    if (userData.profileStatus !== 'pending') {
      return null;
    }

    try {
      // Find admin users and their FCM tokens
      const adminSnapshot = await db.collection('users')
        .where('email', 'in', ADMIN_EMAILS)
        .get();

      if (adminSnapshot.empty) {
        functions.logger.warn('No admin users found to notify');
        return null;
      }

      const notificationPromises = [];

      for (const adminDoc of adminSnapshot.docs) {
        const adminData = adminDoc.data();
        const fcmToken = adminData.fcmToken;

        if (!fcmToken) {
          functions.logger.info('Admin has no FCM token', { adminEmail: adminData.email });
          continue;
        }

        // Send push notification
        const message = {
          token: fcmToken,
          notification: {
            title: '🆕 New Account Pending',
            body: `${userData.fullName || 'New user'} (${userData.email}) needs approval`
          },
          data: {
            type: 'admin_pending_account',
            userId: userId,
            userName: userData.fullName || '',
            userEmail: userData.email || ''
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'content-available': 1
              }
            }
          }
        };

        notificationPromises.push(
          admin.messaging().send(message)
            .then(() => {
              functions.logger.info('Admin notified of new pending account', {
                adminEmail: adminData.email,
                newUserId: userId
              });
            })
            .catch(err => {
              functions.logger.error('Failed to notify admin', {
                error: err.message,
                adminEmail: adminData.email
              });
            })
        );
      }

      await Promise.all(notificationPromises);

      // Also store in admin_alerts collection for dashboard
      await db.collection('admin_alerts').add({
        type: 'new_pending_account',
        userId: userId,
        userName: userData.fullName || 'Unknown',
        userEmail: userData.email || '',
        userPhoto: userData.profileImageURL || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

      return null;
    } catch (error) {
      functions.logger.error('Error notifying admin of new user', { error: error.message });
      return null;
    }
  });

/**
 * Firestore trigger: Notify admin when a user updates to pending status
 * (e.g., after editing profile that requires re-approval)
 */
exports.onUserStatusChangedToPending = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    // Only trigger if profileStatus changed TO pending
    if (beforeData.profileStatus === afterData.profileStatus ||
        afterData.profileStatus !== 'pending') {
      return null;
    }

    functions.logger.info('User profile changed to pending', {
      userId,
      previousStatus: beforeData.profileStatus
    });

    try {
      // Find admin users and their FCM tokens
      const adminSnapshot = await db.collection('users')
        .where('email', 'in', ADMIN_EMAILS)
        .get();

      if (adminSnapshot.empty) {
        return null;
      }

      for (const adminDoc of adminSnapshot.docs) {
        const adminData = adminDoc.data();
        const fcmToken = adminData.fcmToken;

        if (!fcmToken) continue;

        const message = {
          token: fcmToken,
          notification: {
            title: '👤 Profile Needs Re-approval',
            body: `${afterData.fullName || 'User'} updated their profile`
          },
          data: {
            type: 'admin_pending_account',
            userId: userId
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            }
          }
        };

        await admin.messaging().send(message).catch(() => {});
      }

      return null;
    } catch (error) {
      functions.logger.error('Error notifying admin of status change', { error: error.message });
      return null;
    }
  });

// ============================================================================
// ONE-TIME MIGRATION: Set existing users to active
// ============================================================================

/**
 * Migration function to set all existing users without profileStatus to "active"
 * This is for users created before the approval workflow was implemented
 * Call via: firebase functions:shell then migrateExistingUsersToActive()
 */
exports.migrateExistingUsersToActive = functions.https.onRequest(async (req, res) => {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Verify admin
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);

    if (!ADMIN_EMAILS.includes(decodedToken.email?.toLowerCase())) {
      return res.status(403).json({ error: 'Admin access required' });
    }

    // Get all users without profileStatus = 'active'
    const usersSnapshot = await db.collection('users').get();

    let updatedCount = 0;
    let skippedCount = 0;
    const batch = db.batch();

    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const currentStatus = data.profileStatus;

      // Skip if already active or explicitly set to something else that should be preserved
      if (currentStatus === 'active') {
        skippedCount++;
        continue;
      }

      // Only migrate users that have no status or have 'pending' (legacy)
      // Skip suspended/banned/rejected users
      if (currentStatus && ['suspended', 'banned', 'rejected'].includes(currentStatus)) {
        skippedCount++;
        continue;
      }

      batch.update(doc.ref, {
        profileStatus: 'active',
        profileStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    functions.logger.info('Migration completed', { updatedCount, skippedCount });
    res.json({
      success: true,
      message: `Migration complete. Updated ${updatedCount} users, skipped ${skippedCount} users.`
    });
  } catch (error) {
    functions.logger.error('Migration error', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

// NOTE: Do NOT export admin or db here - it causes stack overflow in firebase-functions loader
// Modules should initialize firebase-admin themselves if needed
