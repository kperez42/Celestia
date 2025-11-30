/**
 * Rate Limiting Module
 * Prevents abuse by limiting actions per user
 */

const { RateLimiterMemory } = require('rate-limiter-flexible');
const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Try to load RateLimiterFirestore (may not be available in all versions)
let RateLimiterFirestore = null;
try {
  RateLimiterFirestore = require('rate-limiter-flexible').RateLimiterFirestore;
} catch (e) {
  console.log('RateLimiterFirestore not available, using memory-only rate limiting');
}

// Rate limit configurations for different actions
const RATE_LIMITS = {
  // Swipe actions (free users)
  swipe_free: {
    points: 50, // 50 swipes
    duration: 24 * 60 * 60, // per day
    blockDuration: 24 * 60 * 60 // block for 24 hours
  },
  // Swipe actions (premium users - unlimited)
  swipe_premium: {
    points: 999999,
    duration: 24 * 60 * 60,
    blockDuration: 0
  },
  // Messages
  message: {
    points: 100, // 100 messages
    duration: 60 * 60, // per hour
    blockDuration: 60 * 60 // block for 1 hour
  },
  // Super likes (free users)
  super_like_free: {
    points: 1, // 1 super like
    duration: 24 * 60 * 60, // per day
    blockDuration: 24 * 60 * 60
  },
  // Reports
  report: {
    points: 5, // 5 reports
    duration: 24 * 60 * 60, // per day
    blockDuration: 24 * 60 * 60
  },
  // Profile updates
  profile_update: {
    points: 10, // 10 updates
    duration: 60 * 60, // per hour
    blockDuration: 60 * 60
  },
  // Photo uploads
  photo_upload: {
    points: 6, // 6 photos (max allowed)
    duration: 60 * 60, // per hour
    blockDuration: 2 * 60 * 60 // block for 2 hours
  },
  // Account creation (by IP)
  account_creation: {
    points: 3, // 3 accounts
    duration: 24 * 60 * 60, // per day
    blockDuration: 7 * 24 * 60 * 60 // block for 7 days
  }
};

// In-memory rate limiters (for development)
const memoryLimiters = {};

// Firestore rate limiters (for production)
const firestoreLimiters = {};

/**
 * Initializes rate limiters
 */
function initializeLimiters() {
  const db = admin.firestore();

  for (const [actionType, config] of Object.entries(RATE_LIMITS)) {
    // Memory limiter (fast, but doesn't persist)
    memoryLimiters[actionType] = new RateLimiterMemory({
      points: config.points,
      duration: config.duration,
      blockDuration: config.blockDuration
    });

    // Firestore limiter (persists, works across instances) - only if available
    if (RateLimiterFirestore) {
      try {
        firestoreLimiters[actionType] = new RateLimiterFirestore({
          storeClient: db,
          storeType: 'firestore',
          dbName: 'rate_limits',
          tableName: actionType,
          points: config.points,
          duration: config.duration,
          blockDuration: config.blockDuration
        });
      } catch (err) {
        console.log(`Failed to create Firestore limiter for ${actionType}, using memory only`);
      }
    }
  }
}

/**
 * Checks if user can perform action
 * @param {string} userId - User ID or IP address
 * @param {string} actionType - Type of action
 * @returns {boolean} True if action is allowed
 */
async function checkRateLimit(userId, actionType) {
  try {
    // Get user's subscription status for swipe limits
    let effectiveActionType = actionType;
    if (actionType === 'swipe') {
      const isPremium = await isUserPremium(userId);
      effectiveActionType = isPremium ? 'swipe_premium' : 'swipe_free';
    }

    if (actionType === 'super_like') {
      const isPremium = await isUserPremium(userId);
      if (isPremium) {
        // Check consumables instead of rate limit
        return await hasConsumables(userId, 'superLikesRemaining');
      }
      effectiveActionType = 'super_like_free';
    }

    const limiter = getLimiter(effectiveActionType);

    if (!limiter) {
      functions.logger.warn('Unknown action type for rate limiting', { actionType });
      return true; // Allow if unknown
    }

    // Try to consume a point
    try {
      await limiter.consume(userId, 1);
      return true;
    } catch (rejRes) {
      // Rate limit exceeded
      functions.logger.info('Rate limit exceeded', {
        userId,
        actionType: effectiveActionType,
        remainingPoints: rejRes.remainingPoints,
        msBeforeNext: rejRes.msBeforeNext
      });
      return false;
    }

  } catch (error) {
    functions.logger.error('Rate limit check error', { userId, actionType, error: error.message });
    // Allow action if rate limiting fails
    return true;
  }
}

