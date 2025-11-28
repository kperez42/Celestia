/**
 * Stripe Identity Module
 * Handles server-side Stripe Identity verification session creation and status checking
 *
 * SETUP REQUIRED:
 * 1. Add Stripe SDK: npm install stripe
 * 2. Set environment variable: firebase functions:config:set stripe.secret_key="sk_live_..."
 * 3. Deploy functions: npm run deploy
 *
 * PRICING: $1.50 per verification (first 50 free)
 * DOCS: https://docs.stripe.com/identity
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Stripe SDK - initialize with secret key from environment
// IMPORTANT: Add stripe to package.json dependencies
// const stripe = require('stripe')(functions.config().stripe?.secret_key);

// Firestore reference
const db = admin.firestore();

// Configuration
const CONFIG = {
  // Stripe verification options
  verification_options: {
    document: {
      allowed_types: ['driving_license', 'passport', 'id_card'],
      require_id_number: false,
      require_live_capture: true,
      require_matching_selfie: true,
    },
  },
  // Return URL for web-based flows (iOS uses native SDK)
  return_url: 'celestia://verification-complete',
};

/**
 * Create a Stripe Identity verification session
 * Called by the iOS app to get session credentials
 *
 * @param {Object} data - Request data containing userId
 * @param {Object} context - Firebase function context with auth info
 * @returns {Object} - Session ID and ephemeral key secret
 */
async function createVerificationSession(data, context) {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;

  try {
    functions.logger.info('Creating Stripe Identity verification session', {
      userId,
    });

    // Get user data for metadata
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    // Check if user is already verified
    if (userData.stripeIdentityVerified) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User is already verified'
      );
    }

    // STRIPE API CALL
    // Uncomment when Stripe SDK is added to dependencies
    /*
    // Create verification session
    const verificationSession = await stripe.identity.verificationSessions.create({
      type: 'document',
      options: CONFIG.verification_options,
      metadata: {
        userId: userId,
        app: 'celestia',
      },
      return_url: CONFIG.return_url,
    });

    // Create ephemeral key for client-side SDK
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { verification_session: verificationSession.id },
      { apiVersion: '2023-10-16' }
    );

    // Store session reference in Firestore
    await db.collection('users').doc(userId).update({
      stripeVerificationSessionId: verificationSession.id,
      stripeVerificationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Stripe Identity verification session created', {
      userId,
      sessionId: verificationSession.id,
    });

    return {
      verificationSessionId: verificationSession.id,
      ephemeralKeySecret: ephemeralKey.secret,
    };
    */

    // TEMPORARY: Simulated response for development
    // Remove this when Stripe is configured
    const simulatedSessionId = `vs_simulated_${Date.now()}_${userId.substring(0, 8)}`;

    await db.collection('users').doc(userId).update({
      stripeVerificationSessionId: simulatedSessionId,
      stripeVerificationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Simulated Stripe Identity session created', {
      userId,
      sessionId: simulatedSessionId,
    });

    return {
      verificationSessionId: simulatedSessionId,
      ephemeralKeySecret: `ek_simulated_${Date.now()}`,
    };

  } catch (error) {
    functions.logger.error('Error creating verification session', {
      userId,
      error: error.message,
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to create verification session'
    );
  }
}

/**
 * Check the status of a Stripe Identity verification session
 *
 * @param {Object} data - Request data containing sessionId
 * @param {Object} context - Firebase function context with auth info
 * @returns {Object} - Verification status and details
 */
