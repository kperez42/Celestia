/**
 * Content Moderation Module
 * Uses AI/ML to detect inappropriate content in photos and text
 */

const axios = require('axios');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Moderates an image for inappropriate content
 * @param {string} photoUrl - URL of the photo to moderate
 * @returns {object} Moderation result
 */
async function moderateImage(photoUrl) {
  try {
    // Option 1: Use Google Cloud Vision API
    const visionResult = await moderateWithVisionAPI(photoUrl);

    // Option 2: Use third-party service like Sightengine or AWS Rekognition
    // const sightengineResult = await moderateWithSightengine(photoUrl);

    return visionResult;

  } catch (error) {
    functions.logger.error('Image moderation error', { photoUrl, error: error.message });
    throw error;
  }
}

/**
 * Moderates image using Google Cloud Vision API
 * @param {string} photoUrl - Photo URL
 * @returns {object} Moderation result
 */
async function moderateWithVisionAPI(photoUrl) {
  const vision = require('@google-cloud/vision');
  const client = new vision.ImageAnnotatorClient();

  try {
    const [result] = await client.safeSearchDetection(photoUrl);
    const detections = result.safeSearchAnnotation;

    // Vision API returns likelihood levels: UNKNOWN, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY
    const likelihoodScore = {
      'UNKNOWN': 0,
      'VERY_UNLIKELY': 1,
      'UNLIKELY': 2,
      'POSSIBLE': 3,
      'LIKELY': 4,
      'VERY_LIKELY': 5
    };

    const scores = {
      adult: likelihoodScore[detections.adult] || 0,
      violence: likelihoodScore[detections.violence] || 0,
      racy: likelihoodScore[detections.racy] || 0,
      medical: likelihoodScore[detections.medical] || 0
    };

    // Determine if content should be approved
    const maxScore = Math.max(...Object.values(scores));
    const isApproved = maxScore <= 2; // Allow UNLIKELY or less
    const severity = maxScore >= 4 ? 'high' : maxScore >= 3 ? 'medium' : 'low';

    let reason = 'Content passed moderation';
    if (!isApproved) {
      const violations = Object.entries(scores)
        .filter(([_, score]) => score >= 3)
        .map(([category, _]) => category);

      reason = `Flagged for: ${violations.join(', ')}`;
    }

    // Check for faces (dating app should have clear face photos)
    const [faceResult] = await client.faceDetection(photoUrl);
    const faces = faceResult.faceAnnotations || [];

    if (faces.length === 0) {
      functions.logger.warn('No face detected in photo', { photoUrl });
    } else if (faces.length > 1) {
      functions.logger.info('Multiple faces detected', { photoUrl, count: faces.length });
    }

    return {
      isApproved,
      reason,
      severity,
      confidence: maxScore / 5, // Normalize to 0-1
      details: {
        scores,
        faceCount: faces.length
      }
    };

  } catch (error) {
    functions.logger.error('Vision API error', { error: error.message });

    // Fallback: Approve if API fails (with logging)
    return {
      isApproved: true,
      reason: 'Moderation API unavailable',
      severity: 'low',
      confidence: 0,
      error: error.message
    };
  }
}

/**
 * Moderates text content for inappropriate language
 * @param {string} text - Text to moderate
 * @returns {object} Moderation result
 */
async function moderateText(text) {
  try {
    // Check for prohibited patterns
    const prohibitedPatterns = getProhibitedPatterns();
    const violations = [];

    for (const [category, patterns] of Object.entries(prohibitedPatterns)) {
      for (const pattern of patterns) {
        if (pattern.test(text.toLowerCase())) {
          violations.push(category);
          break;
        }
      }
    }

    // Check for contact info sharing (scam prevention)
    const hasContactInfo = checkForContactInfo(text);
    if (hasContactInfo.detected) {
      violations.push('contact_info');
    }

    // Check for spam patterns
    const isSpam = checkForSpam(text);
    if (isSpam) {
      violations.push('spam');
    }

    const isApproved = violations.length === 0;
    const severity = determineTextSeverity(violations);

    let suggestions = [];
    if (!isApproved) {
      suggestions = getSuggestions(violations);
    }

    return {
      isApproved,
      reason: isApproved ? 'Text passed moderation' : `Flagged for: ${violations.join(', ')}`,
      severity,
      categories: violations,
      suggestions,
      details: {
        contactInfo: hasContactInfo.types,
        textLength: text.length
      }
    };

  } catch (error) {
    functions.logger.error('Text moderation error', { error: error.message });
    return {
      isApproved: true,
      reason: 'Moderation unavailable',
      severity: 'low',
      error: error.message
    };
  }
}

/**
 * Removes a photo from Firebase Storage
 * @param {string} photoUrl - URL of photo to remove
 */
async function removePhoto(photoUrl) {
  try {
    const storage = admin.storage();
    const bucket = storage.bucket();

    // Extract file path from URL
    const urlParts = photoUrl.split('/');
    const filePathEncoded = urlParts[urlParts.length - 1].split('?')[0];
    const filePath = decodeURIComponent(filePathEncoded);

    const file = bucket.file(filePath);
    await file.delete();

    functions.logger.info('Photo removed', { photoUrl, filePath });
  } catch (error) {
    functions.logger.error('Photo removal error', { photoUrl, error: error.message });
    throw error;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getProhibitedPatterns() {
  return {
    hate_speech: [
      /\b(racist|sexist|homophobic)\b/i,
      // Add more patterns
    ],
    sexual_content: [
      /\b(explicit|nsfw|xxx)\b/i,
      // Add more patterns
    ],
    violence: [
      /\b(kill|murder|assault)\b/i,
      // Add more patterns
    ],
    illegal: [
      /\b(drugs|cocaine|heroin)\b/i,
      // Add more patterns
    ]
  };
}

function checkForContactInfo(text) {
  const patterns = {
    phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
    email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
    instagram: /\b(instagram|insta|ig):\s*@?\w+\b/i,
    snapchat: /\b(snapchat|snap|sc):\s*@?\w+\b/i,
    whatsapp: /\b(whatsapp|wa):\s*[+\d\s-]+\b/i,
    telegram: /\b(telegram|tg):\s*@?\w+\b/i
  };

  const detected = [];
  for (const [type, pattern] of Object.entries(patterns)) {
    if (pattern.test(text)) {
      detected.push(type);
    }
  }

  return {
    detected: detected.length > 0,
    types: detected
  };
}

function checkForSpam(text) {
  const spamPatterns = [
    /\b(click here|visit|buy now|limited time)\b/i,
    /(.)\1{4,}/, // Repeated characters
    /[A-Z]{10,}/, // All caps
    /\b(earn money|make \$\d+|free money)\b/i
  ];

  return spamPatterns.some(pattern => pattern.test(text));
}

function determineTextSeverity(violations) {
  const highSeverity = ['hate_speech', 'violence', 'illegal'];
  const mediumSeverity = ['sexual_content', 'contact_info'];

  if (violations.some(v => highSeverity.includes(v))) return 'high';
  if (violations.some(v => mediumSeverity.includes(v))) return 'medium';
  return 'low';
}

function getSuggestions(violations) {
  const suggestions = {
    contact_info: 'Avoid sharing contact information. Keep conversations on the app for your safety.',
    sexual_content: 'Please keep your content appropriate and respectful.',
    hate_speech: 'Hateful language is not allowed on our platform.',
    spam: 'Promotional content and spam are not permitted.',
    violence: 'Content promoting violence is strictly prohibited.'
  };

  return violations.map(v => suggestions[v]).filter(Boolean);
}

module.exports = {
  moderateImage,
  moderateText,
  removePhoto
};
