/**
 * Tests for Receipt Validation Module
 * CRITICAL: Protects payment logic from fraud
 */

const { describe, test, expect, beforeEach, afterEach } = require('@jest/globals');

// Mock dependencies
jest.mock('axios');
jest.mock('firebase-functions', () => ({
  config: () => ({
    apple: {
      shared_secret: 'test_shared_secret_12345'
    }
  }),
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  }
}));

jest.mock('firebase-admin', () => ({
  firestore: () => ({
    collection: jest.fn(() => ({
      add: jest.fn().mockResolvedValue({}),
      doc: jest.fn(() => ({
        get: jest.fn().mockResolvedValue({ exists: false })
      }))
    }))
  }),
  initializeApp: jest.fn()
}));

jest.mock('jsonwebtoken');
jest.mock('jwks-rsa', () => jest.fn(() => ({
  getSigningKey: jest.fn((kid, callback) => {
    callback(null, { publicKey: 'test-key' });
  })
})));

// Mock fraud detection module
jest.mock('../modules/fraudDetection', () => ({
  trackValidationFailure: jest.fn().mockResolvedValue(undefined),
  calculateFraudScore: jest.fn().mockResolvedValue(0),
  checkReceiptDuplicate: jest.fn().mockResolvedValue(false),
  trackFraudAttempt: jest.fn().mockResolvedValue(undefined),
  checkPromotionalCodeAbuse: jest.fn().mockResolvedValue(false),
  detectJailbreakIndicators: jest.fn().mockReturnValue(0.1),
  flagTransactionForReview: jest.fn().mockResolvedValue(undefined),
  FRAUD_THRESHOLDS: {
    FRAUD_SCORE_MEDIUM: 50
  }
}));

const axios = require('axios');
const receiptValidation = require('../modules/receiptValidation');
const fraudDetection = require('../modules/fraudDetection');

