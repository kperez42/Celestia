/**
 * Tests for Admin Security Module
 * CRITICAL: Protects admin endpoints from brute force and abuse
 */

const { describe, test, expect, beforeEach } = require('@jest/globals');

jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  }
}));

const adminSecurity = require('../modules/adminSecurity');

describe('Admin Security Module', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('checkAdminLoginRateLimit', () => {
    test('should allow login attempts within limit', async () => {
      const result = await adminSecurity.checkAdminLoginRateLimit('ip_192.168.1.1');

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBeDefined();
    });

    test('should block after exceeding login attempts', async () => {
      const identifier = 'ip_192.168.1.100';

      // Make 5 attempts (the limit)
      for (let i = 0; i < 5; i++) {
        await adminSecurity.checkAdminLoginRateLimit(identifier);
      }

      // 6th attempt should be blocked
      const result = await adminSecurity.checkAdminLoginRateLimit(identifier);

      expect(result.allowed).toBe(false);
      expect(result.message).toBe('Too many login attempts. Please try again later.');
      expect(result.retryAfter).toBeGreaterThan(0);
    });

    test('should provide retry time when blocked', async () => {
      const identifier = 'ip_10.0.0.1';

      // Exhaust the limit
      for (let i = 0; i < 6; i++) {
        await adminSecurity.checkAdminLoginRateLimit(identifier);
      }

      const result = await adminSecurity.checkAdminLoginRateLimit(identifier);

      expect(result.retryAfter).toBeDefined();
      expect(typeof result.retryAfter).toBe('number');
      expect(result.retryAfter).toBeGreaterThan(0);
    });

    test('should track different identifiers separately', async () => {
      const ip1 = 'ip_1.1.1.1';
      const ip2 = 'ip_2.2.2.2';

      // Exhaust limit for ip1
      for (let i = 0; i < 6; i++) {
        await adminSecurity.checkAdminLoginRateLimit(ip1);
      }

      // ip2 should still be allowed
      const result = await adminSecurity.checkAdminLoginRateLimit(ip2);

      expect(result.allowed).toBe(true);
    });
  });

  describe('checkAdminActionRateLimit', () => {
    test('should allow admin actions within limit', async () => {
      const result = await adminSecurity.checkAdminActionRateLimit('admin_user_123');

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBeDefined();
      expect(result.remaining).toBeGreaterThan(0);
    });

    test('should block after 100 actions per minute', async () => {
      const adminId = 'admin_rapid_fire';

      // Make 100 requests (the limit)
      for (let i = 0; i < 100; i++) {
        await adminSecurity.checkAdminActionRateLimit(adminId);
      }

      // 101st should be blocked
      const result = await adminSecurity.checkAdminActionRateLimit(adminId);

      expect(result.allowed).toBe(false);
      expect(result.message).toBe('Rate limit exceeded. Please slow down.');
    });

    test('should decrease remaining count correctly', async () => {
      const adminId = 'admin_counter';

      const result1 = await adminSecurity.checkAdminActionRateLimit(adminId);
      const result2 = await adminSecurity.checkAdminActionRateLimit(adminId);

      expect(result1.allowed).toBe(true);
      expect(result2.allowed).toBe(true);
      expect(result2.remaining).toBeLessThan(result1.remaining);
    });
  });

  describe('checkBulkOperationRateLimit', () => {
    test('should allow bulk operations within limit', async () => {
      const result = await adminSecurity.checkBulkOperationRateLimit('admin_bulk_123');

      expect(result.allowed).toBe(true);
    });

    test('should block after 10 bulk operations per hour', async () => {
      const adminId = 'admin_bulk_abuser';

      // Make 10 bulk operations (the limit)
      for (let i = 0; i < 10; i++) {
        await adminSecurity.checkBulkOperationRateLimit(adminId);
      }

      // 11th should be blocked
      const result = await adminSecurity.checkBulkOperationRateLimit(adminId);

      expect(result.allowed).toBe(false);
      expect(result.message).toBe('Bulk operation limit exceeded. Please wait before trying again.');
      expect(result.retryAfter).toBeDefined();
    });

    test('should provide longer retry time for bulk operations', async () => {
      const adminId = 'admin_bulk_test';

      // Exhaust limit
      for (let i = 0; i < 11; i++) {
        await adminSecurity.checkBulkOperationRateLimit(adminId);
      }

      const result = await adminSecurity.checkBulkOperationRateLimit(adminId);

      expect(result.retryAfter).toBeGreaterThan(0);
    });
  });

  describe('requireAdmin middleware', () => {
    test('should reject requests without authentication', async () => {
      const middleware = adminSecurity.requireAdmin();

      const req = { auth: null };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      const next = jest.fn();

      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized - Authentication required' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should check rate limit for authenticated users', async () => {
      const middleware = adminSecurity.requireAdmin(true);

      const req = { auth: { uid: 'admin_456' } };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        set: jest.fn()
      };
      const next = jest.fn();

      await middleware(req, res, next);

      expect(res.set).toHaveBeenCalledWith('X-RateLimit-Remaining', expect.any(String));
      expect(next).toHaveBeenCalled();
    });

    test('should block rate-limited users', async () => {
      const middleware = adminSecurity.requireAdmin(true);

      const adminId = 'admin_ratelimited';

      // Exhaust rate limit
      for (let i = 0; i < 101; i++) {
        await adminSecurity.checkAdminActionRateLimit(adminId);
      }

      const req = { auth: { uid: adminId } };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        set: jest.fn()
      };
      const next = jest.fn();

      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(429);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.stringContaining('Rate limit exceeded'),
          retryAfter: expect.any(Number)
        })
      );
      expect(next).not.toHaveBeenCalled();
    });

    test('should skip rate limiting when checkRateLimit is false', async () => {
      const middleware = adminSecurity.requireAdmin(false);

      const req = { auth: { uid: 'admin_789' } };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        set: jest.fn()
      };
      const next = jest.fn();

      await middleware(req, res, next);

      expect(res.set).not.toHaveBeenCalled();
      expect(next).toHaveBeenCalled();
    });

    test('should pass authenticated requests through', async () => {
      const middleware = adminSecurity.requireAdmin(false);

      const req = { auth: { uid: 'admin_legit', token: { email: 'admin@celestia.com' } } };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        set: jest.fn()
      };
      const next = jest.fn();

      await middleware(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });
  });

  describe('Rate Limiter Integration', () => {
    test('should enforce different limits for different operations', async () => {
      const adminId = 'admin_multi_op';

      // Login limiter: 5 attempts
      for (let i = 0; i < 5; i++) {
        const result = await adminSecurity.checkAdminLoginRateLimit('ip_' + adminId);
        expect(result.allowed).toBe(true);
      }
      const loginBlocked = await adminSecurity.checkAdminLoginRateLimit('ip_' + adminId);
      expect(loginBlocked.allowed).toBe(false);

      // Action limiter: 100 actions (different limit)
      for (let i = 0; i < 100; i++) {
        const result = await adminSecurity.checkAdminActionRateLimit(adminId);
        expect(result.allowed).toBe(true);
      }
      const actionBlocked = await adminSecurity.checkAdminActionRateLimit(adminId);
      expect(actionBlocked.allowed).toBe(false);

      // Bulk limiter: 10 operations (different limit)
      for (let i = 0; i < 10; i++) {
        const result = await adminSecurity.checkBulkOperationRateLimit(adminId);
        expect(result.allowed).toBe(true);
      }
      const bulkBlocked = await adminSecurity.checkBulkOperationRateLimit(adminId);
      expect(bulkBlocked.allowed).toBe(false);
    });

    test('should provide accurate remaining count', async () => {
      const adminId = 'admin_remaining_test';

      const result1 = await adminSecurity.checkAdminActionRateLimit(adminId);
      const result2 = await adminSecurity.checkAdminActionRateLimit(adminId);
      const result3 = await adminSecurity.checkAdminActionRateLimit(adminId);

      expect(result1.remaining).toBeGreaterThan(result2.remaining);
      expect(result2.remaining).toBeGreaterThan(result3.remaining);
    });
  });

  describe('Security Edge Cases', () => {
    test('should handle rapid sequential requests', async () => {
      const adminId = 'admin_rapid_sequential';

      const promises = [];
      for (let i = 0; i < 10; i++) {
        promises.push(adminSecurity.checkAdminActionRateLimit(adminId));
      }

      const results = await Promise.all(promises);

      // All should be allowed (under the 100 limit)
      results.forEach(result => {
        expect(result.allowed).toBe(true);
      });
    });

    test('should handle concurrent requests correctly', async () => {
      const adminId = 'admin_concurrent';

      // Fire 5 concurrent requests
      const results = await Promise.all([
        adminSecurity.checkAdminActionRateLimit(adminId),
        adminSecurity.checkAdminActionRateLimit(adminId),
        adminSecurity.checkAdminActionRateLimit(adminId),
        adminSecurity.checkAdminActionRateLimit(adminId),
        adminSecurity.checkAdminActionRateLimit(adminId)
      ]);

      // All should complete successfully
      expect(results).toHaveLength(5);
      results.forEach(result => {
        expect(result.allowed).toBeDefined();
      });
    });

    test('should handle empty/null identifiers gracefully', async () => {
      // These should not crash the system
      await expect(adminSecurity.checkAdminLoginRateLimit('')).resolves.toBeDefined();
      await expect(adminSecurity.checkAdminActionRateLimit('')).resolves.toBeDefined();
      await expect(adminSecurity.checkBulkOperationRateLimit('')).resolves.toBeDefined();
    });
  });
});
