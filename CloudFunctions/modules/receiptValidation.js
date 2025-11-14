/**
 * Receipt Validation Module
 * Handles App Store receipt validation to prevent fraud
 * SECURITY: Implements signature verification, fraud detection, and comprehensive validation
 */

const axios = require('axios');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const crypto = require('crypto');

// App Store endpoints
const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

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
 * Validates an Apple receipt with the App Store
 * @param {string} receiptData - Base64 encoded receipt
 * @param {string} userId - User ID for fraud tracking
 * @returns {object} Validation result
 */
async function validateAppleReceipt(receiptData, userId = null) {
  const sharedSecret = functions.config().apple?.shared_secret;

  if (!sharedSecret) {
    throw new Error('Apple shared secret not configured');
  }

  const requestBody = {
    'receipt-data': receiptData,
    'password': sharedSecret,
    'exclude-old-transactions': true
  };

  try {
    // Try production first
    let response = await axios.post(PRODUCTION_URL, requestBody);

    // If sandbox receipt, retry with sandbox endpoint
    if (response.data.status === 21007) {
      functions.logger.info('Sandbox receipt detected, retrying with sandbox endpoint');
      response = await axios.post(SANDBOX_URL, requestBody);
    }

    const { status, latest_receipt_info, pending_renewal_info, receipt } = response.data;

    // Status codes: 0 = valid, anything else = invalid
    if (status !== 0) {
      functions.logger.warn('Receipt validation failed', { status, userId });

      // Track failed validation attempts for fraud detection
      if (userId) {
        await trackValidationFailure(userId, status, 'receipt_validation_failed');
      }

      return {
        isValid: false,
        error: getErrorMessage(status),
        fraudScore: await calculateFraudScore(userId, { validationFailed: true })
      };
    }

    // Extract transaction info
    const latestTransaction = latest_receipt_info ? latest_receipt_info[0] : null;

    if (!latestTransaction) {
      throw new Error('No transaction information in receipt');
    }

    // SECURITY: Check for receipt reuse
    if (userId) {
      const isDuplicate = await checkReceiptDuplicate(latestTransaction.transaction_id, userId);
      if (isDuplicate) {
        functions.logger.error('FRAUD ALERT: Duplicate receipt detected', {
          userId,
          transactionId: latestTransaction.transaction_id
        });

        await trackFraudAttempt(userId, 'duplicate_receipt', {
          transactionId: latestTransaction.transaction_id,
          productId: latestTransaction.product_id
        });

        return {
          isValid: false,
          error: 'Receipt already used',
          fraudScore: 100 // Maximum fraud score
        };
      }
    }

    // SECURITY: Validate promotional codes server-side
    let isPromotionalPurchase = false;
    let promotionalOfferId = null;

    if (latestTransaction.promotional_offer_id) {
      promotionalOfferId = latestTransaction.promotional_offer_id;
      isPromotionalPurchase = true;

      // Validate promotional code hasn't been abused
      if (userId) {
        const promoAbuse = await checkPromotionalCodeAbuse(userId, promotionalOfferId);
        if (promoAbuse) {
          functions.logger.error('FRAUD ALERT: Promotional code abuse detected', { userId, promotionalOfferId });

          await trackFraudAttempt(userId, 'promo_code_abuse', {
            promotionalOfferId,
            productId: latestTransaction.product_id
          });

          return {
            isValid: false,
            error: 'Promotional code abuse detected',
            fraudScore: 90
          };
        }
      }
    }

    // SECURITY: Check for jailbreak indicators
    const jailbreakRisk = detectJailbreakIndicators(receipt);
    if (jailbreakRisk > 0.7 && userId) {
      functions.logger.warn('SECURITY WARNING: Jailbreak indicators detected', {
        userId,
        riskScore: jailbreakRisk
      });

      await trackSecurityEvent(userId, 'jailbreak_detected', { riskScore: jailbreakRisk });
    }

    // Calculate fraud score for this transaction
    const fraudScore = userId ? await calculateFraudScore(userId, {
      isPromotional: isPromotionalPurchase,
      jailbreakRisk,
      transactionId: latestTransaction.transaction_id,
      productId: latestTransaction.product_id
    }) : 0;

    // SECURITY: Flag high-risk transactions
    if (fraudScore > 50) {
      functions.logger.warn('HIGH FRAUD RISK TRANSACTION', {
        userId,
        fraudScore,
        transactionId: latestTransaction.transaction_id
      });

      await flagTransactionForReview(userId, latestTransaction, fraudScore);
    }

    return {
      isValid: true,
      transactionId: latestTransaction.transaction_id,
      productId: latestTransaction.product_id,
      purchaseDate: new Date(parseInt(latestTransaction.purchase_date_ms)),
      expiryDate: latestTransaction.expires_date_ms
        ? new Date(parseInt(latestTransaction.expires_date_ms))
        : null,
      isSubscription: !!latestTransaction.expires_date_ms,
      originalTransactionId: latestTransaction.original_transaction_id,
      autoRenewStatus: pending_renewal_info?.[0]?.auto_renew_status === '1',
      isPromotional: isPromotionalPurchase,
      promotionalOfferId,
      cancellationDate: latestTransaction.cancellation_date_ms
        ? new Date(parseInt(latestTransaction.cancellation_date_ms))
        : null,
      isInIntroOfferPeriod: latestTransaction.is_in_intro_offer_period === 'true',
      isTrialPeriod: latestTransaction.is_trial_period === 'true',
      webOrderLineItemId: latestTransaction.web_order_line_item_id,
      fraudScore,
      jailbreakRisk,
      receipt: response.data
    };

  } catch (error) {
    functions.logger.error('Receipt validation error', { error: error.message, userId });

    if (userId) {
      await trackValidationFailure(userId, null, 'validation_exception', error.message);
    }

    throw new Error(`Failed to validate receipt: ${error.message}`);
  }
}

