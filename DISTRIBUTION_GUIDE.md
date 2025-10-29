# TrimrPix Distribution Guide

## 🍎 App Store Distribution

### Prerequisites
1. **Apple Developer Account** ($99/year)
   - Sign up at [developer.apple.com](https://developer.apple.com)
   - Complete enrollment process

### Steps to App Store

#### 1. Configure App Store Settings
- Open `TrimrPix.xcodeproj` in Xcode
- Select the project → TrimrPix target
- Go to "Signing & Capabilities"
- Select your Apple Developer Team
- Ensure "Automatically manage signing" is enabled

#### 2. App Store Connect Setup
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app:
   - **Name:** TrimrPix
   - **Bundle ID:** com.iamjarl.trimrpix.TrimrPix
   - **SKU:** trimrpix-mac
   - **Platform:** macOS

#### 3. App Information
- **Description:** High-quality image compression app for macOS
- **Keywords:** image, compression, optimization, photos, jpeg, png
- **Category:** Graphics & Design
- **Age Rating:** 4+ (No objectionable content)

#### 4. Screenshots & Metadata
- Create screenshots (1280x800 minimum)
- App icon (1024x1024)
- Privacy policy URL (required)

#### 5. Build & Upload
```bash
# Archive the app
xcodebuild -project TrimrPix.xcodeproj -scheme TrimrPix -configuration Release archive -archivePath TrimrPix.xcarchive

# Upload to App Store Connect
xcodebuild -exportArchive -archivePath TrimrPix.xcarchive -exportPath ./Export -exportOptionsPlist ExportOptions.plist
```

#### 6. Submit for Review
- Upload build in App Store Connect
- Complete app information
- Submit for review (1-7 days)

---

## 🚀 Direct Distribution (GitHub Releases)

### Prerequisites
- **Apple Developer Account** (free tier works for Developer ID)
- **Xcode** with command line tools

### Steps for Direct Distribution

#### 1. Create Developer ID Certificate
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles
3. Create "Developer ID Application" certificate
4. Download and install in Keychain

#### 2. Configure Code Signing
- Open project in Xcode
- Select "Developer ID Application" for signing
- Ensure "Hardened Runtime" is enabled

#### 3. Build for Distribution
```bash
# Build the app
xcodebuild -project TrimrPix.xcodeproj -scheme TrimrPix -configuration Release -derivedDataPath ./build

# Create .app bundle
cp -R ./build/Build/Products/Release/TrimrPix.app ./TrimrPix.app
```

#### 4. Notarization
```bash
# Create zip for notarization
ditto -c -k --keepParent TrimrPix.app TrimrPix.zip

# Submit for notarization
xcrun notarytool submit TrimrPix.zip --apple-id "your-email@example.com" --password "app-specific-password" --team-id "YOUR_TEAM_ID" --wait

# Staple the notarization
xcrun stapler staple TrimrPix.app
```

#### 5. Create DMG for Distribution
```bash
# Create DMG
hdiutil create -volname "TrimrPix" -srcfolder TrimrPix.app -ov -format UDZO TrimrPix.dmg
```

#### 6. GitHub Release
1. Go to GitHub repository
2. Create new release
3. Upload DMG file
4. Add release notes
5. Publish release

---

## 📋 Checklist

### App Store Ready
- [ ] Apple Developer Account
- [ ] App Store Connect app created
- [ ] Screenshots prepared
- [ ] App description written
- [ ] Privacy policy created
- [ ] App icon (1024x1024)
- [ ] Code signed and archived
- [ ] Uploaded to App Store Connect
- [ ] Submitted for review

### Direct Distribution Ready
- [ ] Developer ID certificate
- [ ] App code signed
- [ ] Notarized by Apple
- [ ] DMG created
- [ ] GitHub release published
- [ ] Download instructions added to README

---

## 🔧 Troubleshooting

### Common Issues
1. **Code Signing Errors**
   - Ensure certificates are valid
   - Check bundle identifier matches
   - Verify provisioning profiles

2. **Notarization Failures**
   - Check app for malware
   - Ensure all libraries are signed
   - Verify hardened runtime is enabled

3. **App Store Rejection**
   - Address all feedback
   - Test on different macOS versions
   - Ensure compliance with guidelines

---

## 📞 Support

For distribution issues:
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [GitHub Issues](https://github.com/JarlLyng/TrimrPix/issues)
