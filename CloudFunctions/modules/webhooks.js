/**
 * Webhooks Module
 * Secure webhook handling for App Store Server Notifications V2
 *
 * SECURITY CRITICAL: This module handles payment webhooks from Apple
 * - Signature verification prevents spoofed notifications
 * - Automatic refund handling revokes access immediately
 * - Comprehensive event handling for all subscription states
 * - Fraud detection integration
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Apple's JWKS endpoint for webhook signature verification
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';

// Initialize JWKS client for Apple signature verification
const jwksClientInstance = jwksClient({
  jwksUri: APPLE_JWKS_URL,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true
});

/**
 * Verifies webhook signature from Apple (App Store Server Notifications V2)
 * SECURITY CRITICAL: Prevents spoofed webhooks and fraudulent notifications
 *
 * Apple sends notifications as signed JWTs following the JWS (JSON Web Signature) standard.
 * The signature uses the ES256 algorithm with Apple's private key.
 *
 * @param {object} request - Express request object
 * @returns {Promise<object|null>} Verified notification payload or null if verification fails
 */
async function verifyWebhookSignature(request) {
  try {
    // Apple sends notifications as signed JWT in the body
    const signedPayload = request.body?.signedPayload;

    if (!signedPayload) {
      functions.logger.error('⛔ Webhook signature verification failed: No signed payload', {
        ip: request.ip,
        headers: request.headers
      });

      await logSecurityEvent('webhook_missing_payload', {
        ip: request.ip,
        timestamp: new Date().toISOString()
      });

      return null;
    }

    // Decode the JWT header to get the key ID
    const decodedHeader = jwt.decode(signedPayload, { complete: true });

    if (!decodedHeader || !decodedHeader.header || !decodedHeader.header.kid) {
      functions.logger.error('⛔ Webhook signature verification failed: Invalid JWT header', {
        ip: request.ip
      });

      await logSecurityEvent('webhook_invalid_jwt', {
        ip: request.ip,
        timestamp: new Date().toISOString()
      });

      return null;
    }

    const kid = decodedHeader.header.kid;

    // Get the signing key from Apple's JWKS endpoint
    const getKey = (header, callback) => {
      jwksClientInstance.getSigningKey(header.kid, (err, key) => {
        if (err) {
          functions.logger.error('Failed to get signing key from Apple JWKS', {
            error: err.message,
            kid: header.kid
          });
          return callback(err);
        }
        const signingKey = key.publicKey || key.rsaPublicKey;
        callback(null, signingKey);
      });
    };

    // Verify the JWT signature
    const verifiedPayload = await new Promise((resolve, reject) => {
      jwt.verify(signedPayload, getKey, {
        algorithms: ['ES256'], // Apple uses ES256 for App Store Server Notifications
        issuer: 'appstorenotifications', // Expected issuer
      }, (err, decoded) => {
        if (err) {
          functions.logger.error('JWT verification failed', {
            error: err.message,
            name: err.name
          });
          return reject(err);
        }
        resolve(decoded);
      });
    });

    functions.logger.info('✅ Webhook signature verified successfully', {
      notificationType: verifiedPayload.notificationType,
      subtype: verifiedPayload.subtype
    });

    // Log successful verification
    await logSecurityEvent('webhook_verified', {
      notificationType: verifiedPayload.notificationType,
      timestamp: new Date().toISOString()
    });

    return verifiedPayload;

  } catch (error) {
    functions.logger.error('⛔ Webhook signature verification failed', {
      error: error.message,
      name: error.name,
      stack: error.stack
    });

    // Log potential spoofing attempt
    await logSecurityEvent('webhook_verification_failed', {
      error: error.message,
      ip: request.ip,
      timestamp: new Date().toISOString()
    });

    return null;
  }
}

/**
 * Handle App Store webhook notification
 * Routes to appropriate handler based on notification type
 *
 * @param {object} verifiedPayload - Verified webhook payload
 * @returns {Promise<void>}
 */
async function handleWebhookNotification(verifiedPayload) {
  const notificationType = verifiedPayload.notificationType;
  const subtype = verifiedPayload.subtype;
  const data = verifiedPayload.data;

  functions.logger.info('Processing webhook notification', {
    notificationType,
    subtype
  });

  try {
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

      case 'RENEWAL_EXTENSION':
        await handleRenewalExtension(data);
        break;

      case 'OFFER_REDEEMED':
        await handleOfferRedeemed(data);
        break;

      case 'TEST':
        functions.logger.info('Test notification received');
        break;

      default:
        functions.logger.warn('Unknown notification type', {
          notificationType,
          subtype
        });
    }

  } catch (error) {
    functions.logger.error('Error handling webhook notification', {
      error: error.message,
      notificationType,
      subtype
    });
    throw error;
  }
}