async function checkVerificationStatus(data, context) {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { sessionId } = data;
  const userId = context.auth.uid;

  if (!sessionId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Session ID is required'
    );
  }

  try {
    functions.logger.info('Checking Stripe Identity verification status', {
      userId,
      sessionId,
    });

    // Verify the session belongs to this user
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    if (userData.stripeVerificationSessionId !== sessionId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Session does not belong to this user'
      );
    }

    // STRIPE API CALL
    // Uncomment when Stripe SDK is added to dependencies
    /*
    const verificationSession = await stripe.identity.verificationSessions.retrieve(sessionId);

    const status = verificationSession.status;
    let verificationStatus;

    switch (status) {
      case 'verified':
        verificationStatus = 'verified';
        // Update user verification status in Firestore
        await db.collection('users').doc(userId).update({
          stripeIdentityVerified: true,
          stripeIdentityVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          stripeVerificationStatus: 'verified',
          idVerified: true,
          idVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          verificationMethods: admin.firestore.FieldValue.arrayUnion('stripe_identity'),
        });
        break;
      case 'requires_input':
        verificationStatus = 'requires_input';
        break;
      case 'processing':
        verificationStatus = 'processing';
        break;
      case 'canceled':
        verificationStatus = 'canceled';
        break;
      default:
        verificationStatus = 'failed';
    }

    return {
      status: verificationStatus,
      sessionId: sessionId,
      lastError: verificationSession.last_error?.message || null,
    };
    */

    // TEMPORARY: Simulated response for development
    // Remove this when Stripe is configured
    return {
      status: userData.stripeVerificationStatus || 'processing',
      sessionId: sessionId,
      lastError: null,
    };

  } catch (error) {
    functions.logger.error('Error checking verification status', {
      userId,
      sessionId,
      error: error.message,
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to check verification status'
    );
  }
}

/**
 * Stripe webhook handler for verification session updates
 * Called by Stripe when verification status changes
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function handleStripeWebhook(req, res) {
  const sig = req.headers['stripe-signature'];
  const endpointSecret = functions.config().stripe?.webhook_secret;

  // STRIPE WEBHOOK VERIFICATION
  // Uncomment when Stripe SDK is added to dependencies
  /*
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    functions.logger.error('Webhook signature verification failed', {
      error: err.message,
    });
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  switch (event.type) {
    case 'identity.verification_session.verified':
      const verifiedSession = event.data.object;
      await handleVerificationVerified(verifiedSession);
      break;

    case 'identity.verification_session.requires_input':
      const inputSession = event.data.object;
      await handleVerificationRequiresInput(inputSession);
      break;

    case 'identity.verification_session.canceled':
      const canceledSession = event.data.object;
      await handleVerificationCanceled(canceledSession);
      break;

    default:
      functions.logger.info(`Unhandled event type: ${event.type}`);
  }

  res.json({ received: true });
  */

  // TEMPORARY: Simulated webhook response
  res.json({ received: true, simulated: true });
}

/**
 * Handle successful verification
 */
async function handleVerificationVerified(session) {
  const userId = session.metadata?.userId;

  if (!userId) {
    functions.logger.error('No userId in verification session metadata', {
      sessionId: session.id,
    });
    return;
  }

  functions.logger.info('Verification verified via webhook', {
    userId,
    sessionId: session.id,
  });

  // Update user verification status
  await db.collection('users').doc(userId).update({
    stripeIdentityVerified: true,
    stripeIdentityVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    stripeVerificationStatus: 'verified',
    idVerified: true,
    idVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    verificationMethods: admin.firestore.FieldValue.arrayUnion('stripe_identity'),
    // Update trust score
    trustScore: admin.firestore.FieldValue.increment(35),
    isVerified: true,
  });

  // Send push notification to user
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  if (userData?.fcmToken) {
    const admin = require('firebase-admin');
    await admin.messaging().send({
      token: userData.fcmToken,
      notification: {
        title: 'Verification Complete!',
        body: 'Your identity has been verified. You now have a verified badge!',
      },
      data: {
        type: 'verification_complete',
        status: 'verified',
      },
    });
  }
}

/**
 * Handle verification requiring additional input
 */
async function handleVerificationRequiresInput(session) {
  const userId = session.metadata?.userId;

  if (!userId) return;

  functions.logger.info('Verification requires input', {
    userId,
    sessionId: session.id,
  });

  await db.collection('users').doc(userId).update({
    stripeVerificationStatus: 'requires_input',
  });
}

/**
 * Handle canceled verification
 */
async function handleVerificationCanceled(session) {
  const userId = session.metadata?.userId;

  if (!userId) return;

  functions.logger.info('Verification canceled', {
    userId,
    sessionId: session.id,
  });

  await db.collection('users').doc(userId).update({
    stripeVerificationStatus: 'canceled',
  });
}

module.exports = {
  createVerificationSession,
  checkVerificationStatus,
  handleStripeWebhook,
};
