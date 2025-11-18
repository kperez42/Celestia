#!/bin/bash

echo "🚀 Cloudinary Setup Script"
echo "=========================="
echo ""

# Check if .env already exists
if [ -f .env ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled."
        exit 1
    fi
fi

echo "Please enter your Cloudinary credentials:"
echo "(Get them from: https://console.cloudinary.com/)"
echo ""

read -p "Cloud Name: " cloud_name
read -p "API Key: " api_key
read -sp "API Secret: " api_secret
echo ""
echo ""

# Validate inputs
if [ -z "$cloud_name" ] || [ -z "$api_key" ] || [ -z "$api_secret" ]; then
    echo "❌ Error: All fields are required!"
    exit 1
fi

# Create .env file
cat > .env <<EOL
# Cloudinary Configuration
# Auto-generated on $(date)

CLOUDINARY_CLOUD_NAME=$cloud_name
CLOUDINARY_API_KEY=$api_key
CLOUDINARY_API_SECRET=$api_secret
EOL

echo "✅ .env file created successfully!"
echo ""
echo "Next steps:"
echo "1. Test locally: npm run serve"
echo "2. Deploy to production:"
echo "   firebase functions:config:set cloudinary.cloud_name=\"$cloud_name\""
echo "   firebase functions:config:set cloudinary.api_key=\"$api_key\""
echo "   firebase functions:config:set cloudinary.api_secret=\"$api_secret\""
echo "   firebase deploy --only functions"
echo ""
echo "🎉 Setup complete!"
