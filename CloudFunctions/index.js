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
 */
exports.validateReceipt = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { receiptData, productId } = data;
  const userId = context.auth.uid;

  try {
    // Validate the receipt with Apple
    const validationResult = await receiptValidation.validateAppleReceipt(receiptData);

    if (!validationResult.isValid) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid receipt');
    }

    // Check if receipt matches the product
    if (validationResult.productId !== productId) {
      throw new functions.https.HttpsError('invalid-argument', 'Product ID mismatch');
    }

    // Check for receipt reuse
    const existingPurchase = await db.collection('purchases')
      .where('transactionId', '==', validationResult.transactionId)
      .get();

    if (!existingPurchase.empty) {
      throw new functions.https.HttpsError('already-exists', 'Receipt already used');
    }

    // Record the purchase
    const purchaseRef = await db.collection('purchases').add({
      userId,
      productId,
      transactionId: validationResult.transactionId,
      purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: validationResult.expiryDate || null,
      receiptData: validationResult.receipt,
      validated: true
    });

    // Update user's subscription status
    await updateUserSubscription(userId, productId, validationResult);

    functions.logger.info(`Receipt validated for user ${userId}`, { productId, transactionId: validationResult.transactionId });

    return {
      success: true,
      purchaseId: purchaseRef.id,
      expiryDate: validationResult.expiryDate
    };

  } catch (error) {
    functions.logger.error('Receipt validation error', { userId, error: error.message });
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Webhook for App Store Server Notifications
 * Handles subscription renewals, cancellations, refunds
 */
exports.appleWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const notification = req.body;

    functions.logger.info('Apple webhook received', { notification });

    // Verify webhook signature (implement in production)
    // const isValid = await receiptValidation.verifyWebhookSignature(req);
    // if (!isValid) {
    //   return res.status(401).send('Invalid signature');
    // }

    // Handle different notification types
    switch (notification.notification_type) {
      case 'DID_RENEW':
        await handleSubscriptionRenewal(notification);
        break;
      case 'DID_FAIL_TO_RENEW':
        await handleSubscriptionFailure(notification);
        break;
      case 'CANCEL':
        await handleSubscriptionCancellation(notification);
        break;
      case 'REFUND':
        await handleRefund(notification);
        break;
      default:
        functions.logger.warn('Unknown notification type', { type: notification.notification_type });
    }

    res.status(200).send('OK');
  } catch (error) {
    functions.logger.error('Apple webhook error', { error: error.message });
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

async function handleRefund(notification) {
  const transactionId = notification.latest_receipt_info.transaction_id;

  // Mark purchase as refunded
  const purchaseQuery = await db.collection('purchases')
    .where('transactionId', '==', transactionId)
    .get();

  if (!purchaseQuery.empty) {
    const purchaseDoc = purchaseQuery.docs[0];
    await purchaseDoc.ref.update({
      refunded: true,
      refundDate: admin.firestore.FieldValue.serverTimestamp()
    });

    // Revoke user's benefits
    const userId = purchaseDoc.data().userId;
    await db.collection('users').doc(userId).update({
      isPremium: false,
      premiumTier: null,
      subscriptionExpiryDate: null
    });

    functions.logger.warn('Purchase refunded', { userId, transactionId });
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
