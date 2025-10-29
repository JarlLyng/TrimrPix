# Manual Build Guide for GitHub Distribution

Since you don't have an Apple Developer account yet, here's how to build and distribute TrimrPix via GitHub without code signing:

## 🚀 Quick Build (No Code Signing)

### Step 1: Open in Xcode
```bash
open TrimrPix.xcodeproj
```

### Step 2: Configure Build Settings
1. Select the **TrimrPix** project in the navigator
2. Select the **TrimrPix** target
3. Go to **Signing & Capabilities** tab
4. **Uncheck** "Automatically manage signing"
5. Set **Team** to "None" (or leave empty)
6. Set **Bundle Identifier** to something unique like `com.yourname.trimrpix`

### Step 3: Build the App
1. Select **Any Mac (Designed for Mac)** as the destination
2. Press **Cmd + B** to build
3. Wait for build to complete

### Step 4: Find the Built App
1. In Xcode, go to **Product** → **Show Build Folder in Finder**
2. Navigate to: `Build/Products/Debug/TrimrPix.app`
3. Copy `TrimrPix.app` to your desktop

### Step 5: Create DMG for Distribution
```bash
# Create DMG (run this in Terminal)
hdiutil create -volname "TrimrPix" -srcfolder ~/Desktop/TrimrPix.app -ov -format UDZO ~/Desktop/TrimrPix.dmg
```

## 📦 Create GitHub Release

### Step 1: Go to GitHub
1. Go to `https://github.com/JarlLyng/TrimrPix`
2. Click **Releases** tab
3. Click **Create a new release**

### Step 2: Fill Release Information
- **Tag version:** `v1.0.0`
- **Release title:** `TrimrPix v1.0.0 - First Release`
- **Description:**
```markdown
## 🎉 First Release of TrimrPix!

### ✨ Features
- High-quality image compression
- Support for JPEG, PNG, GIF, WebP, AVIF
- Drag & Drop interface
- Batch processing
- Individual image optimization
- Auto-save functionality
- Watch Folder monitoring
- Compression presets
- Settings panel

### 📋 Installation
1. Download `TrimrPix.dmg`
2. Open the DMG file
3. Drag TrimrPix to Applications folder
4. Open TrimrPix from Applications

### ⚠️ Note
This is an unsigned build. You may need to:
1. Right-click the app → "Open"
2. Click "Open" in the security dialog
3. Or go to System Preferences → Security & Privacy → Allow

### 🐛 Known Issues
- App is not notarized (will show security warning)
- Some features may require additional permissions

### 🔧 Requirements
- macOS 15.2 or newer
- Intel or Apple Silicon Mac
```

### Step 3: Upload Files
1. Drag `TrimrPix.dmg` to the "Attach binaries" area
2. Click **Publish release**

## 🔧 Alternative: Build with Xcode Archive

If you want a more professional build:

### Step 1: Archive the App
1. In Xcode, select **Product** → **Archive**
2. Wait for archive to complete
3. In the Organizer window, click **Distribute App**
4. Select **Copy App**
5. Choose destination folder
6. Click **Export**

### Step 2: Create DMG
```bash
# Use the exported app
hdiutil create -volname "TrimrPix" -srcfolder /path/to/exported/TrimrPix.app -ov -format UDZO ~/Desktop/TrimrPix.dmg
```

## 🚨 Important Notes

### Security Warnings
- Unsigned apps will show security warnings
- Users need to right-click → "Open" the first time
- This is normal for apps without Developer ID

### Future Improvements
- Get Apple Developer account ($99/year)
- Code sign with Developer ID
- Notarize the app
- Users won't see security warnings

### Distribution Benefits
- ✅ Free distribution via GitHub
- ✅ No Apple review process
- ✅ Full control over releases
- ✅ Easy updates
- ⚠️ Security warnings for users
- ⚠️ Not notarized by Apple

## 📞 User Instructions

Add this to your README for users:

```markdown
### 🔒 Security Note
TrimrPix is not code-signed or notarized. To run the app:

1. Download the DMG from Releases
2. Open the DMG and drag TrimrPix to Applications
3. Right-click TrimrPix in Applications → "Open"
4. Click "Open" in the security dialog

Alternatively, go to System Preferences → Security & Privacy → General → Click "Open Anyway" next to TrimrPix.
```