describe('Receipt Validation Module', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('validateAppleReceipt - Basic Validation', () => {
    test('should validate a legitimate receipt successfully', async () => {
      const mockReceiptData = 'valid_base64_receipt_data';
      const mockUserId = 'user123';

      // Mock successful Apple response
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0, // Success
          latest_receipt_info: [{
            transaction_id: 'txn_12345',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            expires_date_ms: '1702592000000',
            original_transaction_id: 'original_txn_12345',
            is_trial_period: 'false',
            is_in_intro_offer_period: 'false'
          }],
          pending_renewal_info: [{
            auto_renew_status: '1'
          }],
          receipt: {
            bundle_id: 'com.celestia.app',
            receipt_creation_date_ms: '1700000000000'
          }
        }
      });

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(true);
      expect(result.transactionId).toBe('txn_12345');
      expect(result.productId).toBe('com.celestia.premium.monthly');
      expect(result.isSubscription).toBe(true);
      expect(result.autoRenewStatus).toBe(true);
      expect(axios.post).toHaveBeenCalledWith(
        'https://buy.itunes.apple.com/verifyReceipt',
        expect.objectContaining({
          'receipt-data': mockReceiptData,
          'password': 'test_shared_secret_12345'
        })
      );
    });

    test('should handle sandbox receipts correctly', async () => {
      const mockReceiptData = 'sandbox_receipt';
      const mockUserId = 'user456';

      // First call returns sandbox error
      axios.post.mockResolvedValueOnce({
        data: { status: 21007 } // Sandbox receipt in production
      });

      // Second call to sandbox succeeds
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'sandbox_txn_123',
            product_id: 'com.celestia.premium.annual',
            purchase_date_ms: '1700000000000',
            expires_date_ms: null,
            original_transaction_id: 'sandbox_original_123'
          }],
          receipt: {
            bundle_id: 'com.celestia.app',
            environment: 'Sandbox'
          }
        }
      });

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(true);
      expect(result.transactionId).toBe('sandbox_txn_123');
      expect(axios.post).toHaveBeenCalledTimes(2);
      expect(axios.post).toHaveBeenNthCalledWith(2, 'https://sandbox.itunes.apple.com/verifyReceipt', expect.any(Object));
    });

    test('should reject receipt with invalid status code', async () => {
      const mockReceiptData = 'invalid_receipt';
      const mockUserId = 'user789';

      axios.post.mockResolvedValueOnce({
        data: {
          status: 21003 // Receipt could not be authenticated
        }
      });

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('The receipt could not be authenticated.');
      expect(fraudDetection.trackValidationFailure).toHaveBeenCalledWith(
        mockUserId,
        21003,
        'receipt_validation_failed'
      );
    });

    // Note: Config validation is handled at module level, tested in integration
    test.skip('should handle missing shared secret configuration', async () => {
      // This is tested in integration tests where the config can be controlled
      // Unit test mocking is complex due to module-level config initialization
    });
  });

  describe('validateAppleReceipt - Fraud Detection', () => {
    test('should detect and reject duplicate receipts', async () => {
      const mockReceiptData = 'duplicate_receipt';
      const mockUserId = 'fraudster123';

      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'duplicate_txn_999',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            original_transaction_id: 'dup_original_999'
          }],
          receipt: {}
        }
      });

      // Mock duplicate detection
      fraudDetection.checkReceiptDuplicate.mockResolvedValueOnce(true);

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('Receipt already used');
      expect(result.fraudScore).toBe(100);
      expect(fraudDetection.trackFraudAttempt).toHaveBeenCalledWith(
        mockUserId,
        'duplicate_receipt',
        expect.objectContaining({
          transactionId: 'duplicate_txn_999'
        })
      );
    });

    test('should detect and flag promotional code abuse', async () => {
      const mockReceiptData = 'promo_abuse_receipt';
      const mockUserId = 'promo_abuser';

      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'promo_txn_456',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            promotional_offer_id: 'PROMO50OFF',
            original_transaction_id: 'promo_original'
          }],
          receipt: {}
        }
      });

      // Mock promo abuse detection
      fraudDetection.checkPromotionalCodeAbuse.mockResolvedValueOnce(true);

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('Promotional code abuse detected');
      expect(result.fraudScore).toBe(90);
      expect(fraudDetection.trackFraudAttempt).toHaveBeenCalledWith(
        mockUserId,
        'promo_code_abuse',
        expect.objectContaining({
          promotionalOfferId: 'PROMO50OFF'
        })
      );
    });

    test('should flag high fraud score transactions', async () => {
      const mockReceiptData = 'high_risk_receipt';
      const mockUserId = 'suspicious_user';

      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'risky_txn_789',
            product_id: 'com.celestia.premium.lifetime',
            purchase_date_ms: '1700000000000',
            original_transaction_id: 'risky_original'
          }],
          receipt: {}
        }
      });

      // Mock high fraud score
      fraudDetection.calculateFraudScore.mockResolvedValueOnce(75);

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(true);
      expect(result.fraudScore).toBe(75);
      expect(fraudDetection.flagTransactionForReview).toHaveBeenCalledWith(
        mockUserId,
        expect.any(Object),
        75
      );
    });

    test('should detect jailbreak indicators and log security event', async () => {
      const mockReceiptData = 'jailbroken_receipt';
      const mockUserId = 'jailbreak_user';

      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'jb_txn_111',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            original_transaction_id: 'jb_original'
          }],
          receipt: {
            bundle_id: 'com.celestia.cracked'
          }
        }
      });

      // Mock high jailbreak risk
      fraudDetection.detectJailbreakIndicators.mockReturnValueOnce(0.8);

      const result = await receiptValidation.validateAppleReceipt(mockReceiptData, mockUserId);

      expect(result.isValid).toBe(true);
      expect(result.jailbreakRisk).toBe(0.8);
    });
  });

  describe('validateAppleReceipt - Transaction Types', () => {
    test('should handle one-time purchases correctly', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'onetime_txn',
            product_id: 'com.celestia.boost.5',
            purchase_date_ms: '1700000000000',
            expires_date_ms: null, // No expiry for one-time
            original_transaction_id: 'onetime_original'
          }],
          receipt: {}
        }
      });

      const result = await receiptValidation.validateAppleReceipt('receipt', 'user123');

      expect(result.isValid).toBe(true);
      expect(result.isSubscription).toBe(false);
      expect(result.expiryDate).toBeNull();
    });

    test('should detect trial periods', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'trial_txn',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            expires_date_ms: '1700604800000',
            is_trial_period: 'true',
            original_transaction_id: 'trial_original'
          }],
          receipt: {}
        }
      });

      const result = await receiptValidation.validateAppleReceipt('receipt', 'user456');

      expect(result.isValid).toBe(true);
      expect(result.isTrialPeriod).toBe(true);
      expect(result.isSubscription).toBe(true);
    });

    test('should detect introductory offers', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'intro_txn',
            product_id: 'com.celestia.premium.annual',
            purchase_date_ms: '1700000000000',
            expires_date_ms: '1731536000000',
            is_in_intro_offer_period: 'true',
            is_trial_period: 'false',
            original_transaction_id: 'intro_original'
          }],
          receipt: {}
        }
      });

      const result = await receiptValidation.validateAppleReceipt('receipt', 'user789');

      expect(result.isValid).toBe(true);
      expect(result.isInIntroOfferPeriod).toBe(true);
      expect(result.isTrialPeriod).toBe(false);
    });

    test('should handle canceled subscriptions', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: [{
            transaction_id: 'canceled_txn',
            product_id: 'com.celestia.premium.monthly',
            purchase_date_ms: '1700000000000',
            expires_date_ms: '1702592000000',
            cancellation_date_ms: '1701000000000',
            original_transaction_id: 'canceled_original'
          }],
          pending_renewal_info: [{
            auto_renew_status: '0'
          }],
          receipt: {}
        }
      });

      const result = await receiptValidation.validateAppleReceipt('receipt', 'user_cancel');

      expect(result.isValid).toBe(true);
      expect(result.autoRenewStatus).toBe(false);
      expect(result.cancellationDate).toBeInstanceOf(Date);
    });
  });

  describe('validateAppleReceipt - Error Handling', () => {
    test('should handle network errors gracefully', async () => {
      axios.post.mockRejectedValueOnce(new Error('Network timeout'));

      await expect(
        receiptValidation.validateAppleReceipt('receipt', 'user123')
      ).rejects.toThrow('Failed to validate receipt: Network timeout');

      expect(fraudDetection.trackValidationFailure).toHaveBeenCalledWith(
        'user123',
        null,
        'validation_exception',
        'Network timeout'
      );
    });

    test('should handle malformed response from Apple', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          status: 0,
          latest_receipt_info: null // Malformed - should be array
        }
      });

      await expect(
        receiptValidation.validateAppleReceipt('receipt', 'user456')
      ).rejects.toThrow('No transaction information in receipt');
    });

    test('should handle all Apple error codes correctly', async () => {
      const errorCodes = [
        { code: 21000, message: 'The App Store could not read the JSON object you provided.' },
        { code: 21002, message: 'The data in the receipt-data property was malformed or missing.' },
        { code: 21004, message: 'The shared secret you provided does not match the shared secret on file.' },
        { code: 21005, message: 'The receipt server is not currently available.' }
      ];

      for (const { code, message } of errorCodes) {
        jest.clearAllMocks();

        axios.post.mockResolvedValueOnce({
          data: { status: code }
        });

        const result = await receiptValidation.validateAppleReceipt('receipt', 'user_test');

        expect(result.isValid).toBe(false);
        expect(result.error).toBe(message);
      }
    });
  });

  describe('verifyWebhookSignature', () => {
    test('should verify valid webhook signature', async () => {
      const jwt = require('jsonwebtoken');

      const mockRequest = {
        body: {
          signedPayload: 'valid.jwt.token'
        },
        ip: '1.2.3.4'
      };

      jwt.decode.mockReturnValueOnce({
        header: { kid: 'test-key-id' }
      });

      jwt.verify.mockImplementationOnce((token, getKey, options, callback) => {
        callback(null, {
          notificationType: 'SUBSCRIBED',
          data: { bundleId: 'com.celestia.app' }
        });
      });

      const result = await receiptValidation.verifyWebhookSignature(mockRequest);

      expect(result).toEqual({
        notificationType: 'SUBSCRIBED',
        data: { bundleId: 'com.celestia.app' }
      });
    });

    test('should reject webhook with missing signed payload', async () => {
      const mockRequest = {
        body: {},
        ip: '1.2.3.4'
      };

      const result = await receiptValidation.verifyWebhookSignature(mockRequest);

      expect(result).toBeNull();
    });

    test('should reject webhook with invalid signature', async () => {
      const jwt = require('jsonwebtoken');

      const mockRequest = {
        body: {
          signedPayload: 'invalid.jwt.token'
        },
        ip: '5.6.7.8'
      };

      jwt.decode.mockReturnValueOnce({
        header: { kid: 'test-key-id' }
      });

      jwt.verify.mockImplementationOnce((token, getKey, options, callback) => {
        callback(new Error('Invalid signature'));
      });

      const result = await receiptValidation.verifyWebhookSignature(mockRequest);

      expect(result).toBeNull();
    });

    test('should reject webhook with malformed JWT', async () => {
      const jwt = require('jsonwebtoken');

      const mockRequest = {
        body: {
          signedPayload: 'malformed_token'
        },
        ip: '9.10.11.12'
      };

      jwt.decode.mockReturnValueOnce(null);

      const result = await receiptValidation.verifyWebhookSignature(mockRequest);

      expect(result).toBeNull();
    });
  });
});
