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
const fraudDetection = require('./fraudDetection');

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
        await fraudDetection.trackValidationFailure(userId, status, 'receipt_validation_failed');
      }

      return {
        isValid: false,
        error: getErrorMessage(status),
        fraudScore: await fraudDetection.calculateFraudScore(userId, { validationFailed: true })
      };
    }

    // Extract transaction info
    const latestTransaction = latest_receipt_info ? latest_receipt_info[0] : null;

    if (!latestTransaction) {
      throw new Error('No transaction information in receipt');
    }

    // SECURITY: Check for receipt reuse
    if (userId) {
      const isDuplicate = await fraudDetection.checkReceiptDuplicate(latestTransaction.transaction_id, userId);
      if (isDuplicate) {
        functions.logger.error('FRAUD ALERT: Duplicate receipt detected', {
          userId,
          transactionId: latestTransaction.transaction_id
        });

        await fraudDetection.trackFraudAttempt(userId, 'duplicate_receipt', {
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
        const promoAbuse = await fraudDetection.checkPromotionalCodeAbuse(userId, promotionalOfferId);
        if (promoAbuse) {
          functions.logger.error('FRAUD ALERT: Promotional code abuse detected', { userId, promotionalOfferId });

          await fraudDetection.trackFraudAttempt(userId, 'promo_code_abuse', {
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
    const jailbreakRisk = fraudDetection.detectJailbreakIndicators(receipt);
    if (jailbreakRisk > 0.7 && userId) {
      functions.logger.warn('SECURITY WARNING: Jailbreak indicators detected', {
        userId,
        riskScore: jailbreakRisk
      });

      await trackSecurityEvent(userId, 'jailbreak_detected', { riskScore: jailbreakRisk });
    }

    // Calculate fraud score for this transaction
    const fraudScore = userId ? await fraudDetection.calculateFraudScore(userId, {
      isPromotional: isPromotionalPurchase,
      jailbreakRisk,
      transactionId: latestTransaction.transaction_id,
      productId: latestTransaction.product_id
    }) : 0;

    // SECURITY: Flag high-risk transactions
    if (fraudScore > fraudDetection.FRAUD_THRESHOLDS.FRAUD_SCORE_MEDIUM) {
      functions.logger.warn('HIGH FRAUD RISK TRANSACTION', {
        userId,
        fraudScore,
        transactionId: latestTransaction.transaction_id
      });

      await fraudDetection.flagTransactionForReview(userId, latestTransaction, fraudScore);
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
      await fraudDetection.trackValidationFailure(userId, null, 'validation_exception', error.message);
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
  validateGooglePlayPurchase
};
