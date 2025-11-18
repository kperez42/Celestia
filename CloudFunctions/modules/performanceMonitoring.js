/**
 * Performance Monitoring Module
 * Tracks API response times, slow queries, and system metrics
 * Provides admin dashboard with performance analytics
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

const db = admin.firestore();

// Performance thresholds (milliseconds)
const THRESHOLDS = {
  FAST_API: 200,
  ACCEPTABLE_API: 1000,
  SLOW_API: 2000,
  VERY_SLOW_API: 5000,
  SLOW_QUERY: 500,
  VERY_SLOW_QUERY: 1000
};

/**
 * Middleware to track API performance
 * Wraps CloudFunctions and logs execution time
 */
class PerformanceTracker {
  constructor() {
    this.activeTraces = new Map();
  }

  /**
   * Start tracking an API call
   * @param {string} functionName - Function being called
   * @param {object} context - Call context (userId, etc.)
   * @returns {string} Trace ID
   */
  startTrace(functionName, context = {}) {
    const traceId = `${functionName}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    this.activeTraces.set(traceId, {
      functionName,
      context,
      startTime: Date.now(),
      startTimestamp: new Date()
    });

    return traceId;
  }

  /**
   * End tracking and log performance
   * @param {string} traceId - Trace ID from startTrace
   * @param {boolean} success - Was the call successful
   * @param {string} error - Error message if failed
   */
  async endTrace(traceId, success = true, error = null) {
    const trace = this.activeTraces.get(traceId);

    if (!trace) {
      functions.logger.warning(`Trace ${traceId} not found`);
      return;
    }

    const duration = Date.now() - trace.startTime;
    const performanceLevel = this.classifyPerformance(duration);

    // Log performance
    if (duration > THRESHOLDS.SLOW_API) {
      functions.logger.warning(`⏱️ SLOW API: ${trace.functionName} took ${duration}ms`, {
        functionName: trace.functionName,
        duration,
        success,
        userId: trace.context.userId,
        error
      });
    } else {
      functions.logger.debug(`⏱️ ${trace.functionName} took ${duration}ms`, {
        functionName: trace.functionName,
        duration,
        success
      });
    }

    // Store performance metric
    await this.recordPerformance({
      functionName: trace.functionName,
      duration,
      success,
      error,
      performanceLevel,
      userId: trace.context.userId,
      timestamp: trace.startTimestamp
    });

    this.activeTraces.delete(traceId);
  }

  /**
   * Classify performance level
   * @param {number} duration - Duration in milliseconds
   * @returns {string} Performance level
   */
  classifyPerformance(duration) {
    if (duration < THRESHOLDS.FAST_API) return 'fast';
    if (duration < THRESHOLDS.ACCEPTABLE_API) return 'acceptable';
    if (duration < THRESHOLDS.SLOW_API) return 'slow';
    if (duration < THRESHOLDS.VERY_SLOW_API) return 'very_slow';
    return 'critical';
  }

  /**
   * Record performance metric to Firestore
   * @param {object} metric - Performance metric
   */
  async recordPerformance(metric) {
    try {
      // Only store slow operations to save costs
      if (metric.duration > THRESHOLDS.ACCEPTABLE_API) {
        await db.collection('performance_logs').add({
          ...metric,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // Update aggregated stats
      await this.updateAggregatedStats(metric);
    } catch (error) {
      functions.logger.error('Failed to record performance', { error: error.message });
    }
  }

  /**
   * Update aggregated performance statistics
   * @param {object} metric - Performance metric
   */
  async updateAggregatedStats(metric) {
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const statKey = `${metric.functionName}_${today}`;

    const statRef = db.collection('performance_stats').doc(statKey);

    try {
      await db.runTransaction(async (transaction) => {
        const statDoc = await transaction.get(statRef);

        if (!statDoc.exists) {
          // Create new stat
          transaction.set(statRef, {
            functionName: metric.functionName,
            date: today,
            callCount: 1,
            successCount: metric.success ? 1 : 0,
            failureCount: metric.success ? 0 : 1,
            totalDuration: metric.duration,
            minDuration: metric.duration,
            maxDuration: metric.duration,
            avgDuration: metric.duration,
            fastCount: metric.performanceLevel === 'fast' ? 1 : 0,
            acceptableCount: metric.performanceLevel === 'acceptable' ? 1 : 0,
            slowCount: metric.performanceLevel === 'slow' ? 1 : 0,
            verySlowCount: metric.performanceLevel === 'very_slow' ? 1 : 0,
            criticalCount: metric.performanceLevel === 'critical' ? 1 : 0,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          // Update existing stat
          const data = statDoc.data();
          const newCallCount = data.callCount + 1;
          const newTotalDuration = data.totalDuration + metric.duration;

          transaction.update(statRef, {
            callCount: newCallCount,
            successCount: data.successCount + (metric.success ? 1 : 0),
            failureCount: data.failureCount + (metric.success ? 0 : 1),
            totalDuration: newTotalDuration,
            minDuration: Math.min(data.minDuration, metric.duration),
            maxDuration: Math.max(data.maxDuration, metric.duration),
            avgDuration: newTotalDuration / newCallCount,
            fastCount: data.fastCount + (metric.performanceLevel === 'fast' ? 1 : 0),
            acceptableCount: data.acceptableCount + (metric.performanceLevel === 'acceptable' ? 1 : 0),
            slowCount: data.slowCount + (metric.performanceLevel === 'slow' ? 1 : 0),
            verySlowCount: data.verySlowCount + (metric.performanceLevel === 'very_slow' ? 1 : 0),
            criticalCount: data.criticalCount + (metric.performanceLevel === 'critical' ? 1 : 0),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });
    } catch (error) {
      functions.logger.error('Failed to update aggregated stats', { error: error.message });
    }
  }
}

// Global tracker instance
const tracker = new PerformanceTracker();

/**
 * Track Firestore query performance
 * @param {string} collection - Collection name
 * @param {string} operation - Operation type (get, list, query)
 * @param {number} duration - Query duration in ms
 * @param {number} resultCount - Number of documents returned
 */
async function trackQuery(collection, operation, duration, resultCount = 0) {
  const performanceLevel = duration < THRESHOLDS.SLOW_QUERY ? 'fast' :
                          duration < THRESHOLDS.VERY_SLOW_QUERY ? 'slow' : 'very_slow';

  if (duration > THRESHOLDS.SLOW_QUERY) {
    functions.logger.warning(`🐌 SLOW QUERY: ${collection}.${operation} took ${duration}ms (${resultCount} docs)`, {
      collection,
      operation,
      duration,
      resultCount,
      performanceLevel
    });

    // Store slow query
    await db.collection('slow_queries').add({
      collection,
      operation,
      duration,
      resultCount,
      performanceLevel,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  // Update query stats
  await updateQueryStats(collection, operation, duration, resultCount);
}

/**
 * Update aggregated query statistics
 */
async function updateQueryStats(collection, operation, duration, resultCount) {
  const today = new Date().toISOString().split('T')[0];
  const statKey = `${collection}_${operation}_${today}`;

  const statRef = db.collection('query_stats').doc(statKey);

  try {
    await db.runTransaction(async (transaction) => {
      const statDoc = await transaction.get(statRef);

      if (!statDoc.exists) {
        transaction.set(statRef, {
          collection,
          operation,
          date: today,
          queryCount: 1,
          totalDuration: duration,
          avgDuration: duration,
          minDuration: duration,
          maxDuration: duration,
          totalResults: resultCount,
          avgResults: resultCount,
          slowCount: duration > THRESHOLDS.SLOW_QUERY ? 1 : 0,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
      } else {
        const data = statDoc.data();
        const newQueryCount = data.queryCount + 1;
        const newTotalDuration = data.totalDuration + duration;
        const newTotalResults = data.totalResults + resultCount;

        transaction.update(statRef, {
          queryCount: newQueryCount,
          totalDuration: newTotalDuration,
          avgDuration: newTotalDuration / newQueryCount,
          minDuration: Math.min(data.minDuration, duration),
          maxDuration: Math.max(data.maxDuration, duration),
          totalResults: newTotalResults,
          avgResults: newTotalResults / newQueryCount,
          slowCount: data.slowCount + (duration > THRESHOLDS.SLOW_QUERY ? 1 : 0),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    });
  } catch (error) {
    functions.logger.error('Failed to update query stats', { error: error.message });
  }
}

/**
 * Get performance dashboard data
 * @param {number} days - Number of days to analyze
 * @returns {object} Performance dashboard data
 */
async function getPerformanceDashboard(days = 7) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const startDateStr = startDate.toISOString().split('T')[0];

  // Get API performance stats
  const apiStatsSnapshot = await db.collection('performance_stats')
    .where('date', '>=', startDateStr)
    .orderBy('date', 'desc')
    .get();

  // Get query performance stats
  const queryStatsSnapshot = await db.collection('query_stats')
    .where('date', '>=', startDateStr)
    .orderBy('date', 'desc')
    .get();

  // Get slow queries
  const slowQueriesSnapshot = await db.collection('slow_queries')
    .where('timestamp', '>', startDate)
    .orderBy('timestamp', 'desc')
    .limit(50)
    .get();

  // Aggregate API stats
  const apiStats = aggregateApiStats(apiStatsSnapshot.docs.map(doc => doc.data()));

  // Aggregate query stats
  const queryStats = aggregateQueryStats(queryStatsSnapshot.docs.map(doc => doc.data()));

  // Format slow queries
  const slowQueries = slowQueriesSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));

  return {
    summary: {
      totalApiCalls: apiStats.totalCalls,
      avgApiResponseTime: apiStats.avgDuration,
      apiSuccessRate: apiStats.successRate,
      totalQueries: queryStats.totalQueries,
      avgQueryTime: queryStats.avgDuration,
      slowQueryCount: queryStats.slowCount
    },
    apiPerformance: apiStats.byFunction,
    queryPerformance: queryStats.byCollection,
    slowQueries: slowQueries,
    performanceBreakdown: {
      fast: apiStats.fastCount,
      acceptable: apiStats.acceptableCount,
      slow: apiStats.slowCount,
      verySlow: apiStats.verySlowCount,
      critical: apiStats.criticalCount
    },
    recommendations: generateRecommendations(apiStats, queryStats, slowQueries)
  };
}

/**
 * Aggregate API statistics
 */
function aggregateApiStats(stats) {
  const byFunction = {};
  let totalCalls = 0;
  let totalDuration = 0;
  let totalSuccess = 0;
  let totalFailure = 0;
  let fastCount = 0;
  let acceptableCount = 0;
  let slowCount = 0;
  let verySlowCount = 0;
  let criticalCount = 0;

  stats.forEach(stat => {
    // Aggregate by function
    if (!byFunction[stat.functionName]) {
      byFunction[stat.functionName] = {
        callCount: 0,
        avgDuration: 0,
        successRate: 0,
        slowCount: 0
      };
    }

    byFunction[stat.functionName].callCount += stat.callCount;
    byFunction[stat.functionName].avgDuration =
      (byFunction[stat.functionName].avgDuration * byFunction[stat.functionName].callCount +
       stat.avgDuration * stat.callCount) /
      (byFunction[stat.functionName].callCount + stat.callCount);
    byFunction[stat.functionName].successRate =
      ((byFunction[stat.functionName].successRate * byFunction[stat.functionName].callCount +
        (stat.successCount / stat.callCount) * 100 * stat.callCount) /
       (byFunction[stat.functionName].callCount + stat.callCount));
    byFunction[stat.functionName].slowCount += stat.slowCount + stat.verySlowCount + stat.criticalCount;

    // Aggregate totals
    totalCalls += stat.callCount;
    totalDuration += stat.totalDuration;
    totalSuccess += stat.successCount;
    totalFailure += stat.failureCount;
    fastCount += stat.fastCount;
    acceptableCount += stat.acceptableCount;
    slowCount += stat.slowCount;
    verySlowCount += stat.verySlowCount;
    criticalCount += stat.criticalCount;
  });

  return {
    byFunction,
    totalCalls,
    avgDuration: totalCalls > 0 ? totalDuration / totalCalls : 0,
    successRate: totalCalls > 0 ? (totalSuccess / totalCalls) * 100 : 0,
    fastCount,
    acceptableCount,
    slowCount,
    verySlowCount,
    criticalCount
  };
}

/**
 * Aggregate query statistics
 */
function aggregateQueryStats(stats) {
  const byCollection = {};
  let totalQueries = 0;
  let totalDuration = 0;
  let slowCount = 0;

  stats.forEach(stat => {
    // Aggregate by collection
    if (!byCollection[stat.collection]) {
      byCollection[stat.collection] = {
        queryCount: 0,
        avgDuration: 0,
        avgResults: 0,
        slowCount: 0
      };
    }

    byCollection[stat.collection].queryCount += stat.queryCount;
    byCollection[stat.collection].avgDuration =
      (byCollection[stat.collection].avgDuration * byCollection[stat.collection].queryCount +
       stat.avgDuration * stat.queryCount) /
      (byCollection[stat.collection].queryCount + stat.queryCount);
    byCollection[stat.collection].avgResults =
      (byCollection[stat.collection].avgResults * byCollection[stat.collection].queryCount +
       stat.avgResults * stat.queryCount) /
      (byCollection[stat.collection].queryCount + stat.queryCount);
    byCollection[stat.collection].slowCount += stat.slowCount;

    // Aggregate totals
    totalQueries += stat.queryCount;
    totalDuration += stat.totalDuration;
    slowCount += stat.slowCount;
  });

  return {
    byCollection,
    totalQueries,
    avgDuration: totalQueries > 0 ? totalDuration / totalQueries : 0,
    slowCount
  };
}

/**
 * Generate performance recommendations
 */
function generateRecommendations(apiStats, queryStats, slowQueries) {
  const recommendations = [];

  // Check API performance
  if (apiStats.avgDuration > THRESHOLDS.ACCEPTABLE_API) {
    recommendations.push({
      type: 'api_performance',
      severity: 'high',
      message: `Average API response time (${Math.round(apiStats.avgDuration)}ms) exceeds threshold (${THRESHOLDS.ACCEPTABLE_API}ms)`,
      suggestion: 'Review slow functions and optimize database queries'
    });
  }

  if (apiStats.successRate < 95) {
    recommendations.push({
      type: 'api_reliability',
      severity: 'critical',
      message: `API success rate (${apiStats.successRate.toFixed(2)}%) is below 95%`,
      suggestion: 'Investigate error logs and add retry logic for transient failures'
    });
  }

  // Check query performance
  if (queryStats.slowCount > 100) {
    recommendations.push({
      type: 'slow_queries',
      severity: 'high',
      message: `${queryStats.slowCount} slow queries detected in the last 7 days`,
      suggestion: 'Add composite indexes for frequently slow queries'
    });
  }

  // Identify specific slow functions
  for (const [functionName, stats] of Object.entries(apiStats.byFunction)) {
    if (stats.avgDuration > THRESHOLDS.SLOW_API) {
      recommendations.push({
        type: 'slow_function',
        severity: 'medium',
        message: `Function ${functionName} has high average response time (${Math.round(stats.avgDuration)}ms)`,
        suggestion: 'Profile this function and optimize database queries or external API calls'
      });
    }
  }

  // Identify slow collections
  for (const [collection, stats] of Object.entries(queryStats.byCollection)) {
    if (stats.avgDuration > THRESHOLDS.SLOW_QUERY) {
      recommendations.push({
        type: 'slow_collection',
        severity: 'medium',
        message: `Collection ${collection} has slow average query time (${Math.round(stats.avgDuration)}ms)`,
        suggestion: 'Add indexes for this collection or reduce query complexity'
      });
    }
  }

  return recommendations;
}

module.exports = {
  PerformanceTracker,
  tracker,
  trackQuery,
  getPerformanceDashboard,
  THRESHOLDS
};
