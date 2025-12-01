/**
 * Notifications Module
 * Handles FCM push notifications with rich content and custom sounds
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Sends a push notification via FCM
 * Configured for reliable delivery like Instagram - works when app is closed
 * @param {string} token - FCM token
 * @param {object} notification - Notification data
 * @returns {object} Result
 */
async function sendPushNotification(token, notification) {
  try {
    // Convert data values to strings (FCM requirement)
    const stringData = {};
    if (notification.data) {
      for (const [key, value] of Object.entries(notification.data)) {
        stringData[key] = String(value);
      }
    }

    const message = {
      token,
      // Notification payload - this shows the notification to user
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.imageUrl
      },
      // Data payload - for app handling
      data: stringData,
      // iOS (APNs) configuration - CRITICAL for background delivery
      apns: {
        headers: {
          'apns-priority': '10', // HIGH priority - delivers immediately
          'apns-push-type': 'alert', // Alert type shows notification
          'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400) // 24hr expiry
        },
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body
            },
            sound: notification.sound || 'default',
            badge: notification.badge || 1,
            category: notification.category || 'DEFAULT',
            'mutable-content': 1, // Enable rich notifications
            'content-available': 1 // CRITICAL: Wake app in background
          }
        },
        fcm_options: {
          image: notification.imageUrl
        }
      },
      // Android configuration
      android: {
        priority: 'high', // HIGH priority for immediate delivery
        ttl: 86400000, // 24 hour time-to-live
        notification: {
          sound: notification.sound || 'default',
          channelId: notification.channel || 'high_priority',
          priority: 'max', // Maximum priority
          defaultSound: true,
          defaultVibrateTimings: true,
          defaultLightSettings: true,
          imageUrl: notification.imageUrl,
          notificationCount: notification.badge || 1
        }
      },
      // Web push (optional)
      webpush: {
        headers: {
          Urgency: 'high'
        }
      }
    };

    const response = await admin.messaging().send(message);

    functions.logger.info('Push notification sent successfully', {
      token: token.substring(0, 20) + '...',
      messageId: response,
      title: notification.title
    });

    return {
      success: true,
      messageId: response
    };

  } catch (error) {
    functions.logger.error('Push notification failed', {
      error: error.message,
      errorCode: error.code,
      token: token.substring(0, 20) + '...'
    });

    // If token is invalid, we should clean it up
    if (error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token') {
      functions.logger.warn('Invalid FCM token detected - should be cleaned up');
    }

    throw error;
  }
}

/**
 * Sends a match notification
 * @param {string} userId - User to notify
 * @param {object} matchData - Match information
 */
async function sendMatchNotification(userId, matchData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  // Check if notifications are enabled
  if (!user.notificationsEnabled) {
    functions.logger.info('Notifications disabled for user', { userId });
    return;
  }

  const notification = {
    title: "It's a Match! 💕",
    body: `You and ${matchData.matchedUserName} liked each other!`,
    sound: 'match_sound.wav',
    badge: await getUnreadCount(userId),
    category: 'MATCH',
    imageUrl: matchData.matchedUserPhoto,
    data: {
      type: 'match',
      matchId: matchData.matchId,
      userId: matchData.matchedUserId,
      userName: matchData.matchedUserName
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'match',
    matchId: matchData.matchId,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });
}

/**
 * Sends a message notification
 * @param {string} userId - User to notify
 * @param {object} messageData - Message information
 */
async function sendMessageNotification(userId, messageData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken || !user.notificationsEnabled) {
    return;
  }

  const notification = {
    title: messageData.senderName,
    body: messageData.hasImage ? '📷 Sent a photo' : messageData.text,
    sound: 'default',
    badge: await getUnreadCount(userId),
    category: 'MESSAGE',
    imageUrl: messageData.imageUrl,
    data: {
      type: 'message',
      matchId: messageData.matchId,
      senderId: messageData.senderId,
      senderName: messageData.senderName,
      messageId: messageData.messageId
    }
  };

  await sendPushNotification(fcmToken, notification);

  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'message',
    matchId: messageData.matchId,
    messageId: messageData.messageId,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });
}

/**
 * Sends a like notification (premium users only)
 * @param {string} userId - User to notify
 * @param {object} likeData - Like information
 */