/**
 * Verifies webhook signature from Apple (App Store Server Notifications V2)
 * SECURITY CRITICAL: Prevents spoofed webhooks and fraudulent notifications
 * @param {object} request - Express request object
 * @returns {object} Verified notification payload or null
 */
async function verifyWebhookSignature(request) {
  try {
    // Apple sends notifications as signed JWT in the body
    const signedPayload = request.body?.signedPayload;

    if (!signedPayload) {
      functions.logger.error('Webhook signature verification failed: No signed payload');
      return null;
    }

    // Decode the JWT header to get the key ID
    const decodedHeader = jwt.decode(signedPayload, { complete: true });

    if (!decodedHeader || !decodedHeader.header || !decodedHeader.header.kid) {
      functions.logger.error('Webhook signature verification failed: Invalid JWT header');
      return null;
    }

    const kid = decodedHeader.header.kid;

    // Get the signing key from Apple's JWKS endpoint
    const getKey = (header, callback) => {
      jwksClientInstance.getSigningKey(header.kid, (err, key) => {
        if (err) {
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
        issuer: 'appstorenotifications',
      }, (err, decoded) => {
        if (err) {
          return reject(err);
        }
        resolve(decoded);
      });
    });

    functions.logger.info('✅ Webhook signature verified successfully');

    return verifiedPayload;

  } catch (error) {
    functions.logger.error('Webhook signature verification failed', { error: error.message });

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
 * FRAUD DETECTION: Check if receipt has been used before
 * @param {string} transactionId - Transaction ID
 * @param {string} userId - User ID
 * @returns {boolean} True if duplicate
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
 * FRAUD DETECTION: Check for promotional code abuse
 * @param {string} userId - User ID
 * @param {string} promoCode - Promotional code
 * @returns {boolean} True if abuse detected
 */
async function checkPromotionalCodeAbuse(userId, promoCode) {
  const db = admin.firestore();

  try {
    // Check how many times this user has used promotional codes
    const promoUsage = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('isPromotional', '==', true)
      .get();

    // Flag if user has used more than 3 promotional codes
    if (promoUsage.size > 3) {
      return true;
    }

    // Check if the same promo code was used multiple times (shouldn't happen)
    const samePromoUsage = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('promotionalOfferId', '==', promoCode)
      .get();

    if (samePromoUsage.size > 1) {
      return true;
    }

    // Check rapid promotional purchases (within 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentPromoUsage = promoUsage.docs.filter(doc => {
      const purchaseDate = doc.data().purchaseDate?.toDate();
      return purchaseDate && purchaseDate > oneDayAgo;
    });

    if (recentPromoUsage.length > 2) {
      return true;
    }

    return false;
  } catch (error) {
    functions.logger.error('Error checking promo code abuse', { error: error.message });
    return false;
  }
}

/**
 * SECURITY: Detect jailbreak indicators in receipt
 * @param {object} receipt - Receipt data
 * @returns {number} Risk score 0-1
 */
function detectJailbreakIndicators(receipt) {
  let riskScore = 0;

  // Check for suspicious bundle ID patterns
  const bundleId = receipt?.bundle_id || '';
  const suspiciousPatterns = ['cracked', 'hacked', 'pirate', 'modded'];

  if (suspiciousPatterns.some(pattern => bundleId.toLowerCase().includes(pattern))) {
    riskScore += 0.5;
  }

  // Check for environment mismatches (production receipt in sandbox, etc.)
  const environment = receipt?.environment;
  if (environment === 'Sandbox' && process.env.NODE_ENV === 'production') {
    riskScore += 0.3;
  }

  // Additional checks can be added here
  // - Receipt age anomalies
  // - Unusual transaction patterns
  // - etc.

  return Math.min(riskScore, 1.0);
}

/**
 * FRAUD DETECTION: Calculate fraud score for user/transaction
 * @param {string} userId - User ID
 * @param {object} context - Transaction context
 * @returns {number} Fraud score 0-100
 */