/**
 * Records an action (consumes a rate limit point)
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 */
async function recordAction(userId, actionType) {
  const limiter = getLimiter(actionType);

  if (limiter) {
    try {
      await limiter.consume(userId, 1);

      // Log the action
      await admin.firestore().collection('action_logs').add({
        userId,
        actionType,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

    } catch (error) {
      functions.logger.error('Action recording error', { userId, actionType, error: error.message });
    }
  }
}

/**
 * Gets remaining quota for user
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 * @returns {number} Remaining points
 */
async function getRemainingQuota(userId, actionType) {
  const limiter = getLimiter(actionType);

  if (!limiter) {
    return -1; // Unlimited
  }

  try {
    const rateLimiterRes = await limiter.get(userId);

    if (rateLimiterRes === null) {
      // No consumption yet
      return RATE_LIMITS[actionType].points;
    }

    return rateLimiterRes.remainingPoints;

  } catch (error) {
    functions.logger.error('Get quota error', { userId, actionType, error: error.message });
    return 0;
  }
}

/**
 * Resets rate limit for user (admin function)
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 */
async function resetRateLimit(userId, actionType) {
  const limiter = getLimiter(actionType);

  if (limiter) {
    try {
      await limiter.delete(userId);
      functions.logger.info('Rate limit reset', { userId, actionType });
    } catch (error) {
      functions.logger.error('Rate limit reset error', { userId, actionType, error: error.message });
    }
  }
}

/**
 * Gets rate limit configuration
 * @param {string} actionType - Type of action
 * @returns {object} Rate limit config
 */
function getLimits(actionType) {
  return RATE_LIMITS[actionType] || null;
}

/**
 * Penalizes user with extended block (for abuse)
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 * @param {number} multiplier - Block duration multiplier
 */
async function penalizeUser(userId, actionType, multiplier = 2) {
  const limiter = getLimiter(actionType);

  if (limiter) {
    try {
      const config = RATE_LIMITS[actionType];
      const blockDuration = config.blockDuration * multiplier;

      // Block user for extended period
      await limiter.block(userId, blockDuration);

      // Log penalty
      await admin.firestore().collection('user_penalties').add({
        userId,
        actionType,
        blockDuration,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.warn('User penalized', { userId, actionType, blockDuration });
    } catch (error) {
      functions.logger.error('Penalize user error', { userId, actionType, error: error.message });
    }
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getLimiter(actionType) {
  // Use Firestore limiter in production, memory limiter in development
  const useMemory = process.env.FUNCTIONS_EMULATOR === 'true';

  if (useMemory) {
    return memoryLimiters[actionType];
  }

  return firestoreLimiters[actionType];
}

async function isUserPremium(userId) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return false;
    }

    const userData = userDoc.data();
    return userData.isPremium === true;

  } catch (error) {
    functions.logger.error('Check premium status error', { userId, error: error.message });
    return false;
  }
}

async function hasConsumables(userId, consumableType) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return false;
    }

    const userData = userDoc.data();
    return (userData[consumableType] || 0) > 0;

  } catch (error) {
    functions.logger.error('Check consumables error', { userId, error: error.message });
    return false;
  }
}

// Initialize limiters on module load
initializeLimiters();

// ============================================================================
// VALIDATION ENDPOINTS (for backend validation from iOS app)
// ============================================================================

/**
 * Validates if action is allowed (for backend validation)
 * Called by iOS app before performing critical actions
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 * @returns {object} Validation result with remaining quota
 */
async function validateAction(userId, actionType) {
  try {
    // Check if action is allowed
    const isAllowed = await checkRateLimit(userId, actionType);

    if (!isAllowed) {
      const limits = getLimits(actionType);
      const remaining = await getRemainingQuota(userId, actionType);

      return {
        allowed: false,
        remaining: remaining,
        limit: limits.points,
        resetIn: limits.duration,
        reason: 'Rate limit exceeded'
      };
    }

    // Get remaining quota after consuming
    const remaining = await getRemainingQuota(userId, actionType);

    return {
      allowed: true,
      remaining: remaining,
      limit: RATE_LIMITS[actionType]?.points || -1
    };

  } catch (error) {
    functions.logger.error('Action validation error', { userId, actionType, error: error.message });

    // Fail open for availability, but log for monitoring
    return {
      allowed: true,
      remaining: -1,
      warning: 'Rate limit check failed - allowed by default'
    };
  }
}

/**
 * Batch validation for multiple actions (optimization)
 * @param {string} userId - User ID
 * @param {Array<string>} actionTypes - Array of action types
 * @returns {object} Validation results for all actions
 */
async function validateBatchActions(userId, actionTypes) {
  const results = {};

  for (const actionType of actionTypes) {
    results[actionType] = await validateAction(userId, actionType);
  }

  return results;
}

/**
 * Get user's current rate limit status for all actions
 * @param {string} userId - User ID
 * @returns {object} Status for all rate-limited actions
 */
async function getUserRateLimitStatus(userId) {
  const status = {};

  for (const actionType of Object.keys(RATE_LIMITS)) {
    const remaining = await getRemainingQuota(userId, actionType);
    const limits = getLimits(actionType);

    status[actionType] = {
      remaining,
      limit: limits.points,
      resetIn: limits.duration
    };
  }

  return status;
}

module.exports = {
  checkRateLimit,
  recordAction,
  getRemainingQuota,
  resetRateLimit,
  getLimits,
  penalizeUser,
  validateAction,
  validateBatchActions,
  getUserRateLimitStatus
};