async function sendLikeNotification(userId, likeData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return;
  }

  const user = userDoc.data();

  // Only send to premium users
  if (!user.isPremium) {
    functions.logger.info('Like notification skipped - user not premium', { userId });
    return;
  }

  const fcmToken = user.fcmToken;

  if (!fcmToken || !user.notificationsEnabled) {
    return;
  }

  const isSuperLike = likeData.isSuperLike || false;

  const notification = {
    title: isSuperLike ? 'Someone Super Liked You! ⭐' : 'Someone Likes You! ❤️',
    body: `${likeData.likerName} ${isSuperLike ? 'super liked' : 'liked'} your profile`,
    sound: isSuperLike ? 'super_like_sound.wav' : 'default',
    badge: await getUnreadCount(userId),
    category: 'LIKE',
    imageUrl: likeData.likerPhoto,
    data: {
      type: isSuperLike ? 'super_like' : 'like',
      likerId: likeData.likerId,
      likerName: likeData.likerName
    }
  };

  await sendPushNotification(fcmToken, notification);

  await admin.firestore().collection('notification_logs').add({
    userId,
    type: isSuperLike ? 'super_like' : 'like',
    likerId: likeData.likerId,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });
}

/**
 * Sends daily engagement reminders to inactive users
 */
async function sendDailyEngagementReminders() {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const twoDaysAgo = new Date(Date.now() - 48 * 60 * 60 * 1000);

  // Get users who were active 24-48 hours ago
  const inactiveUsers = await admin.firestore()
    .collection('users')
    .where('lastActive', '>', twoDaysAgo)
    .where('lastActive', '<', oneDayAgo)
    .where('notificationsEnabled', '==', true)
    .get();

  functions.logger.info('Sending engagement reminders', { count: inactiveUsers.size });

  const promises = [];

  for (const userDoc of inactiveUsers.docs) {
    const user = userDoc.data();
    const userId = userDoc.id;

    if (!user.fcmToken) {
      continue;
    }

    // Get personalized stats
    const stats = await getPersonalizedStats(userId);

    let title = "We miss you! 💔";
    let body = "Come back and see what's new";

    // Personalize based on stats
    if (stats.newMatches > 0) {
      title = `You have ${stats.newMatches} new match${stats.newMatches === 1 ? '' : 'es'}! 💕`;
      body = "Don't keep them waiting!";
    } else if (stats.profileViews > 5) {
      title = `${stats.profileViews} people viewed your profile! 👀`;
      body = "Someone might be interested in you";
    } else if (stats.newLikes > 0) {
      title = `You have ${stats.newLikes} new like${stats.newLikes === 1 ? '' : 's'}! ❤️`;
      body = "Check out who likes you";
    }

    const notification = {
      title,
      body,
      sound: 'default',
      badge: await getUnreadCount(userId),
      category: 'ENGAGEMENT',
      data: {
        type: 'engagement_reminder',
        newMatches: stats.newMatches.toString(),
        profileViews: stats.profileViews.toString(),
        newLikes: stats.newLikes.toString()
      }
    };

    promises.push(sendPushNotification(user.fcmToken, notification));
  }

  await Promise.allSettled(promises);

  functions.logger.info('Engagement reminders sent', { sent: promises.length });

  return { sent: promises.length };
}

/**
 * Gets unread message count for a user
 * @param {string} userId - User ID
 * @returns {number} Unread count
 */
async function getUnreadCount(userId) {
  try {
    const snapshot = await admin.firestore()
      .collection('messages')
      .where('receiverId', '==', userId)
      .where('isRead', '==', false)
      .get();

    return snapshot.size;
  } catch (error) {
    return 0;
  }
}

/**
 * Gets personalized stats for a user
 * @param {string} userId - User ID
 * @returns {object} Stats
 */
async function getPersonalizedStats(userId) {
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);

  // Get new matches
  const matchesSnapshot = await admin.firestore()
    .collection('matches')
    .where('user1Id', '==', userId)
    .where('timestamp', '>', yesterday)
    .get();

  const newMatches = matchesSnapshot.size;

  // Get profile views
  const viewsSnapshot = await admin.firestore()
    .collection('profile_views')
    .where('viewedUserId', '==', userId)
    .where('timestamp', '>', yesterday)
    .get();

  const profileViews = viewsSnapshot.size;

  // Get new likes
  const likesSnapshot = await admin.firestore()
    .collection('likes')
    .where('targetUserId', '==', userId)
    .where('timestamp', '>', yesterday)
    .get();

  const newLikes = likesSnapshot.size;

  return {
    newMatches,
    profileViews,
    newLikes
  };
}

/**
 * Sends a profile status notification (approved/rejected)
 * @param {string} userId - User to notify
 * @param {object} statusData - Status information
 */
