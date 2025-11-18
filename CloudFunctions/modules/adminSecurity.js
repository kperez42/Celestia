/**
 * Admin Security Module
 * Rate limiting and security controls for admin endpoints
 */

const { RateLimiterMemory } = require('rate-limiter-flexible');
const functions = require('firebase-functions');

// Rate limiters for different admin operations
const adminLoginLimiter = new RateLimiterMemory({
  points: 5, // 5 login attempts
  duration: 900, // per 15 minutes (900 seconds)
  blockDuration: 3600 // block for 1 hour if exceeded
});

const adminActionLimiter = new RateLimiterMemory({
  points: 100, // 100 admin actions
  duration: 60, // per minute
  blockDuration: 300 // block for 5 minutes if exceeded
});

const adminBulkOperationLimiter = new RateLimiterMemory({
  points: 10, // 10 bulk operations
  duration: 3600, // per hour
  blockDuration: 1800 // block for 30 minutes if exceeded
});

/**
 * Check rate limit for admin login attempts
 * @param {string} identifier - IP address or user ID
 * @returns {Promise<boolean>} True if allowed, false if rate limited
 */
async function checkAdminLoginRateLimit(identifier) {
  try {
    await adminLoginLimiter.consume(identifier);
    return { allowed: true, remaining: await adminLoginLimiter.get(identifier) };
  } catch (err) {
    functions.logger.warn('Admin login rate limit exceeded', { identifier });
    return {
      allowed: false,
      retryAfter: Math.round(err.msBeforeNext / 1000),
      message: 'Too many login attempts. Please try again later.'
    };
  }
}

/**
 * Check rate limit for general admin actions
 * @param {string} adminId - Admin user ID
 * @returns {Promise<boolean>} True if allowed, false if rate limited
 */
async function checkAdminActionRateLimit(adminId) {
  try {
    await adminActionLimiter.consume(adminId);
    const remaining = await adminActionLimiter.get(adminId);
    return {
      allowed: true,
      remaining: remaining ? remaining.remainingPoints : 100
    };
  } catch (err) {
    functions.logger.warn('Admin action rate limit exceeded', { adminId });
    return {
      allowed: false,
      retryAfter: Math.round(err.msBeforeNext / 1000),
      message: 'Rate limit exceeded. Please slow down.'
    };
  }
}

/**
 * Check rate limit for bulk operations
 * @param {string} adminId - Admin user ID
 * @returns {Promise<boolean>} True if allowed, false if rate limited
 */
async function checkBulkOperationRateLimit(adminId) {
  try {
    await adminBulkOperationLimiter.consume(adminId);
    return { allowed: true };
  } catch (err) {
    functions.logger.warn('Bulk operation rate limit exceeded', { adminId });
    return {
      allowed: false,
      retryAfter: Math.round(err.msBeforeNext / 1000),
      message: 'Bulk operation limit exceeded. Please wait before trying again.'
    };
  }
}

/**
 * Middleware to check admin authentication and rate limit
 * @param {boolean} checkRateLimit - Whether to check rate limits
 */
function requireAdmin(checkRateLimit = true) {
  return async (req, res, next) => {
    // Check authentication
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized - Authentication required' });
    }

    // Check if user is admin (you should implement this based on custom claims)
    // For now, we'll assume anyone authenticated can access admin
    // TODO: Implement proper admin role checking
    // if (!req.auth.token.admin) {
    //   return res.status(403).json({ error: 'Forbidden - Admin access required' });
    // }

    // Check rate limit if enabled
    if (checkRateLimit) {
      const result = await checkAdminActionRateLimit(req.auth.uid);
      if (!result.allowed) {
        return res.status(429).json({
          error: result.message,
          retryAfter: result.retryAfter
        });
      }

      // Add remaining quota to response headers
      res.set('X-RateLimit-Remaining', result.remaining.toString());
    }

    next();
  };
}

module.exports = {
  checkAdminLoginRateLimit,
  checkAdminActionRateLimit,
  checkBulkOperationRateLimit,
  requireAdmin
};
