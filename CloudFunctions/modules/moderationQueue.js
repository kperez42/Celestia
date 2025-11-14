/**
 * Moderation Queue Module
 * Real-time content moderation with intelligent prioritization
 *
 * Features:
 * - Priority-based queue management
 * - Auto-assignment to moderators
 * - Real-time updates
 * - SLA tracking
 * - Workload balancing
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// ============================================================================
// PRIORITY CALCULATION
// ============================================================================

/**
 * Calculates priority score for moderation item
 * Higher score = higher priority
 *
 * Factors:
 * - Severity (critical, high, medium, low)
 * - User history (repeat offenders)
 * - Report count (multiple reports)
 * - Time in queue (SLA)
 * - Content type (photos vs text)
 *
 * @param {object} item - Moderation item
 * @returns {number} Priority score (0-100)
 */
function calculatePriority(item) {
  let score = 0;

  // Severity weight (40 points)
  const severityScores = {
    'critical': 40,
    'high': 30,
    'medium': 20,
    'low': 10
  };
  score += severityScores[item.severity] || 10;

  // User history weight (20 points)
  const warningCount = item.userWarningCount || 0;
  if (warningCount >= 3) {
    score += 20;
  } else if (warningCount >= 2) {
    score += 15;
  } else if (warningCount >= 1) {
    score += 10;
  }

  // Report count weight (20 points)
  const reportCount = item.reportCount || 1;
  if (reportCount >= 10) {
    score += 20;
  } else if (reportCount >= 5) {
    score += 15;
  } else if (reportCount >= 3) {
    score += 10;
  } else if (reportCount >= 2) {
    score += 5;
  }

  // Time in queue weight (15 points)
  const hoursInQueue = item.hoursInQueue || 0;
  if (hoursInQueue >= 24) {
    score += 15; // SLA breach
  } else if (hoursInQueue >= 12) {
    score += 10;
  } else if (hoursInQueue >= 6) {
    score += 5;
  }

  // Content type weight (5 points)
  if (item.contentType === 'photo') {
    score += 5; // Photos are higher priority
  }

  return Math.min(score, 100);
}

/**
 * Determines priority level from score
 * @param {number} score - Priority score
 * @returns {string} Priority level
 */
function getPriorityLevel(score) {
  if (score >= 75) return 'critical';
  if (score >= 50) return 'high';
  if (score >= 25) return 'medium';
  return 'low';
}

// ============================================================================
// QUEUE MANAGEMENT
// ============================================================================

/**
 * Gets prioritized moderation queue
 * @param {object} options - Query options
 * @returns {array} Prioritized moderation items
 */