async function sendProfileStatusNotification(userId, statusData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for status notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  // Check if notifications are enabled
  if (!user.notificationsEnabled) {
    functions.logger.info('Notifications disabled for user', { userId });
    return;
  }

  let notification;

  if (statusData.status === 'approved' || statusData.status === 'active') {
    notification = {
      title: "Profile Approved! 🎉",
      body: "Your profile is now live. Start discovering people!",
      sound: 'default',
      badge: 1,
      category: 'PROFILE_STATUS',
      data: {
        type: 'profile_approved',
        status: 'approved'
      }
    };
  } else if (statusData.status === 'rejected') {
    notification = {
      title: "Profile Needs Updates",
      body: statusData.reason || "Please review your profile and make some changes.",
      sound: 'default',
      badge: 1,
      category: 'PROFILE_STATUS',
      data: {
        type: 'profile_rejected',
        status: 'rejected',
        reasonCode: statusData.reasonCode || 'unknown',
        reason: statusData.reason || ''
      }
    };
  } else {
    functions.logger.info('Unknown profile status, skipping notification', { status: statusData.status });
    return;
  }

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'profile_status',
    status: statusData.status,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Profile status notification sent', { userId, status: statusData.status });
}

/**
 * Sends a push notification to all admin users
 * @param {object} notificationData - Notification information
 */
async function sendAdminNotification(notificationData) {
  // Admin email whitelist - must match the one in index.js
  const adminEmails = ['perezkevin640@gmail.com', 'admin@celestia.app'];

  try {
    // Get all admin users
    const adminUsers = await admin.firestore()
      .collection('users')
      .where('email', 'in', adminEmails)
      .get();

    if (adminUsers.empty) {
      functions.logger.info('No admin users found for notification');
      return;
    }

    const promises = [];

    for (const adminDoc of adminUsers.docs) {
      const adminData = adminDoc.data();
      const fcmToken = adminData.fcmToken;

      if (!fcmToken) {
        functions.logger.info('No FCM token for admin', { adminId: adminDoc.id });
        continue;
      }

      // Check if notifications are enabled
      if (adminData.notificationsEnabled === false) {
        functions.logger.info('Notifications disabled for admin', { adminId: adminDoc.id });
        continue;
      }

      const notification = {
        title: notificationData.title,
        body: notificationData.body,
        sound: 'default',
        badge: notificationData.badge || 1,
        category: 'ADMIN',
        data: {
          type: 'admin_alert',
          alertType: notificationData.alertType || 'general',
          ...notificationData.data
        }
      };

      promises.push(
        sendPushNotification(fcmToken, notification)
          .then(() => {
            functions.logger.info('Admin notification sent', { adminId: adminDoc.id });
          })
          .catch((error) => {
            functions.logger.error('Failed to send admin notification', {
              adminId: adminDoc.id,
              error: error.message
            });
          })
      );
    }

    await Promise.allSettled(promises);

    // Log the admin notification
    await admin.firestore().collection('admin_alerts').add({
      type: notificationData.alertType || 'general',
      title: notificationData.title,
      body: notificationData.body,
      data: notificationData.data || {},
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientCount: promises.length
    });

    functions.logger.info('Admin notifications sent', { count: promises.length });

  } catch (error) {
    functions.logger.error('Error sending admin notifications', { error: error.message });
  }
}

/**
 * Sends notification to admins when a new account needs approval
 * @param {object} userData - New user's data
 */
async function sendNewAccountNotification(userData) {
  const userName = userData.firstName || userData.fullName || 'New user';

  await sendAdminNotification({
    title: '👤 New Account Pending',
    body: `${userName} just signed up and needs approval`,
    alertType: 'new_account_pending',
    badge: 1,
    data: {
      userId: userData.userId || '',
      userName: userName,
      userEmail: userData.email || ''
    }
  });
}

/**
 * Sends a warning notification to a user
 * @param {string} userId - User to notify
 * @param {object} warningData - Warning information
 */
