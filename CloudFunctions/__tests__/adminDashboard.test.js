/**
 * Tests for Admin Dashboard Module - Comprehensive Error Scenarios
 * Tests all admin operations for failure modes, data corruption, and edge cases
 */

const { describe, test, expect, beforeEach, jest } = require('@jest/globals');

// Mock firebase-admin with inline implementation
const mockGet = jest.fn();
const mockAdd = jest.fn();
const mockUpdate = jest.fn();

jest.mock('firebase-admin', () => {
  const mockDocFn = jest.fn(() => ({
    get: mockGet,
    update: mockUpdate
  }));

  const mockCollectionFn = jest.fn(() => ({
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    get: mockGet,
    add: mockAdd,
    doc: mockDocFn
  }));

  const mockFirestoreInstance = {
    collection: mockCollectionFn
  };

  const mockFirestoreFn = () => mockFirestoreInstance;
  mockFirestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => 'mock_timestamp'),
    arrayRemove: jest.fn((val) => ({ _arrayRemove: val }))
  };

  return {
    firestore: mockFirestoreFn,
    initializeApp: jest.fn()
  };
});

jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  }
}));

jest.mock('../modules/contentModeration', () => ({
  removePhoto: jest.fn()
}));

// Import after mocks
const adminDashboard = require('../modules/adminDashboard');
const contentModeration = require('../modules/contentModeration');

// Helper to create mock Firestore document
const createMockDoc = (id, data, exists = true) => ({
  id,
  exists,
  data: () => data,
  ref: { update: jest.fn(), delete: jest.fn() }
});

// Helper to create mock Firestore snapshot
const createMockSnapshot = (docs) => ({
  docs,
  size: docs.length,
  empty: docs.length === 0,
  forEach: (fn) => docs.forEach(fn)
});