/**
 * Handle subscription start (new subscription)
 */
async function handleSubscriptionStart(data) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      functions.logger.error('No transaction info in subscription start');
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const productId = transactionInfo.productId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      functions.logger.info('✅ New subscription started', {
        userId,
        transactionId,
        productId
      });

      // Send welcome notification
      await db.collection('notifications').add({
        userId,
        type: 'subscription_started',
        title: 'Welcome to Premium!',
        message: 'Your premium subscription is now active. Enjoy all the benefits!',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription start', {
      error: error.message
    });
  }
}

/**
 * Handle subscription renewal
 */
async function handleSubscriptionRenewal(data) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const expiresDate = transactionInfo.expiresDate;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      // Update subscription expiry date
      await db.collection('users').doc(userId).update({
        subscriptionExpiryDate: new Date(expiresDate),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.info('✅ Subscription renewed', {
        userId,
        transactionId,
        expiryDate: expiresDate
      });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription renewal', {
      error: error.message
    });
  }
}

/**
 * Handle subscription failure
 */
async function handleSubscriptionFailure(data) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      // Put user in grace period instead of immediate revocation
      await db.collection('users').doc(userId).update({
        inGracePeriod: true,
        gracePeriodStartDate: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send notification
      await db.collection('notifications').add({
        userId,
        type: 'renewal_failed',
        title: 'Subscription Renewal Failed',
        message: 'Your subscription renewal failed. Please update your payment method.',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

      functions.logger.warn('⚠️ Subscription failed to renew - grace period started', {
        userId,
        transactionId
      });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription failure', {
      error: error.message
    });
  }
}

/**
 * Handle renewal status change
 */
async function handleRenewalStatusChange(data, subtype) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      const autoRenewEnabled = subtype === 'AUTO_RENEW_ENABLED';

      // Update user record
      await db.collection('users').doc(userId).update({
        autoRenewEnabled,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.info('Renewal status changed', {
        userId,
        transactionId,
        autoRenewEnabled
      });

      // Send notification if auto-renew was disabled
      if (!autoRenewEnabled) {
        await db.collection('notifications').add({
          userId,
          type: 'auto_renew_disabled',
          title: 'Auto-Renewal Disabled',
          message: 'Your subscription will not automatically renew.',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });
      }
    }
  } catch (error) {
    functions.logger.error('Error handling renewal status change', {
      error: error.message
    });
  }
}

/**
 * Handle subscription expired
 */
