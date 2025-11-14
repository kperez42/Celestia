/**
 * Celestia Backend API - Cloud Functions
 * Handles server-side validation, moderation, and admin operations
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
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

// ============================================================================
// API ENDPOINTS
// ============================================================================

// Express app for HTTP endpoints
const app = express();
app.use(cors({ origin: true }));
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
    if (validationResult.fraudScore > 75) {
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
    const verifiedPayload = await receiptValidation.verifyWebhookSignature(req);

    if (!verifiedPayload) {
      functions.logger.error('⛔ Webhook signature verification failed - potential spoofing attempt', {
        ip: req.ip
      });
      return res.status(401).send('Invalid signature');
    }

    functions.logger.info('✅ Webhook signature verified');

    // Extract notification data from verified payload
    const notificationType = verifiedPayload.notificationType;
    const subtype = verifiedPayload.subtype;
    const data = verifiedPayload.data;

    functions.logger.info('Processing webhook notification', {
      notificationType,
      subtype
    });

    // Handle different notification types (V2 format)
    switch (notificationType) {
      case 'SUBSCRIBED':
        await handleSubscriptionStart(data);
        break;

      case 'DID_RENEW':
        await handleSubscriptionRenewal(data);
        break;

      case 'DID_FAIL_TO_RENEW':
        await handleSubscriptionFailure(data);
        break;

      case 'DID_CHANGE_RENEWAL_STATUS':
        await handleRenewalStatusChange(data, subtype);
        break;

      case 'EXPIRED':
        await handleSubscriptionExpired(data);
        break;

      case 'GRACE_PERIOD_EXPIRED':
        await handleGracePeriodExpired(data);
        break;

      case 'REVOKE':
      case 'REFUND':
        // CRITICAL: Handle refunds with fraud detection
        await handleRefundEnhanced(data, notificationType);
        break;

      case 'CONSUMPTION_REQUEST':
        await handleConsumptionRequest(data);
        break;

      case 'RENEWAL_EXTENDED':
        await handleRenewalExtended(data);
        break;

      case 'PRICE_INCREASE':
        await handlePriceIncrease(data);
        break;

      case 'REFUND_DECLINED':
        await handleRefundDeclined(data);
        break;

      default:
        functions.logger.warn('Unknown notification type', { notificationType, subtype });
    }

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

/**
 * Handle subscription start (new subscription)
 */
async function handleSubscriptionStart(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      functions.logger.error('No transaction info in subscription start');
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      functions.logger.info('✅ New subscription started', { userId, transactionId });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription start', { error: error.message });
  }
}

/**
 * Handle renewal status change
 */
async function handleRenewalStatusChange(data, subtype) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      const autoRenewEnabled = subtype === 'AUTO_RENEW_ENABLED';

      functions.logger.info('Renewal status changed', {
        userId,
        transactionId,
        autoRenewEnabled
      });

      // Update user record
      await db.collection('users').doc(userId).update({
        autoRenewEnabled,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  } catch (error) {
    functions.logger.error('Error handling renewal status change', { error: error.message });
  }
}

/**
 * Handle subscription expired
 */
async function handleSubscriptionExpired(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      await db.collection('users').doc(userId).update({
        isPremium: false,
        premiumTier: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.info('Subscription expired', { userId, transactionId });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription expiration', { error: error.message });
  }
}

/**
 * Handle grace period expired
 */
async function handleGracePeriodExpired(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      await db.collection('users').doc(userId).update({
        isPremium: false,
        premiumTier: null,
        inGracePeriod: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.warn('Grace period expired - access revoked', { userId, transactionId });
    }
  } catch (error) {
    functions.logger.error('Error handling grace period expiration', { error: error.message });
  }
}

/**
 * Handle consumption request (for consumable products)
 */
async function handleConsumptionRequest(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    functions.logger.info('Consumption request received', {
      transactionId: transactionInfo.transactionId,
      productId: transactionInfo.productId
    });
  } catch (error) {
    functions.logger.error('Error handling consumption request', { error: error.message });
  }
}

/**
 * Handle renewal extended
 */
async function handleRenewalExtended(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      functions.logger.info('Subscription renewal extended', { userId, transactionId });
    }
  } catch (error) {
    functions.logger.error('Error handling renewal extended', { error: error.message });
  }
}

/**
 * Handle price increase consent
 */
async function handlePriceIncrease(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      functions.logger.info('Price increase notification', { userId, transactionId });

      // Send notification to user
      await db.collection('notifications').add({
        userId,
        type: 'price_increase',
        title: 'Subscription Price Update',
        message: 'The price of your subscription will increase on your next renewal.',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
  } catch (error) {
    functions.logger.error('Error handling price increase', { error: error.message });
  }
}

/**
 * Handle refund declined
 */
async function handleRefundDeclined(data) {
  try {
    const jwt = require('jsonwebtoken');
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      functions.logger.info('Refund request declined', { userId, transactionId });
    }
  } catch (error) {
    functions.logger.error('Error handling refund declined', { error: error.message });
  }
}

