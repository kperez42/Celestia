#!/bin/bash

# Firebase Deployment Script for Image Optimization System
# Run this after: firebase login

set -e  # Exit on error

echo "🚀 Starting deployment process..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "${YELLOW}⚠️  Firebase CLI not found. Installing...${NC}"
    npm install -g firebase-tools
fi

# Check if logged in
echo "${BLUE}Checking Firebase authentication...${NC}"
if ! firebase projects:list &> /dev/null; then
    echo "${YELLOW}⚠️  Not logged in to Firebase. Running login...${NC}"
    firebase login
fi

# Verify project
echo "${BLUE}Current project:${NC}"
firebase use

# Install dependencies
echo ""
echo "${BLUE}📦 Installing dependencies...${NC}"
npm install

# Set Firebase config
echo ""
echo "${BLUE}🔧 Configuring Cloudinary credentials...${NC}"
firebase functions:config:set \
  cloudinary.cloud_name="dquqeovn2" \
  cloudinary.api_key="551344196324785" \
  cloudinary.api_secret="td1HXKjKpubpxf9yIxzqgXoGwes"

# Verify config
echo ""
echo "${BLUE}Verifying configuration...${NC}"
firebase functions:config:get

# Test Cloudinary connection
echo ""
echo "${BLUE}🧪 Testing Cloudinary connection...${NC}"
if node test-cloudinary.js; then
    echo "${GREEN}✅ Cloudinary connection successful!${NC}"
else
    echo "${YELLOW}⚠️  Cloudinary test failed, but continuing deployment...${NC}"
fi

# Deploy functions
echo ""
echo "${BLUE}🚀 Deploying Cloud Functions...${NC}"
firebase deploy --only functions

echo ""
echo "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "📊 Next steps:"
echo "  1. Check Firebase Console: https://console.firebase.google.com/project/celestia-dating-app/functions"
echo "  2. Test from iOS app"
echo "  3. Monitor performance: https://console.firebase.google.com/project/celestia-dating-app/performance"
echo "  4. Check Cloudinary dashboard: https://console.cloudinary.com/console/c-dquqeovn2"
echo ""
echo "📚 Documentation:"
echo "  - DEPLOYMENT_GUIDE.md - Full deployment instructions"
echo "  - TESTING_GUIDE.md - Testing procedures"
echo "  - PERFORMANCE_MONITORING_GUIDE.md - Monitoring setup"
echo ""
