/**
 * Celestia Cloud Functions
 *
 * Admin moderation functions for the Celestia dating app
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Admin email whitelist - only these users can access moderation functions
const ADMIN_EMAILS = ["perezkevin640@gmail.com", "admin@celestia.app"];

/**
 * Verify that the caller is an admin
 */
async function verifyAdmin(context: functions.https.CallableContext): Promise<void> {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated to access this function"
    );
  }

  const email = context.auth.token.email?.toLowerCase();
  if (!email || !ADMIN_EMAILS.includes(email)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Must be an admin to access this function"
    );
  }
}

/**
 * Get the moderation queue (reports, suspicious profiles, stats)
 */
export const getModerationQueue = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const status = data.status || "pending";
  const limit = Math.min(data.limit || 50, 100);

  try {
    // Get pending reports
    const reportsSnapshot = await db.collection("reports")
      .where("status", "==", status)
      .orderBy("timestamp", "desc")
      .limit(limit)
      .get();

    const reports = await Promise.all(
      reportsSnapshot.docs.map(async (doc) => {
        const reportData = doc.data();

        // Get reporter info
        let reporter = null;
        if (reportData.reporterId) {
          const reporterDoc = await db.collection("users").doc(reportData.reporterId).get();
          if (reporterDoc.exists) {
            const userData = reporterDoc.data();
            reporter = {
              id: reportData.reporterId,
              name: userData?.fullName || "Unknown",
              email: userData?.email || "",
              photoURL: userData?.profileImageURL || null,
            };
          }
        }

        // Get reported user info
        let reportedUser = null;
        if (reportData.reportedUserId) {
          const reportedDoc = await db.collection("users").doc(reportData.reportedUserId).get();
          if (reportedDoc.exists) {
            const userData = reportedDoc.data();
            reportedUser = {
              id: reportData.reportedUserId,
              name: userData?.fullName || "Unknown",
              email: userData?.email || "",
              photoURL: userData?.profileImageURL || null,
            };
          }
        }

        return {
          id: doc.id,
          reason: reportData.reason || "Unknown",
          timestamp: reportData.timestamp?.toDate?.()?.toISOString() || new Date().toISOString(),
          status: reportData.status || "pending",
          additionalDetails: reportData.additionalDetails || null,
          reporter,
          reportedUser,
        };
      })
    );

    // Get suspicious profiles from moderation queue
    const moderationQueueSnapshot = await db.collection("moderationQueue")
      .where("status", "==", "pending")
      .orderBy("suspicionScore", "desc")
      .limit(limit)
      .get();

    const moderationQueue = await Promise.all(
      moderationQueueSnapshot.docs.map(async (doc) => {
        const queueData = doc.data();

        // Get user info
        let user = null;
        if (queueData.userId) {
          const userDoc = await db.collection("users").doc(queueData.userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            user = {
              id: queueData.userId,
              name: userData?.fullName || "Unknown",
              photoURL: userData?.profileImageURL || null,
            };
          }
        }

        return {
          id: doc.id,
          suspicionScore: queueData.suspicionScore || 0,
          indicators: queueData.indicators || [],
          autoDetected: queueData.autoDetected ?? true,
          timestamp: queueData.timestamp?.toDate?.()?.toISOString() || new Date().toISOString(),
          user,
        };
      })
    );

    // Get stats
    const [totalReportsSnap, pendingReportsSnap, resolvedReportsSnap, suspiciousSnap] = await Promise.all([
      db.collection("reports").count().get(),
      db.collection("reports").where("status", "==", "pending").count().get(),
      db.collection("reports").where("status", "==", "resolved").count().get(),
      db.collection("moderationQueue").where("status", "==", "pending").count().get(),
    ]);

    const stats = {
      totalReports: totalReportsSnap.data().count,
      pendingReports: pendingReportsSnap.data().count,
      resolvedReports: resolvedReportsSnap.data().count,
      suspiciousProfiles: suspiciousSnap.data().count,
    };

    return {
      reports,
      moderationQueue,
      stats,
    };
  } catch (error) {
    console.error("Error getting moderation queue:", error);
    throw new functions.https.HttpsError("internal", "Failed to get moderation queue");
  }
});

/**
 * Moderate a report (dismiss, warn, suspend, ban)
 */
export const moderateReport = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { reportId, action, reason, duration } = data;

  if (!reportId || !action) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "reportId and action are required"
    );
  }

  const validActions = ["dismiss", "warn", "suspend", "ban"];
  if (!validActions.includes(action)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid action. Must be one of: ${validActions.join(", ")}`
    );
  }

  try {
    // Get the report
    const reportRef = db.collection("reports").doc(reportId);
    const reportDoc = await reportRef.get();

    if (!reportDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Report not found");
    }

    const reportData = reportDoc.data()!;
    const reportedUserId = reportData.reportedUserId;

    // Update report status
    await reportRef.update({
      status: "resolved",
      resolution: action,
      resolutionReason: reason || null,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: context.auth!.uid,
    });

    // Take action on the user
    if (reportedUserId && action !== "dismiss") {
      const userRef = db.collection("users").doc(reportedUserId);

      switch (action) {
        case "warn":
          await userRef.update({
            warningsCount: admin.firestore.FieldValue.increment(1),
            lastWarningAt: admin.firestore.FieldValue.serverTimestamp(),
            lastWarningReason: reason || "Violation of community guidelines",
          });
          break;

        case "suspend":
          const suspendDays = duration || 7;
          const suspendUntil = new Date();
          suspendUntil.setDate(suspendUntil.getDate() + suspendDays);

          await userRef.update({
            isSuspended: true,
            suspendedUntil: admin.firestore.Timestamp.fromDate(suspendUntil),
            suspendedReason: reason || "Violation of community guidelines",
          });
          break;

        case "ban":
          await userRef.update({
            isBanned: true,
            bannedAt: admin.firestore.FieldValue.serverTimestamp(),
            bannedReason: reason || "Repeated violations of community guidelines",
          });

          // Disable Firebase Auth account
          try {
            await admin.auth().updateUser(reportedUserId, { disabled: true });
          } catch (authError) {
            console.error("Error disabling auth account:", authError);
          }
          break;
      }

      // Log moderation action
      await db.collection("moderationLogs").add({
        action,
        targetUserId: reportedUserId,
        reportId,
        reason: reason || null,
        performedBy: context.auth!.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { success: true };
  } catch (error) {
    console.error("Error moderating report:", error);
    throw new functions.https.HttpsError("internal", "Failed to moderate report");
  }
});

/**
 * Ban a user directly (without a report)
 */
export const banUserDirectly = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { userId, reason } = data;

  if (!userId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId is required"
    );
  }

  try {
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }

    // Ban the user
    await userRef.update({
      isBanned: true,
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      bannedReason: reason || "Banned by admin",
    });

    // Disable Firebase Auth account
    try {
      await admin.auth().updateUser(userId, { disabled: true });
    } catch (authError) {
      console.error("Error disabling auth account:", authError);
    }

    // Remove from moderation queue if present
    const queueSnapshot = await db.collection("moderationQueue")
      .where("userId", "==", userId)
      .get();

    const batch = db.batch();
    queueSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { status: "resolved", resolution: "banned" });
    });
    await batch.commit();

    // Log moderation action
    await db.collection("moderationLogs").add({
      action: "ban",
      targetUserId: userId,
      reason: reason || null,
      performedBy: context.auth!.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("Error banning user:", error);
    throw new functions.https.HttpsError("internal", "Failed to ban user");
  }
});
