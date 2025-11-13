/**
 * Receipt Validation Module
 * Handles App Store receipt validation to prevent fraud
 */

const axios = require('axios');
const functions = require('firebase-functions');

// App Store endpoints
const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

/**
 * Validates an Apple receipt with the App Store
 * @param {string} receiptData - Base64 encoded receipt
 * @returns {object} Validation result
 */
async function validateAppleReceipt(receiptData) {
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

    const { status, latest_receipt_info, pending_renewal_info } = response.data;

    // Status codes: 0 = valid, anything else = invalid
    if (status !== 0) {
      functions.logger.warn('Receipt validation failed', { status, receiptData: receiptData.substring(0, 50) });
      return {
        isValid: false,
        error: getErrorMessage(status)
      };
    }

    // Extract transaction info
    const latestTransaction = latest_receipt_info[0];

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
      receipt: response.data
    };

  } catch (error) {
    functions.logger.error('Receipt validation error', { error: error.message });
    throw new Error(`Failed to validate receipt: ${error.message}`);
  }
}

/**
 * Verifies webhook signature from Apple
 * @param {object} request - Express request object
 * @returns {boolean} True if signature is valid
 */
async function verifyWebhookSignature(request) {
  // TODO: Implement signature verification
  // Apple signs webhooks with their certificate
  // See: https://developer.apple.com/documentation/appstoreservernotifications/verifying_server_notifications

  // For now, verify the notification structure
  const notification = request.body;

  return (
    notification &&
    notification.notification_type &&
    notification.latest_receipt_info
  );
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