async function handleSubscriptionExpired(data) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      // Revoke premium access
      await db.collection('users').doc(userId).update({
        isPremium: false,
        premiumTier: null,
        subscriptionExpiryDate: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send notification
      await db.collection('notifications').add({
        userId,
        type: 'subscription_expired',
        title: 'Subscription Expired',
        message: 'Your premium subscription has expired. Renew to continue enjoying premium features.',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

      functions.logger.info('Subscription expired', {
        userId,
        transactionId
      });
    }
  } catch (error) {
    functions.logger.error('Error handling subscription expiration', {
      error: error.message
    });
  }
}

/**
 * Handle grace period expired
 */
async function handleGracePeriodExpired(data) {
  const db = admin.firestore();

  try {
    const transactionInfo = jwt.decode(data?.signedTransactionInfo);

    if (!transactionInfo) {
      return;
    }

    const transactionId = transactionInfo.transactionId;
    const userId = await getUserIdFromTransaction(transactionId);

    if (userId) {
      // Revoke access after grace period
      await db.collection('users').doc(userId).update({
        isPremium: false,
        premiumTier: null,
        inGracePeriod: false,
        gracePeriodStartDate: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.warn('⚠️ Grace period expired - access revoked', {
        userId,
        transactionId
      });
    }
  } catch (error) {
    functions.logger.error('Error handling grace period expiration', {
      error: error.message
    });
  }
}

/**
 * Enhanced refund handler with fraud detection
 * SECURITY: Tracks refund patterns and revokes access immediately
 */
async function handleRefundEnhanced(data, notificationType) {
  const db = admin.firestore();
  const fraudDetection = require('./fraudDetection');

  try {
    // Extract transaction info from App Store Server Notification V2 format
    const transactionInfo = data?.signedTransactionInfo;

    if (!transactionInfo) {
      functions.logger.error('No transaction info in refund notification');
      return;
    }

    // Decode the signed transaction (it's a JWT)
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
        functions.logger.error('Purchase not found for refund', {
          transactionId,
          originalTransactionId
        });
        return;
      }

      const purchaseDoc = originalQuery.docs[0];
      await processRefund(purchaseDoc, transactionId, notificationType);
    } else {
      const purchaseDoc = purchaseQuery.docs[0];
      await processRefund(purchaseDoc, transactionId, notificationType);
    }

  } catch (error) {
    functions.logger.error('Error handling refund', {
      error: error.message
    });
  }
}

/**
 * Process refund and revoke access
 * SECURITY: Immediate access revocation and fraud pattern detection
 */
async function processRefund(purchaseDoc, transactionId, notificationType) {
  const db = admin.firestore();
  const fraudDetection = require('./fraudDetection');

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

  functions.logger.warn('⚠️ Premium access revoked due to refund', {
    userId,
    transactionId
  });

  // FRAUD DETECTION: Track refund patterns
  await trackRefundForFraudDetection(userId, transactionId, productId);

  // Check if user has suspicious refund patterns
  const refundCount = await getRefundCount(userId);

  if (refundCount > fraudDetection.FRAUD_THRESHOLDS.MAX_REFUNDS_WARNING) {
    functions.logger.error('🚨 FRAUD ALERT: Multiple refunds detected', {
      userId,
      refundCount
    });

    // Flag user for review
    await fraudDetection.trackFraudAttempt(userId, 'multiple_refunds', {
      refundCount,
      latestTransactionId: transactionId,
      productId
    });

    // Auto-suspend if exceeds critical threshold
    if (refundCount > fraudDetection.FRAUD_THRESHOLDS.MAX_REFUNDS_CRITICAL) {
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
 * Handle other webhook events
 */
async function handleConsumptionRequest(data) {
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);
  if (transactionInfo) {
    functions.logger.info('Consumption request received', {
      transactionId: transactionInfo.transactionId,
      productId: transactionInfo.productId
    });
  }
}

async function handleRenewalExtended(data) {
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);
  if (transactionInfo) {
    functions.logger.info('Subscription renewal extended', {
      transactionId: transactionInfo.transactionId
    });
  }
}

async function handlePriceIncrease(data) {
  const db = admin.firestore();
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);

  if (transactionInfo) {
    const userId = await getUserIdFromTransaction(transactionInfo.transactionId);

    if (userId) {
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
  }
}

async function handleRefundDeclined(data) {
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);
  if (transactionInfo) {
    functions.logger.info('Refund request declined', {
      transactionId: transactionInfo.transactionId
    });
  }
}

async function handleRenewalExtension(data) {
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);
  if (transactionInfo) {
    functions.logger.info('Renewal extension received', {
      transactionId: transactionInfo.transactionId
    });
  }
}

async function handleOfferRedeemed(data) {
  const db = admin.firestore();
  const transactionInfo = jwt.decode(data?.signedTransactionInfo);

  if (transactionInfo) {
    const userId = await getUserIdFromTransaction(transactionInfo.transactionId);

    if (userId) {
      functions.logger.info('Promotional offer redeemed', {
        userId,
        transactionId: transactionInfo.transactionId,
        productId: transactionInfo.productId
      });
    }
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get user ID from transaction ID
 */
async function getUserIdFromTransaction(transactionId) {
  const db = admin.firestore();

  const purchaseQuery = await db.collection('purchases')
    .where('transactionId', '==', transactionId)
    .limit(1)
    .get();

  if (!purchaseQuery.empty) {
    return purchaseQuery.docs[0].data().userId;
  }
  return null;
}

/**
 * Track refund for fraud detection
 */
async function trackRefundForFraudDetection(userId, transactionId, productId) {
  const db = admin.firestore();

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
  const db = admin.firestore();

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
  const db = admin.firestore();

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
    functions.logger.error('Error sending refund notification', {
      error: error.message
    });
  }
}

/**
 * Log security event
 */
async function logSecurityEvent(eventType, details) {
  const db = admin.firestore();

  try {
    await db.collection('security_logs').add({
      eventType,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    functions.logger.error('Error logging security event', {
      error: error.message
    });
  }
}

module.exports = {
  verifyWebhookSignature,
  handleWebhookNotification
};