async function getQueue(options = {}) {
  const db = admin.firestore();
  const {
    limit = 50,
    status = 'pending', // pending, in_progress, completed
    assignedTo = null,
    priorityLevel = null
  } = options;

  try {
    let query = db.collection('moderation_queue')
      .where('status', '==', status);

    if (assignedTo) {
      query = query.where('assignedTo', '==', assignedTo);
    }

    if (priorityLevel) {
      query = query.where('priorityLevel', '==', priorityLevel);
    }

    const snapshot = await query.get();

    // Enrich items with user data and calculate priorities
    const items = await Promise.all(snapshot.docs.map(async (doc) => {
      const data = doc.data();

      // Get user info
      const userDoc = await db.collection('users').doc(data.userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      // Get user warning count
      const warningsSnapshot = await db.collection('user_warnings')
        .where('userId', '==', data.userId)
        .get();

      const hoursInQueue = data.timestamp
        ? (Date.now() - data.timestamp.toDate().getTime()) / (1000 * 60 * 60)
        : 0;

      const itemWithMeta = {
        ...data,
        userWarningCount: warningsSnapshot.size,
        hoursInQueue
      };

      const priorityScore = calculatePriority(itemWithMeta);

      return {
        id: doc.id,
        ...data,
        user: {
          id: data.userId,
          fullName: userData.fullName || 'Unknown',
          email: userData.email || 'Unknown',
          warningCount: warningsSnapshot.size,
          suspended: userData.suspended || false
        },
        priorityScore,
        priorityLevel: getPriorityLevel(priorityScore),
        hoursInQueue: hoursInQueue.toFixed(1),
        timestamp: data.timestamp?.toDate().toISOString()
      };
    }));

    // Sort by priority score (highest first)
    items.sort((a, b) => b.priorityScore - a.priorityScore);

    return items.slice(0, limit);

  } catch (error) {
    functions.logger.error('Get queue error', { error: error.message });
    throw error;
  }
}

/**
 * Adds item to moderation queue
 * @param {object} item - Moderation item
 * @returns {string} Queue item ID
 */
async function addToQueue(item) {
  const db = admin.firestore();

  try {
    const queueItem = {
      userId: item.userId,
      contentId: item.contentId,
      contentType: item.contentType, // 'photo', 'text', 'profile', 'message'
      contentUrl: item.contentUrl || null,
      contentText: item.contentText || null,
      reason: item.reason,
      severity: item.severity || 'medium',
      reportCount: item.reportCount || 1,
      reportedBy: item.reportedBy || [],
      status: 'pending',
      assignedTo: null,
      assignedAt: null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      slaDeadline: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      metadata: item.metadata || {}
    };

    const docRef = await db.collection('moderation_queue').add(queueItem);

    functions.logger.info('Item added to moderation queue', {
      queueItemId: docRef.id,
      userId: item.userId,
      severity: item.severity
    });

    return docRef.id;

  } catch (error) {
    functions.logger.error('Add to queue error', { error: error.message });
    throw error;
  }
}

/**
 * Assigns queue item to moderator
 * @param {string} queueItemId - Queue item ID
 * @param {string} moderatorId - Moderator user ID
 * @returns {object} Assignment result
 */
async function assignToModerator(queueItemId, moderatorId) {
  const db = admin.firestore();

  try {
    const queueRef = db.collection('moderation_queue').doc(queueItemId);
    const queueDoc = await queueRef.get();

    if (!queueDoc.exists) {
      throw new Error('Queue item not found');
    }

    const data = queueDoc.data();

    if (data.status !== 'pending') {
      throw new Error('Item is not available for assignment');
    }

    await queueRef.update({
      status: 'in_progress',
      assignedTo: moderatorId,
      assignedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    functions.logger.info('Queue item assigned', { queueItemId, moderatorId });

    return { success: true };

  } catch (error) {
    functions.logger.error('Assign to moderator error', { queueItemId, error: error.message });
    throw error;
  }
}

/**
 * Auto-assigns items to available moderators based on workload
 * @returns {object} Assignment results
 */
async function autoAssignItems() {
  const db = admin.firestore();

  try {
    // Get available moderators (users with isAdmin = true)
    const moderatorsSnapshot = await db.collection('users')
      .where('isAdmin', '==', true)
      .get();

    const moderators = moderatorsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    if (moderators.length === 0) {
      return { assigned: 0, message: 'No moderators available' };
    }

    // Get current workload for each moderator
    const workloads = await Promise.all(moderators.map(async (mod) => {
      const assignedSnapshot = await db.collection('moderation_queue')
        .where('assignedTo', '==', mod.id)
        .where('status', '==', 'in_progress')
        .get();

      return {
        moderatorId: mod.id,
        currentWorkload: assignedSnapshot.size
      };
    }));

    // Sort by workload (least busy first)
    workloads.sort((a, b) => a.currentWorkload - b.currentWorkload);

    // Get pending items (highest priority first)
    const pendingItems = await getQueue({ status: 'pending', limit: 20 });

    let assigned = 0;

    for (const item of pendingItems) {
      // Assign to least busy moderator
      const leastBusy = workloads[0];

      if (leastBusy.currentWorkload < 10) { // Max 10 items per moderator
        await assignToModerator(item.id, leastBusy.moderatorId);
        leastBusy.currentWorkload++;
        assigned++;

        // Re-sort after assignment
        workloads.sort((a, b) => a.currentWorkload - b.currentWorkload);
      }
    }

    functions.logger.info('Auto-assignment completed', { assigned });

    return { assigned, total: pendingItems.length };

  } catch (error) {
    functions.logger.error('Auto-assign error', { error: error.message });
    throw error;
  }
}

/**
 * Completes moderation of queue item
 * @param {string} queueItemId - Queue item ID
 * @param {string} decision - 'approve' or 'reject'
 * @param {string} moderatorNote - Moderator's note
 * @param {string} moderatorId - Moderator user ID
 * @returns {object} Completion result
 */
async function completeModeration(queueItemId, decision, moderatorNote, moderatorId) {
  const db = admin.firestore();

  try {
    const queueRef = db.collection('moderation_queue').doc(queueItemId);
    const queueDoc = await queueRef.get();

    if (!queueDoc.exists) {
      throw new Error('Queue item not found');
    }

    const data = queueDoc.data();

    // Update queue item
    await queueRef.update({
      status: 'completed',
      decision,
      moderatorNote,
      completedBy: moderatorId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      timeToComplete: data.assignedAt
        ? Date.now() - data.assignedAt.toDate().getTime()
        : null
    });

    // Take action based on decision
    if (decision === 'reject') {
      // Content is inappropriate
      if (data.contentType === 'photo' && data.contentUrl) {
        // Remove photo
        const contentModeration = require('./contentModeration');
        await contentModeration.removePhoto(data.contentUrl);

        // Remove from user's photos
        await db.collection('users').doc(data.userId).update({
          photos: admin.firestore.FieldValue.arrayRemove(data.contentUrl)
        });
      }

      // Issue warning
      await db.collection('user_warnings').add({
        userId: data.userId,
        reason: data.reason,
        queueItemId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        acknowledged: false
      });

      // Check if user should be suspended
      const warningsSnapshot = await db.collection('user_warnings')
        .where('userId', '==', data.userId)
        .where('acknowledged', '==', false)
        .get();

      if (warningsSnapshot.size >= 3) {
        await db.collection('users').doc(data.userId).update({
          suspended: true,
          suspensionReason: 'Multiple violations',
          suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
          suspensionExpiryDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
        });
      }
    }

    // Log the action
    const adminDashboard = require('./adminDashboard');
    await adminDashboard.logAdminAction(moderatorId, 'moderation_completed', {
      queueItemId,
      decision,
      userId: data.userId,
      contentType: data.contentType
    });

    functions.logger.info('Moderation completed', { queueItemId, decision, moderatorId });

    return { success: true };

  } catch (error) {
    functions.logger.error('Complete moderation error', { queueItemId, error: error.message });
    throw error;
  }
}

/**
 * Gets queue statistics and metrics
 * @returns {object} Queue statistics
 */
async function getQueueStats() {
  const db = admin.firestore();

  try {
    // Get all queue items
    const allItemsSnapshot = await db.collection('moderation_queue').get();
    const allItems = allItemsSnapshot.docs.map(doc => doc.data());

    // Status breakdown
    const pending = allItems.filter(i => i.status === 'pending').length;
    const inProgress = allItems.filter(i => i.status === 'in_progress').length;
    const completed = allItems.filter(i => i.status === 'completed').length;

    // Priority breakdown (pending items)
    const pendingItems = allItems.filter(i => i.status === 'pending');
    const priorityCounts = {
      critical: 0,
      high: 0,
      medium: 0,
      low: 0
    };

    pendingItems.forEach(item => {
      const hoursInQueue = item.timestamp
        ? (Date.now() - item.timestamp.toDate().getTime()) / (1000 * 60 * 60)
        : 0;

      const itemWithMeta = { ...item, hoursInQueue };
      const score = calculatePriority(itemWithMeta);
      const level = getPriorityLevel(score);

      priorityCounts[level]++;
    });

    // SLA metrics
    const now = Date.now();
    const slaBreached = pendingItems.filter(item => {
      return item.slaDeadline && item.slaDeadline.toDate() < now;
    }).length;

    const approaching = pendingItems.filter(item => {
      if (!item.slaDeadline) return false;
      const hoursUntilDeadline = (item.slaDeadline.toDate() - now) / (1000 * 60 * 60);
      return hoursUntilDeadline < 6 && hoursUntilDeadline > 0;
    }).length;

    // Average completion time (last 100 completed items)
    const completedItems = allItems
      .filter(i => i.status === 'completed' && i.timeToComplete)
      .slice(-100);

    const avgCompletionTime = completedItems.length > 0
      ? completedItems.reduce((sum, i) => sum + i.timeToComplete, 0) / completedItems.length / (1000 * 60)
      : 0;

    // Content type breakdown
    const contentTypes = {};
    pendingItems.forEach(item => {
      contentTypes[item.contentType] = (contentTypes[item.contentType] || 0) + 1;
    });

    return {
      total: allItems.length,
      status: {
        pending,
        inProgress,
        completed
      },
      priority: priorityCounts,
      sla: {
        breached: slaBreached,
        approachingDeadline: approaching,
        averageCompletionTimeMinutes: avgCompletionTime.toFixed(1)
      },
      contentTypes,
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    functions.logger.error('Get queue stats error', { error: error.message });
    throw error;
  }
}

/**
 * Escalates high-priority items that have been in queue too long
 * @returns {object} Escalation results
 */
async function escalateStaleItems() {
  const db = admin.firestore();

  try {
    const now = Date.now();
    const twelveHoursAgo = new Date(now - 12 * 60 * 60 * 1000);

    // Find pending items older than 12 hours
    const staleItemsSnapshot = await db.collection('moderation_queue')
      .where('status', '==', 'pending')
      .where('timestamp', '<', twelveHoursAgo)
      .get();

    let escalated = 0;

    for (const doc of staleItemsSnapshot.docs) {
      const data = doc.data();

      // Escalate severity
      let newSeverity = data.severity;
      if (data.severity === 'low') newSeverity = 'medium';
      else if (data.severity === 'medium') newSeverity = 'high';
      else if (data.severity === 'high') newSeverity = 'critical';

      if (newSeverity !== data.severity) {
        await doc.ref.update({
          severity: newSeverity,
          escalated: true,
          escalatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        escalated++;

        functions.logger.warn('Queue item escalated', {
          queueItemId: doc.id,
          oldSeverity: data.severity,
          newSeverity
        });
      }
    }

    return { escalated, total: staleItemsSnapshot.size };

  } catch (error) {
    functions.logger.error('Escalate stale items error', { error: error.message });
    throw error;
  }
}

module.exports = {
  getQueue,
  addToQueue,
  assignToModerator,
  autoAssignItems,
  completeModeration,
  getQueueStats,
  escalateStaleItems,
  calculatePriority,
  getPriorityLevel
};