async function calculateFraudScore(userId, context = {}) {
  const db = admin.firestore();
  let score = 0;

  try {
    // Check refund history
    const refundCount = await getRefundCount(userId);
    if (refundCount > 2) score += 30;
    else if (refundCount > 0) score += 15;

    // Check validation failure history
    const validationFailures = await getValidationFailureCount(userId);
    if (validationFailures > 5) score += 20;
    else if (validationFailures > 2) score += 10;

    // Check account age (new accounts are higher risk)
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const accountAge = Date.now() - userDoc.data().timestamp?.toDate().getTime();
      const daysSinceCreation = accountAge / (1000 * 60 * 60 * 24);

      if (daysSinceCreation < 1) score += 15;
      else if (daysSinceCreation < 7) score += 10;
    }

    // Check jailbreak risk
    if (context.jailbreakRisk > 0.7) score += 25;
    else if (context.jailbreakRisk > 0.4) score += 15;

    // Check promotional abuse
    if (context.isPromotional) {
      const promoCount = await getPromotionalPurchaseCount(userId);
      if (promoCount > 3) score += 20;
    }

    // Check rapid purchase/refund cycles
    const rapidCycleDetected = await detectRapidPurchaseRefundCycle(userId);
    if (rapidCycleDetected) score += 30;

    // Previous fraud attempts
    const fraudAttempts = await getFraudAttemptCount(userId);
    if (fraudAttempts > 0) score += 25 * fraudAttempts;

    return Math.min(score, 100);
  } catch (error) {
    functions.logger.error('Error calculating fraud score', { error: error.message, userId });
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
 * Detect rapid purchase/refund cycles (fraud pattern)
 */
async function detectRapidPurchaseRefundCycle(userId) {
  const db = admin.firestore();

  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const recentPurchases = await db.collection('purchases')
      .where('userId', '==', userId)
      .where('purchaseDate', '>', thirtyDaysAgo)
      .get();

    const refundedPurchases = recentPurchases.docs.filter(doc => doc.data().refunded === true);

    // Flag if more than 50% of purchases were refunded
    if (recentPurchases.size >= 3 && refundedPurchases.length / recentPurchases.size > 0.5) {
      return true;
    }

    return false;
  } catch (error) {
    functions.logger.error('Error detecting rapid cycles', { error: error.message });
    return false;
  }
}

/**
 * Track validation failures for fraud detection
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
 * Track fraud attempts
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

    // Alert admins for immediate attention
    await createAdminAlert('fraud_detected', {
      userId,
      fraudType,
      details
    });
  } catch (error) {
    functions.logger.error('Error tracking fraud attempt', { error: error.message });
  }
}

/**
 * Track security events
 */
async function trackSecurityEvent(userId, eventType, details) {
  const db = admin.firestore();

  try {
    await db.collection('security_logs').add({
      userId,
      eventType,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    functions.logger.error('Error tracking security event', { error: error.message });
  }
}

/**
 * Flag transaction for manual review
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

    // Alert admins
    if (fraudScore > 70) {
      await createAdminAlert('high_risk_transaction', {
        userId,
        transactionId: transaction.transaction_id,
        fraudScore
      });
    }
  } catch (error) {
    functions.logger.error('Error flagging transaction', { error: error.message });
  }
}

/**
 * Create admin alert
 */
async function createAdminAlert(alertType, details) {
  const db = admin.firestore();

  try {
    await db.collection('admin_alerts').add({
      alertType,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false,
      priority: alertType === 'fraud_detected' ? 'critical' : 'high'
    });
  } catch (error) {
    functions.logger.error('Error creating admin alert', { error: error.message });
  }
}

/**
 * Log security events
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
    functions.logger.error('Error logging security event', { error: error.message });
  }
}

/**
 * Gets human-readable error message for status code
 * @param {number} status - Apple status code
 * @returns {string} Error message
 */
function getErrorMessage(status) {
  const errors = {
    21000: 'The App Store could not read the JSON object you provided.',
    21002: 'The data in the receipt-data property was malformed or missing.',
    21003: 'The receipt could not be authenticated.',
    21004: 'The shared secret you provided does not match the shared secret on file.',
    21005: 'The receipt server is not currently available.',
    21006: 'This receipt is valid but the subscription has expired.',
    21007: 'This receipt is from the test environment.',
    21008: 'This receipt is from the production environment.',
    21009: 'Internal data access error.',
    21010: 'This receipt could not be authorized.'
  };

  return errors[status] || `Unknown error (status: ${status})`;
}

/**
 * Validates a Google Play purchase (for Android support)
 * @param {string} packageName - App package name
 * @param {string} productId - Product ID
 * @param {string} purchaseToken - Purchase token
 * @returns {object} Validation result
 */
async function validateGooglePlayPurchase(packageName, productId, purchaseToken) {
  // TODO: Implement Google Play validation when Android app is ready
  // Use Google Play Developer API
  // See: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products

  throw new Error('Google Play validation not yet implemented');
}

module.exports = {
  validateAppleReceipt,
  verifyWebhookSignature,
  validateGooglePlayPurchase,
  calculateFraudScore,
  checkReceiptDuplicate,
  checkPromotionalCodeAbuse,
  detectJailbreakIndicators
};