describe('Admin Dashboard Module - Error Scenarios', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Clear the cache before each test
    adminDashboard.clearCache();
  });

  // ============================================================================
  // getStats() Error Scenarios
  // ============================================================================
  describe('getStats() - Error Scenarios', () => {
    test('should throw error when users collection query fails', async () => {
      mockGet.mockRejectedValue(new Error('Firestore unavailable'));

      await expect(adminDashboard.getStats()).rejects.toThrow('Firestore unavailable');
    });

    test('should throw error when database is not available', async () => {
      mockGet.mockRejectedValue(new Error('DEADLINE_EXCEEDED'));

      await expect(adminDashboard.getStats()).rejects.toThrow('DEADLINE_EXCEEDED');
    });

    test('should throw error when permission denied', async () => {
      const permissionError = new Error('PERMISSION_DENIED');
      permissionError.code = 'PERMISSION_DENIED';
      mockGet.mockRejectedValue(permissionError);

      await expect(adminDashboard.getStats()).rejects.toThrow('PERMISSION_DENIED');
    });

    test('should handle empty database gracefully', async () => {
      const emptySnapshot = createMockSnapshot([]);
      mockGet.mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getStats();

      expect(result.users.total).toBe(0);
      expect(result.users.active).toBe(0);
      expect(result.engagement.totalMatches).toBe(0);
      expect(result.revenue.last30Days).toBe(0);
    });

    test('should handle users with null/undefined lastActive field', async () => {
      const usersSnapshot = createMockSnapshot([
        createMockDoc('user1', { isPremium: true, lastActive: null }),
        createMockDoc('user2', { isPremium: false, lastActive: undefined }),
        createMockDoc('user3', { isPremium: true }) // missing lastActive entirely
      ]);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(usersSnapshot)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getStats();

      expect(result.users.total).toBe(3);
      expect(result.users.active).toBe(0);
    });

    test('should handle users with valid timestamps correctly', async () => {
      const now = new Date();
      const usersSnapshot = createMockSnapshot([
        createMockDoc('user1', {
          isPremium: true,
          isVerified: true,
          suspended: false,
          lastActive: { toDate: () => now },
          timestamp: { toDate: () => new Date(now.getTime() - 24 * 60 * 60 * 1000) }
        }),
        createMockDoc('user2', {
          isPremium: false,
          isVerified: false,
          suspended: true,
          lastActive: { toDate: () => new Date(now.getTime() - 48 * 60 * 60 * 1000) }
        })
      ]);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(usersSnapshot)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getStats();

      expect(result.users.total).toBe(2);
      expect(result.users.active).toBe(1);
      expect(result.users.premium).toBe(1);
      expect(result.users.verified).toBe(1);
      expect(result.users.suspended).toBe(1);
    });
  });

  // ============================================================================
  // getFlaggedContent() Error Scenarios
  // ============================================================================
  describe('getFlaggedContent() - Error Scenarios', () => {
    test('should throw error when flagged_content query fails', async () => {
      mockGet.mockRejectedValue(new Error('Query failed'));

      await expect(adminDashboard.getFlaggedContent()).rejects.toThrow('Query failed');
    });

    test('should handle empty flagged content list', async () => {
      const emptySnapshot = createMockSnapshot([]);
      mockGet.mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getFlaggedContent();
      expect(result).toHaveLength(0);
    });

    test('should handle missing user data gracefully', async () => {
      const flaggedSnapshot = createMockSnapshot([
        createMockDoc('flag1', {
          userId: 'nonexistent_user',
          reason: 'inappropriate',
          timestamp: { toDate: () => new Date() }
        })
      ]);

      const nonExistentUserDoc = createMockDoc('nonexistent_user', null, false);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(flaggedSnapshot)
        .mockResolvedValueOnce(nonExistentUserDoc)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getFlaggedContent();

      expect(result).toHaveLength(1);
      expect(result[0].user.fullName).toBe('Unknown');
      expect(result[0].user.email).toBe('Unknown');
    });
  });

  // ============================================================================
  // moderateContent() Error Scenarios
  // ============================================================================
  describe('moderateContent() - Error Scenarios', () => {
    test('should throw error when content not found', async () => {
      const nonExistentDoc = createMockDoc('nonexistent', null, false);
      mockGet.mockResolvedValue(nonExistentDoc);

      await expect(adminDashboard.moderateContent('nonexistent', 'approve'))
        .rejects.toThrow('Content not found');
    });

    test('should throw error when Firestore update fails', async () => {
      const existingDoc = createMockDoc('content1', {
        userId: 'user1',
        contentType: 'text',
        reviewed: false
      });

      mockGet.mockResolvedValue(existingDoc);
      mockUpdate.mockRejectedValue(new Error('Update failed - disk full'));

      await expect(adminDashboard.moderateContent('content1', 'approve'))
        .rejects.toThrow('Update failed - disk full');
    });

    test('should handle photo removal failure when rejecting content', async () => {
      const photoContentDoc = createMockDoc('photo1', {
        userId: 'user1',
        contentType: 'photo',
        contentUrl: 'https://storage.example.com/photo.jpg',
        reason: 'inappropriate'
      });

      mockGet.mockResolvedValue(photoContentDoc);
      mockUpdate.mockResolvedValue();
      contentModeration.removePhoto.mockRejectedValue(new Error('Storage deletion failed'));

      await expect(adminDashboard.moderateContent('photo1', 'reject', 'Violates TOS'))
        .rejects.toThrow('Storage deletion failed');
    });

    test('should successfully approve content', async () => {
      const contentDoc = createMockDoc('content1', {
        userId: 'user1',
        contentType: 'text',
        reviewed: false
      });

      mockGet.mockResolvedValue(contentDoc);
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.moderateContent('content1', 'approve', 'Looks good');
      expect(result.success).toBe(true);
    });

    test('should handle warning creation when rejecting text content', async () => {
      const textContentDoc = createMockDoc('text1', {
        userId: 'user1',
        contentType: 'text',
        reason: 'harassment'
      });
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(textContentDoc)
        .mockResolvedValue(emptySnapshot);

      mockUpdate.mockResolvedValue();
      mockAdd.mockResolvedValue();

      const result = await adminDashboard.moderateContent('text1', 'reject', 'Harassment');
      expect(result.success).toBe(true);
    });
  });

  // ============================================================================
  // getUserDetails() Error Scenarios
  // ============================================================================
  describe('getUserDetails() - Error Scenarios', () => {
    test('should throw error when user not found', async () => {
      const nonExistentDoc = createMockDoc('nonexistent', null, false);
      mockGet.mockResolvedValue(nonExistentDoc);

      await expect(adminDashboard.getUserDetails('nonexistent_user'))
        .rejects.toThrow('User not found');
    });

    test('should throw error when warnings query fails', async () => {
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com'
      });

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockRejectedValueOnce(new Error('Warnings query failed'));

      await expect(adminDashboard.getUserDetails('user1'))
        .rejects.toThrow('Warnings query failed');
    });

    test('should handle user with complete data', async () => {
      const now = new Date();
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        lastActive: { toDate: () => now },
        timestamp: { toDate: () => new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000) }
      });

      const warningsSnapshot = createMockSnapshot([
        createMockDoc('w1', { reason: 'spam', timestamp: { toDate: () => now } })
      ]);
      const reportsSnapshot = createMockSnapshot([]);
      const matchesSnapshot = createMockSnapshot([]);
      const messagesSnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockResolvedValueOnce(warningsSnapshot)
        .mockResolvedValueOnce(reportsSnapshot)
        .mockResolvedValueOnce(matchesSnapshot)
        .mockResolvedValueOnce(messagesSnapshot);

      const result = await adminDashboard.getUserDetails('user1');

      expect(result.fullName).toBe('Test User');
      expect(result.adminInfo.warningCount).toBe(1);
    });

    test('should handle user with null date fields', async () => {
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        lastActive: null,
        timestamp: null
      });

      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getUserDetails('user1');

      expect(result.fullName).toBe('Test User');
      expect(result.adminInfo.lastActive).toBeUndefined();
      expect(result.adminInfo.accountCreated).toBeUndefined();
    });
  });

  // ============================================================================
  // suspendUser() / unsuspendUser() Error Scenarios
  // ============================================================================
  describe('suspendUser() - Error Scenarios', () => {
    test('should throw error when user update fails', async () => {
      mockUpdate.mockRejectedValue(new Error('User suspension failed'));

      await expect(adminDashboard.suspendUser('user1', 'Violation'))
        .rejects.toThrow('User suspension failed');
    });

    test('should throw error when user does not exist', async () => {
      const notFoundError = new Error('NOT_FOUND');
      notFoundError.code = 5;
      mockUpdate.mockRejectedValue(notFoundError);

      await expect(adminDashboard.suspendUser('nonexistent_user', 'Spam'))
        .rejects.toThrow('NOT_FOUND');
    });

    test('should successfully suspend user with duration', async () => {
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.suspendUser('user1', 'Violation', 7);
      expect(result.success).toBe(true);
    });

    test('should successfully suspend user permanently (0 duration)', async () => {
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.suspendUser('user1', 'Permanent ban', 0);
      expect(result.success).toBe(true);
    });
  });

  describe('unsuspendUser() - Error Scenarios', () => {
    test('should throw error when unsuspension fails', async () => {
      mockUpdate.mockRejectedValue(new Error('Unsuspension failed'));

      await expect(adminDashboard.unsuspendUser('user1'))
        .rejects.toThrow('Unsuspension failed');
    });

    test('should successfully unsuspend user', async () => {
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.unsuspendUser('user1');
      expect(result.success).toBe(true);
    });
  });

  // ============================================================================
  // bulkUserOperation() Error Scenarios
  // ============================================================================
  describe('bulkUserOperation() - Error Scenarios', () => {
    test('should handle partial failures in bulk operations', async () => {
      let updateCallCount = 0;
      mockUpdate.mockImplementation(() => {
        updateCallCount++;
        if (updateCallCount === 2) {
          return Promise.reject(new Error('Update failed for user'));
        }
        return Promise.resolve();
      });
      mockAdd.mockResolvedValue();

      const result = await adminDashboard.bulkUserOperation(
        'ban',
        ['user1', 'user2', 'user3'],
        { reason: 'Spam' },
        'admin1'
      );

      expect(result.success.length).toBeGreaterThan(0);
      expect(result.failed.length).toBeGreaterThan(0);
      expect(result.total).toBe(3);
    });

    test('should handle all operations failing', async () => {
      mockUpdate.mockRejectedValue(new Error('Database unavailable'));
      mockAdd.mockResolvedValue();

      const result = await adminDashboard.bulkUserOperation(
        'verify',
        ['user1', 'user2', 'user3'],
        {},
        'admin1'
      );

      expect(result.success).toHaveLength(0);
      expect(result.failed).toHaveLength(3);
    });

    test('should fail for unknown operation type', async () => {
      mockAdd.mockResolvedValue();

      const result = await adminDashboard.bulkUserOperation(
        'invalid_operation',
        ['user1'],
        {},
        'admin1'
      );

      expect(result.failed).toHaveLength(1);
      expect(result.failed[0].error).toContain('Unknown operation');
    });

    test('should handle empty user array', async () => {
      mockAdd.mockResolvedValue();

      const result = await adminDashboard.bulkUserOperation(
        'ban',
        [],
        {},
        'admin1'
      );

      expect(result.success).toHaveLength(0);
      expect(result.failed).toHaveLength(0);
      expect(result.total).toBe(0);
    });

    test('should handle audit log failure but continue with operations', async () => {
      mockAdd
        .mockRejectedValueOnce(new Error('Audit log failed'))
        .mockRejectedValue(new Error('Audit log failed'));
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.bulkUserOperation(
        'verify',
        ['user1'],
        {},
        'admin1'
      );

      expect(result.success).toContain('user1');
    });

    test('should test all operation types successfully', async () => {
      mockUpdate.mockResolvedValue();
      mockAdd.mockResolvedValue();

      const banResult = await adminDashboard.bulkUserOperation('ban', ['user1'], { reason: 'Test', durationDays: 7 }, 'admin1');
      expect(banResult.success).toContain('user1');

      const verifyResult = await adminDashboard.bulkUserOperation('verify', ['user2'], {}, 'admin1');
      expect(verifyResult.success).toContain('user2');

      const premiumResult = await adminDashboard.bulkUserOperation('grantPremium', ['user3'], { tier: 'premium', months: 3 }, 'admin1');
      expect(premiumResult.success).toContain('user3');

      const revokeResult = await adminDashboard.bulkUserOperation('revokePremium', ['user4'], {}, 'admin1');
      expect(revokeResult.success).toContain('user4');

      const unbanResult = await adminDashboard.bulkUserOperation('unban', ['user5'], {}, 'admin1');
      expect(unbanResult.success).toContain('user5');
    });
  });

  // ============================================================================
  // getUserTimeline() Error Scenarios
  // ============================================================================
  describe('getUserTimeline() - Error Scenarios', () => {
    test('should throw error when user not found', async () => {
      const nonExistentDoc = createMockDoc('nonexistent', null, false);
      mockGet.mockResolvedValue(nonExistentDoc);

      await expect(adminDashboard.getUserTimeline('nonexistent_user'))
        .rejects.toThrow('User not found');
    });

    test('should throw error when matches query fails', async () => {
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        timestamp: { toDate: () => new Date() }
      });

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockRejectedValueOnce(new Error('Matches query failed'));

      await expect(adminDashboard.getUserTimeline('user1'))
        .rejects.toThrow('Matches query failed');
    });

    test('should handle user timeline with complete data', async () => {
      const now = new Date();
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        suspended: false,
        isPremium: true,
        isVerified: true,
        timestamp: { toDate: () => now }
      });

      const matchesSnapshot = createMockSnapshot([
        createMockDoc('match1', {
          user2Id: 'user2',
          isActive: true,
          timestamp: { toDate: () => now }
        })
      ]);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockResolvedValueOnce(matchesSnapshot)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getUserTimeline('user1');

      expect(result.userId).toBe('user1');
      expect(result.user.fullName).toBe('Test User');
      expect(result.timeline.length).toBeGreaterThan(0);
    });

    test('should handle null timestamps in timeline events', async () => {
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        timestamp: null
      });

      const matchesSnapshot = createMockSnapshot([
        createMockDoc('match1', {
          user2Id: 'user2',
          isActive: true,
          timestamp: null
        })
      ]);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockResolvedValueOnce(matchesSnapshot)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getUserTimeline('user1');

      expect(result.userId).toBe('user1');
      expect(result.timeline).toBeDefined();
    });
  });

  // ============================================================================
  // detectFraudPatterns() Error Scenarios
  // ============================================================================
  describe('detectFraudPatterns() - Error Scenarios', () => {
    test('should throw error when purchases query fails', async () => {
      mockGet.mockRejectedValue(new Error('Purchases query failed'));

      await expect(adminDashboard.detectFraudPatterns())
        .rejects.toThrow('Purchases query failed');
    });

    test('should handle empty purchase data', async () => {
      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result = await adminDashboard.detectFraudPatterns();

      expect(result.patterns.multipleRefunds).toHaveLength(0);
      expect(result.patterns.rapidPurchases).toHaveLength(0);
      expect(result.patterns.highFraudScore).toHaveLength(0);
      expect(result.summary.totalPatterns).toBe(0);
    });

    test('should handle purchases with missing fields', async () => {
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', { userId: 'user1', purchaseDate: null, refunded: null }),
        createMockDoc('p2', { userId: 'user2', purchaseDate: undefined, fraudScore: undefined }),
        createMockDoc('p3', { userId: null, deviceId: null })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.detectFraudPatterns();
      expect(result).toBeDefined();
      expect(result.patterns).toBeDefined();
    });

    test('should detect multiple refund pattern', async () => {
      const now = new Date();
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', { userId: 'user1', refunded: true, purchaseDate: { toDate: () => now } }),
        createMockDoc('p2', { userId: 'user1', refunded: true, purchaseDate: { toDate: () => now } }),
        createMockDoc('p3', { userId: 'user1', refunded: true, purchaseDate: { toDate: () => now } })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.detectFraudPatterns();

      expect(result.patterns.multipleRefunds).toHaveLength(1);
      expect(result.patterns.multipleRefunds[0].userId).toBe('user1');
      expect(result.patterns.multipleRefunds[0].severity).toBe('high');
    });

    test('should detect high fraud score pattern', async () => {
      const now = new Date();
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', { userId: 'user1', fraudScore: 95, productId: 'premium_monthly', purchaseDate: { toDate: () => now } })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.detectFraudPatterns();

      expect(result.patterns.highFraudScore).toHaveLength(1);
      expect(result.patterns.highFraudScore[0].severity).toBe('critical');
    });

    test('should detect suspicious device pattern', async () => {
      const now = new Date();
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', { userId: 'user1', deviceId: 'device123', purchaseDate: { toDate: () => now } }),
        createMockDoc('p2', { userId: 'user2', deviceId: 'device123', purchaseDate: { toDate: () => now } }),
        createMockDoc('p3', { userId: 'user3', deviceId: 'device123', purchaseDate: { toDate: () => now } }),
        createMockDoc('p4', { userId: 'user4', deviceId: 'device123', purchaseDate: { toDate: () => now } })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.detectFraudPatterns();

      expect(result.patterns.suspiciousDevices).toHaveLength(1);
      expect(result.patterns.suspiciousDevices[0].userCount).toBe(4);
    });

    test('should detect price manipulation', async () => {
      const now = new Date();
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', {
          userId: 'user1',
          productId: 'premium_monthly',
          price: '0.99',
          purchaseDate: { toDate: () => now }
        })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.detectFraudPatterns();

      expect(result.patterns.priceManipulation).toHaveLength(1);
      expect(result.patterns.priceManipulation[0].severity).toBe('critical');
    });
  });

  // ============================================================================
  // getAdminAuditLogs() Error Scenarios
  // ============================================================================
  describe('getAdminAuditLogs() - Error Scenarios', () => {
    test('should throw error when query fails', async () => {
      mockGet.mockRejectedValue(new Error('Audit logs unavailable'));

      await expect(adminDashboard.getAdminAuditLogs())
        .rejects.toThrow('Audit logs unavailable');
    });

    test('should handle empty audit logs', async () => {
      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result = await adminDashboard.getAdminAuditLogs();
      expect(result).toHaveLength(0);
    });

    test('should handle logs with null timestamps', async () => {
      const logsSnapshot = createMockSnapshot([
        createMockDoc('log1', { adminId: 'admin1', action: 'ban', timestamp: null }),
        createMockDoc('log2', { adminId: 'admin2', action: 'verify', timestamp: undefined })
      ]);

      mockGet.mockResolvedValue(logsSnapshot);

      const result = await adminDashboard.getAdminAuditLogs();
      expect(result).toHaveLength(2);
    });

    test('should return logs with valid timestamps', async () => {
      const now = new Date();
      const logsSnapshot = createMockSnapshot([
        createMockDoc('log1', {
          adminId: 'admin1',
          action: 'ban',
          timestamp: { toDate: () => now },
          details: { userId: 'user1' }
        })
      ]);

      mockGet.mockResolvedValue(logsSnapshot);

      const result = await adminDashboard.getAdminAuditLogs();
      expect(result).toHaveLength(1);
      expect(result[0].adminId).toBe('admin1');
    });
  });

  // ============================================================================
  // logAdminAction() Error Scenarios
  // ============================================================================
  describe('logAdminAction() - Error Scenarios', () => {
    test('should handle write failure gracefully (does not throw)', async () => {
      mockAdd.mockRejectedValue(new Error('Write failed'));

      await expect(adminDashboard.logAdminAction('admin1', 'test_action', {}))
        .resolves.toBeUndefined();
    });

    test('should handle permission denied error gracefully', async () => {
      const permissionError = new Error('PERMISSION_DENIED');
      mockAdd.mockRejectedValue(permissionError);

      await expect(adminDashboard.logAdminAction('admin1', 'test_action', {}))
        .resolves.toBeUndefined();
    });

    test('should successfully log admin action', async () => {
      mockAdd.mockResolvedValue({ id: 'log1' });

      await expect(adminDashboard.logAdminAction('admin1', 'test_action', { userId: 'user1' }))
        .resolves.toBeUndefined();
    });
  });

  // ============================================================================
  // Cache Functions Error Scenarios
  // ============================================================================
  describe('Cache Functions - Error Scenarios', () => {
    test('clearCache should handle empty cache', () => {
      expect(() => adminDashboard.clearCache()).not.toThrow();
    });

    test('invalidateCache should handle valid patterns', () => {
      expect(() => adminDashboard.invalidateCache('admin:*')).not.toThrow();
    });

    test('invalidateCache should handle non-matching patterns', () => {
      expect(() => adminDashboard.invalidateCache('nonexistent_pattern')).not.toThrow();
    });
  });

  // ============================================================================
  // getSubscriptionAnalytics() Error Scenarios
  // ============================================================================
  describe('getSubscriptionAnalytics() - Error Scenarios', () => {
    test('should throw error when purchases query fails', async () => {
      mockGet.mockRejectedValue(new Error('Analytics query failed'));

      await expect(adminDashboard.getSubscriptionAnalytics())
        .rejects.toThrow('Analytics query failed');
    });

    test('should handle empty subscription data', async () => {
      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result = await adminDashboard.getSubscriptionAnalytics();

      expect(result.totalPurchases).toBe(0);
      expect(result.subscriptions.total).toBe(0);
      expect(result.metrics.churnRate).toBe(0);
    });

    test('should calculate metrics correctly with data', async () => {
      const purchasesSnapshot = createMockSnapshot([
        createMockDoc('p1', { isSubscription: true, cancelled: true, refunded: false, fraudScore: 10 }),
        createMockDoc('p2', { isSubscription: true, cancelled: false, refunded: true, fraudScore: 80 }),
        createMockDoc('p3', { isSubscription: false, cancelled: false, refunded: false, fraudScore: 50 })
      ]);

      mockGet.mockResolvedValue(purchasesSnapshot);

      const result = await adminDashboard.getSubscriptionAnalytics();

      expect(result.totalPurchases).toBe(3);
      expect(result.subscriptions.cancelled).toBe(1);
      expect(result.subscriptions.refunded).toBe(1);
    });
  });

  // ============================================================================
  // getFraudDashboard() Error Scenarios
  // ============================================================================
  describe('getFraudDashboard() - Error Scenarios', () => {
    test('should throw error when fraud_logs query fails', async () => {
      mockGet.mockRejectedValue(new Error('Fraud logs query failed'));

      await expect(adminDashboard.getFraudDashboard())
        .rejects.toThrow('Fraud logs query failed');
    });

    test('should handle empty fraud dashboard data', async () => {
      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result = await adminDashboard.getFraudDashboard();

      expect(result.fraudLogs).toHaveLength(0);
      expect(result.flaggedTransactions).toHaveLength(0);
      expect(result.refundAbusers).toHaveLength(0);
      expect(result.statistics.totalFraudAttempts).toBe(0);
    });

    test('should handle missing user data in flagged transactions', async () => {
      const fraudLogsSnapshot = createMockSnapshot([]);
      const flaggedTransactionsSnapshot = createMockSnapshot([
        createMockDoc('t1', {
          userId: 'nonexistent_user',
          fraudScore: 85,
          timestamp: { toDate: () => new Date() }
        })
      ]);

      const nonExistentUserDoc = createMockDoc('nonexistent_user', null, false);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(fraudLogsSnapshot)
        .mockResolvedValueOnce(flaggedTransactionsSnapshot)
        .mockResolvedValueOnce(nonExistentUserDoc)
        .mockResolvedValue(emptySnapshot);

      const result = await adminDashboard.getFraudDashboard();

      expect(result.flaggedTransactions).toHaveLength(1);
      expect(result.flaggedTransactions[0].user.fullName).toBe('Unknown');
    });

    test('should identify refund abusers correctly', async () => {
      const fraudLogsSnapshot = createMockSnapshot([]);
      const flaggedTransactionsSnapshot = createMockSnapshot([]);
      const refundHistorySnapshot = createMockSnapshot([
        createMockDoc('r1', { userId: 'user1', timestamp: { toDate: () => new Date() } }),
        createMockDoc('r2', { userId: 'user1', timestamp: { toDate: () => new Date() } }),
        createMockDoc('r3', { userId: 'user1', timestamp: { toDate: () => new Date() } })
      ]);
      const adminAlertsSnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(fraudLogsSnapshot)
        .mockResolvedValueOnce(flaggedTransactionsSnapshot)
        .mockResolvedValueOnce(refundHistorySnapshot)
        .mockResolvedValueOnce(adminAlertsSnapshot);

      const result = await adminDashboard.getFraudDashboard();

      expect(result.refundAbusers).toHaveLength(1);
      expect(result.refundAbusers[0].userId).toBe('user1');
      expect(result.refundAbusers[0].refundCount).toBe(3);
    });
  });

  // ============================================================================
  // getRefundTracking() Error Scenarios
  // ============================================================================
  describe('getRefundTracking() - Error Scenarios', () => {
    test('should throw error when refund query fails', async () => {
      mockGet.mockRejectedValue(new Error('Refund tracking query failed'));

      await expect(adminDashboard.getRefundTracking())
        .rejects.toThrow('Refund tracking query failed');
    });

    test('should handle empty refund data', async () => {
      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result = await adminDashboard.getRefundTracking();
      expect(result).toHaveLength(0);
    });

    test('should handle missing user data in refunds', async () => {
      const now = new Date();
      const refundsSnapshot = createMockSnapshot([
        createMockDoc('r1', {
          userId: 'nonexistent',
          refundDate: { toDate: () => now },
          purchaseDate: { toDate: () => now }
        })
      ]);

      const nonExistentUserDoc = createMockDoc('nonexistent', null, false);
      const emptyRefundsSnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(refundsSnapshot)
        .mockResolvedValueOnce(nonExistentUserDoc)
        .mockResolvedValue(emptyRefundsSnapshot);

      const result = await adminDashboard.getRefundTracking();

      expect(result).toHaveLength(1);
      expect(result[0].user.fullName).toBe('Unknown');
    });
  });

  // ============================================================================
  // reviewFlaggedTransaction() Error Scenarios
  // ============================================================================
  describe('reviewFlaggedTransaction() - Error Scenarios', () => {
    test('should throw error when transaction not found', async () => {
      const nonExistentDoc = createMockDoc('nonexistent', null, false);
      mockGet.mockResolvedValue(nonExistentDoc);

      await expect(adminDashboard.reviewFlaggedTransaction('nonexistent', 'approve'))
        .rejects.toThrow('Flagged transaction not found');
    });

    test('should throw error when update fails', async () => {
      const transactionDoc = createMockDoc('t1', {
        userId: 'user1',
        fraudScore: 85
      });

      mockGet.mockResolvedValue(transactionDoc);
      mockUpdate.mockRejectedValue(new Error('Update failed'));

      await expect(adminDashboard.reviewFlaggedTransaction('t1', 'approve'))
        .rejects.toThrow('Update failed');
    });

    test('should approve transaction successfully', async () => {
      const transactionDoc = createMockDoc('t1', {
        userId: 'user1',
        fraudScore: 30
      });

      mockGet.mockResolvedValue(transactionDoc);
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.reviewFlaggedTransaction('t1', 'approve', 'Verified');
      expect(result.success).toBe(true);
    });

    test('should suspend user when transaction is rejected', async () => {
      const transactionDoc = createMockDoc('t1', {
        userId: 'user1',
        fraudScore: 90
      });

      mockGet.mockResolvedValue(transactionDoc);
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.reviewFlaggedTransaction('t1', 'reject', 'Fraud confirmed');

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();
    });

    test('should handle user suspension failure during rejection', async () => {
      const transactionDoc = createMockDoc('t1', {
        userId: 'user1',
        fraudScore: 90
      });

      mockGet.mockResolvedValue(transactionDoc);
      mockUpdate
        .mockResolvedValueOnce()
        .mockRejectedValueOnce(new Error('User suspension failed'));

      await expect(adminDashboard.reviewFlaggedTransaction('t1', 'reject'))
        .rejects.toThrow('User suspension failed');
    });
  });

  // ============================================================================
  // Data Corruption and Erasure Scenarios
  // ============================================================================
  describe('Data Corruption and Erasure Scenarios', () => {
    test('should handle corrupted user data during bulk operation', async () => {
      mockAdd.mockResolvedValue();

      let updateCallCount = 0;
      mockUpdate.mockImplementation(() => {
        updateCallCount++;
        if (updateCallCount === 2) {
          return Promise.reject(new Error('Document corrupted'));
        }
        return Promise.resolve();
      });

      const result = await adminDashboard.bulkUserOperation(
        'verify',
        ['user1', 'user2', 'user3'],
        {},
        'admin1'
      );

      expect(result.success.length).toBeGreaterThan(0);
      expect(result.failed.length).toBeGreaterThan(0);
      expect(result.failed.some(f => f.error.includes('corrupted'))).toBe(true);
    });

    test('should handle race condition during moderation', async () => {
      const contentDoc = createMockDoc('content1', {
        userId: 'user1',
        contentType: 'text',
        reviewed: false
      });

      mockGet.mockResolvedValue(contentDoc);
      mockUpdate.mockRejectedValue(new Error('ABORTED: Document was updated'));

      await expect(adminDashboard.moderateContent('content1', 'approve'))
        .rejects.toThrow('ABORTED: Document was updated');
    });

    test('should handle data loss during user timeline fetch', async () => {
      const userDoc = createMockDoc('user1', {
        fullName: 'Test User',
        email: 'test@example.com',
        timestamp: { toDate: () => new Date() }
      });

      mockGet
        .mockResolvedValueOnce(userDoc)
        .mockRejectedValueOnce(new Error('Collection not found'));

      await expect(adminDashboard.getUserTimeline('user1'))
        .rejects.toThrow('Collection not found');
    });

    test('should detect when admin saves get erased (consecutive operations)', async () => {
      mockAdd.mockResolvedValue();

      let operationCount = 0;
      mockUpdate.mockImplementation(() => {
        operationCount++;
        if (operationCount > 2) {
          return Promise.reject(new Error('Database connection lost'));
        }
        return Promise.resolve();
      });

      const result = await adminDashboard.bulkUserOperation(
        'grantPremium',
        ['user1', 'user2', 'user3', 'user4'],
        { tier: 'premium' },
        'admin1'
      );

      expect(result.success.length).toBeGreaterThan(0);
      expect(result.failed.length).toBeGreaterThan(0);
    });

    test('should handle admin operation when cache is stale', async () => {
      const initialUsersSnapshot = createMockSnapshot([
        createMockDoc('user1', { isPremium: true, lastActive: { toDate: () => new Date() } })
      ]);
      const emptySnapshot = createMockSnapshot([]);

      mockGet
        .mockResolvedValueOnce(initialUsersSnapshot)
        .mockResolvedValue(emptySnapshot);

      const result1 = await adminDashboard.getStats();
      expect(result1.users.total).toBe(1);

      adminDashboard.clearCache();

      mockGet.mockResolvedValue(createMockSnapshot([]));

      const result2 = await adminDashboard.getStats();
      expect(result2.users.total).toBe(0);
    });
  });

  // ============================================================================
  // Edge Cases and Boundary Conditions
  // ============================================================================
  describe('Edge Cases and Boundary Conditions', () => {
    test('should handle large user arrays in bulk operation', async () => {
      mockUpdate.mockResolvedValue();
      mockAdd.mockResolvedValue();

      const userIds = Array.from({ length: 100 }, (_, i) => `user${i}`);

      const result = await adminDashboard.bulkUserOperation(
        'verify',
        userIds,
        {},
        'admin1'
      );

      expect(result.success).toHaveLength(100);
      expect(result.total).toBe(100);
    });

    test('should handle special characters in user IDs', async () => {
      mockUpdate.mockResolvedValue();
      mockAdd.mockResolvedValue();

      const specialUserIds = [
        'user@email.com',
        'user/with/slashes',
        'user.with.dots',
        'user_with_underscores',
        'user-with-dashes'
      ];

      const result = await adminDashboard.bulkUserOperation(
        'verify',
        specialUserIds,
        {},
        'admin1'
      );

      expect(result.success).toHaveLength(5);
    });

    test('should handle unicode in admin notes', async () => {
      const contentDoc = createMockDoc('content1', {
        userId: 'user1',
        contentType: 'text'
      });

      mockGet.mockResolvedValue(contentDoc);
      mockUpdate.mockResolvedValue();

      const unicodeNote = '违规内容 - 包含不当信息 🚫 محتوى غير لائق';

      const result = await adminDashboard.moderateContent('content1', 'approve', unicodeNote);

      expect(result.success).toBe(true);
    });

    test('should handle very long suspension reasons', async () => {
      mockUpdate.mockResolvedValue();

      const longReason = 'A'.repeat(10000);

      const result = await adminDashboard.suspendUser('user1', longReason, 7);

      expect(result.success).toBe(true);
    });

    test('should handle zero duration suspension (permanent)', async () => {
      mockUpdate.mockResolvedValue();

      const result = await adminDashboard.suspendUser('user1', 'Permanent ban', 0);
      expect(result.success).toBe(true);
    });
  });
});
