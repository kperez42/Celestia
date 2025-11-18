/**
 * Tests for Fraud Detection Module
 * CRITICAL: Protects revenue from sophisticated fraud attacks
 */

const { describe, test, expect, beforeEach } = require('@jest/globals');

// Mock Firebase Admin
const mockFirestore = {
  collection: jest.fn()
};

jest.mock('firebase-admin', () => ({
  firestore: () => mockFirestore,
  initializeApp: jest.fn()
}));

jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  }
}));

const fraudDetection = require('../modules/fraudDetection');

describe('Fraud Detection Module', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('calculateFraudScore', () => {
    test('should return low score for legitimate new user', async () => {
      // Mock user with no fraud history
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({ size: 0, docs: [], empty: true }),
        doc: jest.fn(() => ({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              timestamp: { toDate: () => new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) } // 30 days old
            })
          })
        }))
      });

      const score = await fraudDetection.calculateFraudScore('user_legit', {
        jailbreakRisk: 0.1,
        transactionId: 'txn_123'
      });

      expect(score).toBeLessThan(30); // Low risk
    });

    test('should return high score for user with multiple refunds', async () => {
      // Mock user with 5 refunds
      mockFirestore.collection.mockImplementation((collectionName) => {
        if (collectionName === 'purchases') {
          return {
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({
              size: 5,
              docs: Array(5).fill({ data: () => ({ refunded: true }) })
            })
          };
        }
        if (collectionName === 'fraud_logs') {
          return {
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
          };
        }
        if (collectionName === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  timestamp: { toDate: () => new Date(Date.now() - 60 * 24 * 60 * 60 * 1000) }
                })
              })
            }))
          };
        }
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
        };
      });

      const score = await fraudDetection.calculateFraudScore('user_refunder', {
        jailbreakRisk: 0.2
      });

      expect(score).toBeGreaterThan(20); // At least refund points
    });

    test('should return very high score for jailbroken device', async () => {
      mockFirestore.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  timestamp: { toDate: () => new Date(Date.now() - 60 * 24 * 60 * 60 * 1000) }
                })
              })
            }))
          };
        }
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
        };
      });

      const score = await fraudDetection.calculateFraudScore('user_jailbreak', {
        jailbreakRisk: 0.9, // High jailbreak risk
        transactionId: 'txn_456'
      });

      expect(score).toBeGreaterThan(20); // Should get jailbreak penalty
    });

    test('should penalize brand new accounts heavily', async () => {
      mockFirestore.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  timestamp: { toDate: () => new Date(Date.now() - 12 * 60 * 60 * 1000) } // 12 hours old
                })
              })
            }))
          };
        }
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
        };
      });

      const score = await fraudDetection.calculateFraudScore('brand_new_user', {});

      expect(score).toBeGreaterThan(10); // New account penalty
    });

    test('should detect promotional code abuse', async () => {
      mockFirestore.collection.mockImplementation((collectionName) => {
        if (collectionName === 'purchases') {
          return {
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({
              size: 5, // 5 promotional purchases
              docs: Array(5).fill({
                data: () => ({
                  isPromotional: true,
                  purchaseDate: { toDate: () => new Date() }
                })
              })
            })
          };
        }
        if (collectionName === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  timestamp: { toDate: () => new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
                })
              })
            }))
          };
        }
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
        };
      });

      const score = await fraudDetection.calculateFraudScore('promo_abuser', {
        isPromotional: true
      });

      expect(score).toBeGreaterThan(15); // Promo abuse penalty
    });

    test('should cap fraud score at 100', async () => {
      // Setup extreme fraud indicators
      mockFirestore.collection.mockImplementation((collectionName) => {
        if (collectionName === 'purchases') {
          return {
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({
              size: 10,
              docs: Array(10).fill({
                data: () => ({
                  refunded: true,
                  isPromotional: true,
                  purchaseDate: { toDate: () => new Date(Date.now() - 1 * 60 * 60 * 1000) }, // 1 hour ago
                  refundDate: { toDate: () => new Date() }
                })
              })
            })
          };
        }
        if (collectionName === 'fraud_logs') {
          return {
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({
              size: 5, // Multiple validation failures AND fraud attempts
              docs: []
            })
          };
        }
        if (collectionName === 'users') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  timestamp: { toDate: () => new Date(Date.now() - 1 * 60 * 60 * 1000) }, // 1 hour old
                  profileComplete: false,
                  photos: []
                })
              })
            })),
            where: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({ size: 5 }) // Multiple users on device
          };
        }
        return {
          where: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ size: 0, docs: [] })
        };
      });

      const score = await fraudDetection.calculateFraudScore('extreme_fraudster', {
        jailbreakRisk: 0.95,
        isPromotional: true,
        deviceFingerprint: 'shared_device_123',
        productId: 'com.celestia.premium.lifetime'
      });

      expect(score).toBeLessThanOrEqual(100);
      expect(score).toBeGreaterThan(70); // Very high but capped
    });
  });

  describe('detectJailbreakIndicators', () => {
    test('should detect suspicious bundle ID', () => {
      const receipt = {
        bundle_id: 'com.celestia.cracked.app',
        receipt_creation_date_ms: String(Date.now())
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt);

      expect(riskScore).toBeGreaterThan(0.4);
    });

    test('should detect Cydia indicators', () => {
      const receipt = {
        bundle_id: 'com.legitimate.app',
        receipt_creation_date_ms: String(Date.now())
      };

      const deviceInfo = {
        isJailbroken: true,
        canOpenCydia: true,
        suspiciousPaths: ['/Applications/Cydia.app', '/Library/MobileSubstrate']
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt, deviceInfo);

      expect(riskScore).toBeGreaterThan(0.7); // Very high risk
    });

    test('should flag environment mismatch', () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      const receipt = {
        bundle_id: 'com.celestia.app',
        environment: 'Sandbox',
        receipt_creation_date_ms: String(Date.now())
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt);

      expect(riskScore).toBeGreaterThan(0.2);

      process.env.NODE_ENV = originalEnv;
    });

    test('should detect abnormally large in_app array', () => {
      const receipt = {
        bundle_id: 'com.celestia.app',
        in_app: Array(100).fill({}), // Abnormally large
        receipt_creation_date_ms: String(Date.now())
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt);

      expect(riskScore).toBeGreaterThan(0.2);
    });

    test('should flag very old receipts', () => {
      const twoYearsAgo = Date.now() - 730 * 24 * 60 * 60 * 1000;

      const receipt = {
        bundle_id: 'com.celestia.app',
        receipt_creation_date_ms: String(twoYearsAgo)
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt);

      expect(riskScore).toBeGreaterThan(0.1);
    });

    test('should return low risk for legitimate receipt', () => {
      const receipt = {
        bundle_id: 'com.celestia.app',
        environment: 'Production',
        receipt_creation_date: new Date().toISOString(),
        receipt_creation_date_ms: String(Date.now()),
        in_app: [{ product_id: 'premium' }]
      };

      const deviceInfo = {
        isJailbroken: false,
        suspiciousPaths: []
      };

      const riskScore = fraudDetection.detectJailbreakIndicators(receipt, deviceInfo);

      expect(riskScore).toBeLessThan(0.3);
    });
  });

  describe('checkReceiptDuplicate', () => {
    test('should detect receipt used by different user', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          empty: false,
          docs: [{
            data: () => ({ userId: 'original_user_123' })
          }]
        })
      });

      const isDuplicate = await fraudDetection.checkReceiptDuplicate('txn_999', 'fraudster_456');

      expect(isDuplicate).toBe(true);
    });

    test('should allow same user to re-validate receipt', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          empty: false,
          docs: [{
            data: () => ({ userId: 'same_user_123' })
          }]
        })
      });

      const isDuplicate = await fraudDetection.checkReceiptDuplicate('txn_888', 'same_user_123');

      expect(isDuplicate).toBe(false);
    });

    test('should allow first-time receipt validation', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          empty: true,
          docs: []
        })
      });

      const isDuplicate = await fraudDetection.checkReceiptDuplicate('txn_new', 'user_new');

      expect(isDuplicate).toBe(false);
    });
  });

  describe('checkPromotionalCodeAbuse', () => {
    test('should detect excessive promo code usage', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          size: 5, // More than threshold (3)
          docs: Array(5).fill({
            data: () => ({
              isPromotional: true,
              purchaseDate: { toDate: () => new Date() }
            })
          })
        })
      });

      const isAbuse = await fraudDetection.checkPromotionalCodeAbuse('user_promo', 'PROMO_CODE');

      expect(isAbuse).toBe(true);
    });

    test('should detect same promo code used multiple times', async () => {
      let callCount = 0;
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockImplementation(() => {
          callCount++;
          if (callCount === 1) {
            // First call - total promo usage (under threshold)
            return Promise.resolve({
              size: 2,
              docs: []
            });
          } else {
            // Second call - same promo code used twice
            return Promise.resolve({
              size: 2,
              docs: []
            });
          }
        })
      });

      const isAbuse = await fraudDetection.checkPromotionalCodeAbuse('user_123', 'SAME_PROMO');

      expect(isAbuse).toBe(true);
    });

    test('should allow legitimate promo usage', async () => {
      let callCount = 0;
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockImplementation(() => {
          callCount++;
          if (callCount === 1) {
            // Total promo usage
            return Promise.resolve({
              size: 1,
              docs: [{
                data: () => ({
                  purchaseDate: { toDate: () => new Date(Date.now() - 10 * 24 * 60 * 60 * 1000) }
                })
              }]
            });
          } else {
            // Same promo usage
            return Promise.resolve({
              size: 1,
              docs: []
            });
          }
        })
      });

      const isAbuse = await fraudDetection.checkPromotionalCodeAbuse('legit_user', 'PROMO_NEW');

      expect(isAbuse).toBe(false);
    });
  });

  describe('detectRapidPurchaseRefundCycle', () => {
    test('should detect high refund rate pattern', async () => {
      const purchases = Array(5).fill(null).map((_, i) => ({
        data: () => ({
          refunded: i < 4, // 4 out of 5 refunded (80%)
          purchaseDate: { toDate: () => new Date(Date.now() - i * 24 * 60 * 60 * 1000) }
        })
      }));

      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          size: 5,
          docs: purchases
        })
      });

      const isRapidCycle = await fraudDetection.detectRapidPurchaseRefundCycle('user_refunder');

      expect(isRapidCycle).toBe(true);
    });

    test('should detect rapid refunds within 24 hours', async () => {
      const now = new Date();
      const purchases = [
        {
          data: () => ({
            refunded: true,
            purchaseDate: { toDate: () => new Date(now.getTime() - 20 * 60 * 60 * 1000) }, // 20 hours ago
            refundDate: { toDate: () => new Date(now.getTime() - 10 * 60 * 60 * 1000) } // 10 hours ago
          })
        },
        {
          data: () => ({
            refunded: true,
            purchaseDate: { toDate: () => new Date(now.getTime() - 5 * 60 * 60 * 1000) }, // 5 hours ago
            refundDate: { toDate: () => now }
          })
        }
      ];

      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          size: 2,
          docs: purchases
        })
      });

      const isRapidCycle = await fraudDetection.detectRapidPurchaseRefundCycle('rapid_user');

      expect(isRapidCycle).toBe(true);
    });

    test('should allow legitimate purchase history', async () => {
      const purchases = Array(10).fill(null).map((_, i) => ({
        data: () => ({
          refunded: i === 0, // Only 1 refund out of 10
          purchaseDate: { toDate: () => new Date(Date.now() - i * 24 * 60 * 60 * 1000) }
        })
      }));

      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          size: 10,
          docs: purchases
        })
      });

      const isRapidCycle = await fraudDetection.detectRapidPurchaseRefundCycle('legit_user');

      expect(isRapidCycle).toBe(false);
    });
  });

  describe('checkVelocity', () => {
    test('should flag too many purchases per hour', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockImplementation(() => {
          // First call is hourly, second is daily
          const callCount = mockFirestore.collection.mock.results.length;
          return Promise.resolve({
            size: callCount === 1 ? 5 : 8 // 5 per hour, 8 per day
          });
        })
      });

      const riskScore = await fraudDetection.checkVelocity('rapid_buyer');

      expect(riskScore).toBeGreaterThan(10);
    });

    test('should allow normal purchase velocity', async () => {
      mockFirestore.collection.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({
          size: 1 // Normal: 1 purchase
        })
      });

      const riskScore = await fraudDetection.checkVelocity('normal_user');

      expect(riskScore).toBe(0);
    });
  });

  describe('trackFraudAttempt', () => {
    test('should log fraud attempt and create admin alert', async () => {
      const mockAdd = jest.fn().mockResolvedValue({ id: 'log_123' });
      let callCount = 0;

      mockFirestore.collection.mockImplementation(() => {
        callCount++;
        return {
          add: mockAdd
        };
      });

      await fraudDetection.trackFraudAttempt('fraudster_789', 'duplicate_receipt', {
        transactionId: 'txn_fraud'
      });

      expect(mockFirestore.collection).toHaveBeenCalledWith('fraud_logs');
      expect(mockFirestore.collection).toHaveBeenCalledWith('admin_alerts');
      expect(mockAdd).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'fraudster_789',
          eventType: 'fraud_attempt',
          fraudType: 'duplicate_receipt'
        })
      );
    });
  });

  describe('flagTransactionForReview', () => {
    test('should create flagged transaction record', async () => {
      const mockAdd = jest.fn().mockResolvedValue({ id: 'flag_123' });

      mockFirestore.collection.mockImplementation(() => ({
        add: mockAdd
      }));

      const transaction = {
        transaction_id: 'txn_suspicious',
        product_id: 'com.celestia.premium.lifetime'
      };

      await fraudDetection.flagTransactionForReview('user_suspicious', transaction, 65);

      expect(mockFirestore.collection).toHaveBeenCalledWith('flagged_transactions');
      expect(mockAdd).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user_suspicious',
          transactionId: 'txn_suspicious',
          fraudScore: 65,
          reviewed: false
        })
      );
    });

    test('should create admin alert for high-risk transactions', async () => {
      const mockAdd = jest.fn().mockResolvedValue({ id: 'alert_456' });

      mockFirestore.collection.mockImplementation(() => ({
        add: mockAdd
      }));

      const transaction = {
        transaction_id: 'txn_highrisk',
        product_id: 'com.celestia.premium.lifetime'
      };

      await fraudDetection.flagTransactionForReview('user_highrisk', transaction, 85);

      expect(mockFirestore.collection).toHaveBeenCalledWith('flagged_transactions');
      expect(mockFirestore.collection).toHaveBeenCalledWith('admin_alerts');
      expect(mockAdd).toHaveBeenCalledWith(
        expect.objectContaining({
          alertType: 'high_risk_transaction',
          priority: 'critical'
        })
      );
    });
  });

  describe('generateDeviceFingerprint', () => {
    test('should generate consistent fingerprint for same device', () => {
      const deviceInfo = {
        deviceModel: 'iPhone14,2',
        osVersion: '17.0',
        appVersion: '1.2.3',
        locale: 'en_US',
        timezone: 'America/New_York',
        vendorId: 'ABC-123-DEF'
      };

      const fingerprint1 = fraudDetection.generateDeviceFingerprint(deviceInfo);
      const fingerprint2 = fraudDetection.generateDeviceFingerprint(deviceInfo);

      expect(fingerprint1).toBe(fingerprint2);
      expect(fingerprint1).toHaveLength(64); // SHA256 hex length
    });

    test('should generate different fingerprints for different devices', () => {
      const device1 = {
        deviceModel: 'iPhone14,2',
        osVersion: '17.0',
        appVersion: '1.2.3',
        locale: 'en_US',
        timezone: 'America/New_York',
        vendorId: 'ABC-123'
      };

      const device2 = {
        deviceModel: 'iPhone13,1',
        osVersion: '16.5',
        appVersion: '1.2.3',
        locale: 'en_US',
        timezone: 'America/New_York',
        vendorId: 'XYZ-789'
      };

      const fingerprint1 = fraudDetection.generateDeviceFingerprint(device1);
      const fingerprint2 = fraudDetection.generateDeviceFingerprint(device2);

      expect(fingerprint1).not.toBe(fingerprint2);
    });
  });
});
