/**
 * Tests for Content Moderation Module
 * CRITICAL: Protects user safety and app reputation
 */

const { describe, test, expect, beforeEach } = require('@jest/globals');

// Mock dependencies
jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  }
}));

jest.mock('firebase-admin', () => ({
  storage: () => ({
    bucket: () => ({
      file: jest.fn(() => ({
        delete: jest.fn().mockResolvedValue(undefined)
      }))
    })
  }),
  initializeApp: jest.fn()
}));

jest.mock('@google-cloud/vision', () => {
  return jest.fn().mockImplementation(() => ({
    ImageAnnotatorClient: jest.fn().mockImplementation(() => ({
      safeSearchDetection: jest.fn(),
      faceDetection: jest.fn()
    }))
  }));
});

const contentModeration = require('../modules/contentModeration');

describe('Content Moderation Module', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('moderateText', () => {
    test('should approve clean text', async () => {
      const cleanText = 'Hello! I love hiking and photography. Looking to meet new people!';

      const result = await contentModeration.moderateText(cleanText);

      expect(result.isApproved).toBe(true);
      expect(result.reason).toBe('Text passed moderation');
      expect(result.severity).toBe('low');
      expect(result.categories).toHaveLength(0);
    });

    test('should detect phone numbers', async () => {
      const textWithPhone = 'Call me at 555-123-4567';

      const result = await contentModeration.moderateText(textWithPhone);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('contact_info');
      expect(result.details.contactInfo).toContain('phone');
    });

    test('should detect email addresses', async () => {
      const textWithEmail = 'Email me at example@gmail.com';

      const result = await contentModeration.moderateText(textWithEmail);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('contact_info');
      expect(result.details.contactInfo).toContain('email');
    });

    test('should detect social media handles', async () => {
      const tests = [
        { text: 'Follow me on instagram: @myhandle', platform: 'instagram' },
        { text: 'Add me on snapchat: username123', platform: 'snapchat' },
        { text: 'Message me on telegram: @user', platform: 'telegram' },
        { text: 'WhatsApp me: +1-555-1234', platform: 'whatsapp' }
      ];

      for (const { text } of tests) {
        const result = await contentModeration.moderateText(text);

        expect(result.isApproved).toBe(false);
        expect(result.categories).toContain('contact_info');
      }
    });

    test('should detect sexual content', async () => {
      const sexualText = 'Looking for explicit fun';

      const result = await contentModeration.moderateText(sexualText);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('sexual_content');
      expect(result.severity).toBe('medium');
    });

    test('should detect violent language', async () => {
      const violentText = 'I want to kill someone';

      const result = await contentModeration.moderateText(violentText);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('violence');
      expect(result.severity).toBe('high');
    });

    test('should detect spam patterns', async () => {
      const spamTexts = [
        'CLICK HERE NOW!!!',
        'Buy now for limited time offer',
        'AAAAAAAAAA', // Repeated characters
        'Make $5000 per day easy money'
      ];

      for (const text of spamTexts) {
        const result = await contentModeration.moderateText(text);

        expect(result.isApproved).toBe(false);
        expect(result.categories).toContain('spam');
      }
    });

    test('should provide helpful suggestions for violations', async () => {
      const textWithContact = 'Text me at 555-1234';

      const result = await contentModeration.moderateText(textWithContact);

      expect(result.suggestions).toBeDefined();
      expect(result.suggestions.length).toBeGreaterThan(0);
      expect(result.suggestions[0]).toContain('contact information');
    });

    test('should handle multiple violations', async () => {
      const multiViolation = 'Email me explicit photos at bad@email.com';

      const result = await contentModeration.moderateText(multiViolation);

      expect(result.isApproved).toBe(false);
      expect(result.categories.length).toBeGreaterThan(1);
      expect(result.categories).toContain('contact_info');
      expect(result.categories).toContain('sexual_content');
    });

    test('should include text length in details', async () => {
      const text = 'Hello world';

      const result = await contentModeration.moderateText(text);

      expect(result.details.textLength).toBe(text.length);
    });

    test('should determine severity correctly', async () => {
      const highSeverityText = 'I hate everyone, kill them all';
      const mediumSeverityText = 'Send explicit pics';
      const lowSeverityText = 'Hello there';

      const high = await contentModeration.moderateText(highSeverityText);
      const medium = await contentModeration.moderateText(mediumSeverityText);
      const low = await contentModeration.moderateText(lowSeverityText);

      expect(high.severity).toBe('high');
      expect(medium.severity).toBe('medium');
      expect(low.severity).toBe('low');
    });

    test('should handle empty text', async () => {
      const result = await contentModeration.moderateText('');

      expect(result.isApproved).toBe(true);
    });

    test('should be case insensitive', async () => {
      const uppercase = await contentModeration.moderateText('CALL ME AT 555-1234');
      const lowercase = await contentModeration.moderateText('call me at 555-1234');
      const mixed = await contentModeration.moderateText('CaLl Me At 555-1234');

      expect(uppercase.isApproved).toBe(false);
      expect(lowercase.isApproved).toBe(false);
      expect(mixed.isApproved).toBe(false);
    });

    test('should detect hate speech patterns', async () => {
      const hatefulText = 'You are so racist and homophobic';

      const result = await contentModeration.moderateText(hatefulText);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('hate_speech');
      expect(result.severity).toBe('high');
    });

    test('should detect illegal content references', async () => {
      const illegalText = 'Want to buy some cocaine';

      const result = await contentModeration.moderateText(illegalText);

      expect(result.isApproved).toBe(false);
      expect(result.categories).toContain('illegal');
      expect(result.severity).toBe('high');
    });
  });

  describe('moderateImage', () => {
    test('should approve safe images with faces', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      // Mock safe image response
      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'VERY_UNLIKELY',
          violence: 'VERY_UNLIKELY',
          racy: 'UNLIKELY',
          medical: 'VERY_UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: [{ /* face data */ }]
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/photo.jpg');

      expect(result.isApproved).toBe(true);
      expect(result.reason).toBe('Content passed moderation');
      expect(result.details.faceCount).toBe(1);
    });

    test('should reject images with adult content', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'VERY_LIKELY',
          violence: 'UNLIKELY',
          racy: 'POSSIBLE',
          medical: 'UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: []
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/bad.jpg');

      expect(result.isApproved).toBe(false);
      expect(result.reason).toContain('adult');
      expect(result.severity).toBe('high');
    });

    test('should flag violent content', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'UNLIKELY',
          violence: 'LIKELY',
          racy: 'UNLIKELY',
          medical: 'UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: []
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/violent.jpg');

      expect(result.isApproved).toBe(false);
      expect(result.reason).toContain('violence');
    });

    test('should warn about missing faces in dating profile', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();
      const functions = require('firebase-functions');

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'VERY_UNLIKELY',
          violence: 'VERY_UNLIKELY',
          racy: 'UNLIKELY',
          medical: 'VERY_UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: [] // No faces
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/landscape.jpg');

      expect(result.details.faceCount).toBe(0);
      expect(functions.logger.warn).toHaveBeenCalledWith(
        'No face detected in photo',
        expect.any(Object)
      );
    });

    test('should note multiple faces in image', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();
      const functions = require('firebase-functions');

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'VERY_UNLIKELY',
          violence: 'VERY_UNLIKELY',
          racy: 'UNLIKELY',
          medical: 'VERY_UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: [{}, {}, {}] // 3 faces
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/group.jpg');

      expect(result.details.faceCount).toBe(3);
      expect(functions.logger.info).toHaveBeenCalledWith(
        'Multiple faces detected',
        expect.objectContaining({ count: 3 })
      );
    });

    test('should fail open if Vision API fails', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      mockClient.safeSearchDetection.mockRejectedValueOnce(new Error('API Error'));

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/photo.jpg');

      expect(result.isApproved).toBe(true);
      expect(result.reason).toBe('Moderation API unavailable');
      expect(result.error).toBe('API Error');
    });

    test('should calculate confidence scores correctly', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'POSSIBLE',
          violence: 'UNLIKELY',
          racy: 'POSSIBLE',
          medical: 'VERY_UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: [{}]
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/test.jpg');

      expect(result.confidence).toBeGreaterThanOrEqual(0);
      expect(result.confidence).toBeLessThanOrEqual(1);
    });

    test('should provide detailed scores in response', async () => {
      const vision = require('@google-cloud/vision');
      const mockClient = new vision.ImageAnnotatorClient();

      mockClient.safeSearchDetection.mockResolvedValueOnce([{
        safeSearchAnnotation: {
          adult: 'UNLIKELY',
          violence: 'VERY_UNLIKELY',
          racy: 'UNLIKELY',
          medical: 'VERY_UNLIKELY'
        }
      }]);

      mockClient.faceDetection.mockResolvedValueOnce([{
        faceAnnotations: [{}]
      }]);

      vision.ImageAnnotatorClient.mockImplementationOnce(() => mockClient);

      const result = await contentModeration.moderateImage('https://example.com/photo.jpg');

      expect(result.details.scores).toBeDefined();
      expect(result.details.scores.adult).toBeDefined();
      expect(result.details.scores.violence).toBeDefined();
      expect(result.details.scores.racy).toBeDefined();
      expect(result.details.scores.medical).toBeDefined();
    });
  });

  describe('removePhoto', () => {
    test('should delete photo from Firebase Storage', async () => {
      const admin = require('firebase-admin');
      const mockDelete = jest.fn().mockResolvedValue(undefined);

      admin.storage().bucket().file.mockReturnValue({
        delete: mockDelete
      });

      const photoUrl = 'https://storage.googleapis.com/bucket/users/user123/photo.jpg?token=abc';

      await contentModeration.removePhoto(photoUrl);

      expect(mockDelete).toHaveBeenCalled();
    });

    test('should handle URL decoding correctly', async () => {
      const admin = require('firebase-admin');
      const mockFile = jest.fn().mockReturnValue({
        delete: jest.fn().mockResolvedValue(undefined)
      });

      admin.storage().bucket().file = mockFile;

      const encodedUrl = 'https://storage.googleapis.com/bucket/users%2Fuser123%2Fphoto.jpg?token=xyz';

      await contentModeration.removePhoto(encodedUrl);

      expect(mockFile).toHaveBeenCalledWith(expect.stringContaining('users'));
    });

    test('should throw error if deletion fails', async () => {
      const admin = require('firebase-admin');
      const mockDelete = jest.fn().mockRejectedValue(new Error('Permission denied'));

      admin.storage().bucket().file.mockReturnValue({
        delete: mockDelete
      });

      await expect(
        contentModeration.removePhoto('https://example.com/photo.jpg')
      ).rejects.toThrow('Permission denied');
    });

    test('should log successful deletion', async () => {
      const admin = require('firebase-admin');
      const functions = require('firebase-functions');
      const mockDelete = jest.fn().mockResolvedValue(undefined);

      admin.storage().bucket().file.mockReturnValue({
        delete: mockDelete
      });

      const photoUrl = 'https://storage.googleapis.com/bucket/photo.jpg';

      await contentModeration.removePhoto(photoUrl);

      expect(functions.logger.info).toHaveBeenCalledWith(
        'Photo removed',
        expect.any(Object)
      );
    });
  });

  describe('Edge Cases and Error Handling', () => {
    test('should handle very long text', async () => {
      const longText = 'a'.repeat(10000);

      const result = await contentModeration.moderateText(longText);

      expect(result).toBeDefined();
      expect(result.details.textLength).toBe(10000);
    });

    test('should handle special characters in text', async () => {
      const specialText = '!@#$%^&*()_+-=[]{}|;:\'",.<>?/~`';

      const result = await contentModeration.moderateText(specialText);

      expect(result).toBeDefined();
      expect(result.isApproved).toBe(true);
    });

    test('should handle unicode and emojis', async () => {
      const emojiText = 'Hello 👋 I love ❤️ coffee ☕ and travel ✈️';

      const result = await contentModeration.moderateText(emojiText);

      expect(result).toBeDefined();
      expect(result.isApproved).toBe(true);
    });

    test('should handle null/undefined gracefully', async () => {
      // Text moderation error handling
      await expect(async () => {
        await contentModeration.moderateText(null);
      }).rejects.toThrow();
    });
  });
});
