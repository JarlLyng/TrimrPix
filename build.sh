#!/bin/bash

# TrimrPix Build Script
# This script builds TrimrPix for distribution

set -e

echo "🚀 Building TrimrPix for distribution..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCHEME="TrimrPix"
CONFIGURATION="Release"
ARCHIVE_NAME="TrimrPix.xcarchive"
APP_NAME="TrimrPix.app"
DMG_NAME="TrimrPix.dmg"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf *.xcarchive
rm -rf *.dmg
rm -rf *.app

# Build the app
echo "🔨 Building app..."
xcodebuild -project TrimrPix.xcodeproj \
           -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -derivedDataPath ./build \
           build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Copy app to current directory
echo "📦 Copying app..."
cp -R "./build/Build/Products/Release/$APP_NAME" ./

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "TrimrPix" \
               -srcfolder "$APP_NAME" \
               -ov \
               -format UDZO \
               "$DMG_NAME"

# Check if DMG was created successfully
if [ -f "$DMG_NAME" ]; then
    echo -e "${GREEN}✅ DMG created successfully: $DMG_NAME${NC}"
    echo "📏 DMG size: $(du -h "$DMG_NAME" | cut -f1)"
else
    echo -e "${RED}❌ DMG creation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo "📁 Files created:"
echo "   - $APP_NAME (App bundle)"
echo "   - $DMG_NAME (Distribution package)"
echo ""
echo "📋 Next steps:"
echo "   1. Test the app: open $APP_NAME"
echo "   2. For App Store: Archive in Xcode and upload to App Store Connect"
echo "   3. For direct distribution: Upload $DMG_NAME to GitHub Releases"
echo ""
echo "🔧 For notarization (required for distribution):"
echo "   xcrun notarytool submit $DMG_NAME --apple-id YOUR_EMAIL --password APP_PASSWORD --team-id YOUR_TEAM_ID"
