/**
 * Test Cloudinary Configuration
 * Verifies that Cloudinary credentials are working
 */

require('dotenv').config();
const cloudinary = require('cloudinary').v2;

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true
});

console.log('🧪 Testing Cloudinary Configuration...\n');

// Test 1: Check configuration
console.log('📋 Configuration:');
console.log('  Cloud Name:', cloudinary.config().cloud_name || '❌ Missing');
console.log('  API Key:', cloudinary.config().api_key ? '✅ Set' : '❌ Missing');
console.log('  API Secret:', cloudinary.config().api_secret ? '✅ Set' : '❌ Missing');
console.log('');

// Test 2: Ping Cloudinary API
console.log('🌐 Testing API Connection...');

cloudinary.api.ping()
  .then(result => {
    console.log('✅ Connection successful!');
    console.log('  Status:', result.status);
    console.log('');
    
    // Test 3: Generate a sample URL
    console.log('🔗 Testing URL Generation...');
    const sampleUrl = cloudinary.url('sample', {
      transformation: [
        { width: 300, height: 300, crop: 'fill' },
        { quality: 'auto', fetch_format: 'auto' }
      ]
    });
    console.log('  Sample URL:', sampleUrl);
    console.log('');
    
    console.log('🎉 All tests passed! Cloudinary is ready to use.');
    console.log('');
    console.log('Next steps:');
    console.log('  1. Deploy functions: firebase deploy --only functions');
    console.log('  2. Test image upload from iOS app');
    console.log('  3. Verify images appear in Cloudinary dashboard');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Connection failed!');
    console.error('Error:', error.message);
    console.error('');
    console.error('Please check:');
    console.error('  1. Cloud Name is correct');
    console.error('  2. API Key is correct');
    console.error('  3. API Secret is correct');
    console.error('  4. Internet connection is working');
    process.exit(1);
  });