async function sendWarningNotification(userId, warningData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for warning notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  const notification = {
    title: "⚠️ Account Warning",
    body: warningData.reason || "Your account has received a warning. Please review our guidelines.",
    sound: 'default',
    badge: 1,
    category: 'ACCOUNT_WARNING',
    data: {
      type: 'account_warning',
      reason: warningData.reason || '',
      warningCount: (warningData.warningCount || 1).toString()
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'account_warning',
    reason: warningData.reason,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Warning notification sent', { userId, reason: warningData.reason });
}

/**
 * Sends a suspension notification to a user
 * @param {string} userId - User to notify
 * @param {object} suspensionData - Suspension information
 */
async function sendSuspensionNotification(userId, suspensionData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for suspension notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  const days = suspensionData.days || 7;
  const reason = suspensionData.reason || "Violation of community guidelines";

  const notification = {
    title: "🚫 Account Suspended",
    body: `Your account has been suspended for ${days} days. Reason: ${reason}`,
    sound: 'default',
    badge: 1,
    category: 'ACCOUNT_SUSPENDED',
    data: {
      type: 'account_suspended',
      reason: reason,
      days: days.toString(),
      suspendedUntil: suspensionData.suspendedUntil || ''
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'account_suspended',
    reason: reason,
    days: days,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Suspension notification sent', { userId, days, reason });
}

/**
 * Sends a ban notification to a user
 * Called by admin when permanently banning an account
 * @param {string} userId - User to notify
 * @param {object} banData - Ban information
 */
async function sendBanNotification(userId, banData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for ban notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  const reason = banData.reason || "Serious violation of community guidelines";

  const notification = {
    title: "⛔ Account Banned",
    body: `Your account has been permanently banned. Reason: ${reason}`,
    sound: 'default',
    badge: 1,
    category: 'ACCOUNT_BANNED',
    data: {
      type: 'account_banned',
      reason: reason
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'account_banned',
    reason: reason,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Ban notification sent', { userId, reason });
}

/**
 * Sends a notification to the reporter when their report is resolved
 * @param {string} reporterId - User who filed the report
 * @param {object} resolutionData - Resolution information
 */
async function sendReportResolvedNotification(reporterId, resolutionData) {
  const userDoc = await admin.firestore().collection('users').doc(reporterId).get();

  if (!userDoc.exists) {
    functions.logger.error('Reporter not found for report resolution notification', { reporterId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for reporter', { reporterId });
    return;
  }

  const action = resolutionData.action || 'reviewed';
  let title = "📋 Report Update";
  let body = "Your report has been reviewed by our moderation team.";

  // Customize message based on action taken
  if (action === 'ban' || action === 'banned') {
    title = "✅ Report Action Taken";
    body = "Thank you for your report. The user has been removed from Celestia.";
  } else if (action === 'suspend' || action === 'suspended') {
    title = "✅ Report Action Taken";
    body = "Thank you for your report. The user has been suspended.";
  } else if (action === 'warn' || action === 'warned') {
    title = "✅ Report Action Taken";
    body = "Thank you for your report. A warning has been issued to the user.";
  } else if (action === 'dismiss' || action === 'dismissed') {
    title = "📋 Report Reviewed";
    body = "Your report has been reviewed. No violation was found, but we appreciate your help keeping Celestia safe.";
  }

  const notification = {
    title: title,
    body: body,
    sound: 'default',
    badge: 1,
    category: 'REPORT_RESOLVED',
    data: {
      type: 'report_resolved',
      action: action,
      reportId: resolutionData.reportId || ''
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId: reporterId,
    type: 'report_resolved',
    action: action,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Report resolution notification sent to reporter', { reporterId, action });
}

/**
 * Sends an ID verification rejection notification to a user
 * @param {string} userId - User to notify
 * @param {object} rejectionData - Rejection information
 */
async function sendIDVerificationRejectionNotification(userId, rejectionData) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for ID verification rejection notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  const reason = rejectionData.reason || "Your ID verification could not be completed";

  const notification = {
    title: "ID Verification Update",
    body: reason,
    sound: 'default',
    badge: 1,
    category: 'ID_VERIFICATION',
    data: {
      type: 'id_verification_rejected',
      reason: reason
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'id_verification_rejected',
    reason: reason,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('ID verification rejection notification sent', { userId, reason });
}

/**
 * Sends an appeal resolution notification to a user
 * @param {string} userId - User to notify
 * @param {boolean} approved - Whether the appeal was approved
 * @param {string} response - Admin response message
 */
async function sendAppealResolvedNotification(userId, approved, response) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    functions.logger.error('User not found for appeal resolution notification', { userId });
    return;
  }

  const user = userDoc.data();
  const fcmToken = user.fcmToken;

  if (!fcmToken) {
    functions.logger.info('No FCM token for user', { userId });
    return;
  }

  const title = approved ? "✅ Appeal Approved" : "❌ Appeal Denied";
  const body = approved
    ? "Your appeal has been approved. Your account access has been restored."
    : response || "Your appeal has been reviewed and denied.";

  const notification = {
    title: title,
    body: body,
    sound: 'default',
    badge: 1,
    category: 'APPEAL_RESULT',
    data: {
      type: 'appeal_resolved',
      approved: approved,
      response: response
    }
  };

  await sendPushNotification(fcmToken, notification);

  // Log the notification
  await admin.firestore().collection('notification_logs').add({
    userId,
    type: 'appeal_resolved',
    approved: approved,
    response: response,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    delivered: true
  });

  functions.logger.info('Appeal resolution notification sent', { userId, approved });
}

module.exports = {
  sendPushNotification,
  sendMatchNotification,
  sendMessageNotification,
  sendLikeNotification,
  sendDailyEngagementReminders,
  sendProfileStatusNotification,
  sendAdminNotification,
  sendNewAccountNotification,
  sendWarningNotification,
  sendSuspensionNotification,
  sendBanNotification,
  sendReportResolvedNotification,
  sendIDVerificationRejectionNotification,
  sendAppealResolvedNotification
};