async function handleSubscriptionRenewal(notification) {
  const transactionId = notification.latest_receipt_info.transaction_id;
  const userId = await getUserIdFromTransaction(transactionId);

  if (userId) {
    await db.collection('users').doc(userId).update({
      subscriptionExpiryDate: new Date(notification.expiration_date_ms),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info('Subscription renewed', { userId, transactionId });
  }
}

async function handleSubscriptionFailure(notification) {
  const transactionId = notification.latest_receipt_info.transaction_id;
  const userId = await getUserIdFromTransaction(transactionId);

  if (userId) {
    // Mark subscription as expired
    await db.collection('users').doc(userId).update({
      isPremium: false,
      premiumTier: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.warn('Subscription failed to renew', { userId, transactionId });
  }
}

async function handleSubscriptionCancellation(notification) {
  const transactionId = notification.latest_receipt_info.transaction_id;
  const userId = await getUserIdFromTransaction(transactionId);

  if (userId) {
    await db.collection('users').doc(userId).update({
      isPremium: false,
      premiumTier: null,
      subscriptionExpiryDate: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info('Subscription cancelled', { userId, transactionId });
  }
}

/**
 * Enhanced refund handler with fraud detection
 * SECURITY: Tracks refund patterns and revokes access immediately
 */
async function handleRefundEnhanced(data, notificationType) {
  try {
    // Extract transaction info from App Store Server Notification V2 format
    const transactionInfo = data?.signedTransactionInfo;

    if (!transactionInfo) {
      functions.logger.error('No transaction info in refund notification');
      return;
    }

    // Decode the signed transaction (it's a JWT)
    const jwt = require('jsonwebtoken');
    const decodedTransaction = jwt.decode(transactionInfo);

    const transactionId = decodedTransaction?.transactionId;
    const originalTransactionId = decodedTransaction?.originalTransactionId;
    const productId = decodedTransaction?.productId;

    if (!transactionId) {
      functions.logger.error('No transaction ID in refund notification');
      return;
    }

    functions.logger.warn('🚨 REFUND NOTIFICATION RECEIVED', {
      transactionId,
      originalTransactionId,
      productId,
      notificationType
    });

    // Find the purchase record
    const purchaseQuery = await db.collection('purchases')
      .where('transactionId', '==', transactionId)
      .get();

    if (purchaseQuery.empty) {
      // Try with original transaction ID
      const originalQuery = await db.collection('purchases')
        .where('originalTransactionId', '==', originalTransactionId)
        .get();

      if (originalQuery.empty) {
        functions.logger.error('Purchase not found for refund', { transactionId, originalTransactionId });
        return;
      }

      const purchaseDoc = originalQuery.docs[0];
      await processRefund(purchaseDoc, transactionId, notificationType);
    } else {
      const purchaseDoc = purchaseQuery.docs[0];
      await processRefund(purchaseDoc, transactionId, notificationType);
    }

  } catch (error) {
    functions.logger.error('Error handling refund', { error: error.message });
  }
}

/**
 * Process refund and revoke access
 */
async function processRefund(purchaseDoc, transactionId, notificationType) {
  const purchaseData = purchaseDoc.data();
  const userId = purchaseData.userId;
  const productId = purchaseData.productId;

  // Update purchase record
  await purchaseDoc.ref.update({
    refunded: true,
    refundDate: admin.firestore.FieldValue.serverTimestamp(),
    refundType: notificationType
  });

  // IMMEDIATELY revoke user's premium access
  await db.collection('users').doc(userId).update({
    isPremium: false,
    premiumTier: null,
    subscriptionExpiryDate: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  functions.logger.warn('⚠️ Premium access revoked due to refund', { userId, transactionId });

  // FRAUD DETECTION: Track refund patterns
  await trackRefundForFraudDetection(userId, transactionId, productId);

  // Check if user has suspicious refund patterns
  const refundCount = await getRefundCount(userId);

  if (refundCount > 2) {
    functions.logger.error('🚨 FRAUD ALERT: Multiple refunds detected', {
      userId,
      refundCount
    });

    // Flag user for review
    await db.collection('fraud_logs').add({
      userId,
      eventType: 'multiple_refunds',
      refundCount,
      details: {
        latestTransactionId: transactionId,
        productId
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      severity: 'critical'
    });

    // Create admin alert
    await db.collection('admin_alerts').add({
      alertType: 'refund_abuse_detected',
      details: {
        userId,
        refundCount,
        transactionId
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false,
      priority: 'critical'
    });

    // Auto-suspend if refund count exceeds threshold
    if (refundCount > 3) {
      await db.collection('users').doc(userId).update({
        suspended: true,
        suspensionReason: 'Multiple refund abuse - automatic suspension',
        suspendedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.error('⛔ User auto-suspended for refund abuse', {
        userId,
        refundCount
      });
    }
  }

  // Send notification to user about access revocation
  await sendRefundNotification(userId, productId);
}

/**
 * Track refund for fraud detection
 */
async function trackRefundForFraudDetection(userId, transactionId, productId) {
  await db.collection('refund_history').add({
    userId,
    transactionId,
    productId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    flaggedForReview: false
  });
}

/**
 * Get refund count for user
 */
async function getRefundCount(userId) {
  const refunds = await db.collection('purchases')
    .where('userId', '==', userId)
    .where('refunded', '==', true)
    .get();
  return refunds.size;
}

/**
 * Send notification to user about refund
 */
async function sendRefundNotification(userId, productId) {
  try {
    await db.collection('notifications').add({
      userId,
      type: 'refund_processed',
      title: 'Subscription Refunded',
      message: 'Your subscription has been refunded and premium access has been revoked.',
      productId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
  } catch (error) {
    functions.logger.error('Error sending refund notification', { error: error.message });
  }
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

async function getUserIdFromTransaction(transactionId) {
  const purchaseQuery = await db.collection('purchases')
    .where('transactionId', '==', transactionId)
    .limit(1)
    .get();

  if (!purchaseQuery.empty) {
    return purchaseQuery.docs[0].data().userId;
  }
  return null;
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

// Export admin object for use in modules
exports.admin = admin;
exports.db = db;
