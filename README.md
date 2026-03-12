# TrimrPix

[![macOS](https://img.shields.io/badge/macOS-15.2+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<img src="App store images/Screenshots/screenshot-1.png" width="600" alt="TrimrPix Screenshot">

## 📋 Description
TrimrPix is a macOS app built with SwiftUI, focusing on high-quality image compression with a simple user interface. The goal is to offer a modern and efficient image optimization solution with the same core functionality as [ImageOptim](https://github.com/ImageOptim/ImageOptim), but with newer technology and optimized performance.

## ✨ Features

### 🖼️ Image Processing
- **High-quality compression** with focus on optimal file size reduction
- **Multi-format support:** JPEG, PNG, GIF, WebP, AVIF, and HEIC
- **Smart compression:** Configurable quality (60%-95%) for JPEG, WebP, AVIF, and HEIC
- **Advanced PNG optimization:** Alpha channel stripping for opaque images
- **Format validation:** Ensures file integrity before processing

### 🎯 User Experience
- **Drag & Drop Interface** for intuitive image addition
- **Batch processing** with concurrent optimization
- **Individual optimization** with per-image controls
- **Real-time feedback:** File size comparison and percentage reduction
- **Auto-save:** Saves optimized images in the same folder as originals (default)
- **Manual save:** Fallback to save dialog when folder access is restricted
- **Individual removal:** Remove single images from the list

### ⚙️ Advanced Features
- **Compression presets:** Low (60%), Medium (80%), High (95%), Custom
- **Watch Folder:** Automatically processes new images with configurable delay (0.5-10s)
- **Settings panel:** Compression quality, save options, and watch folder configuration
- **Overwrite protection:** Option to overwrite originals or create new files
- **Smart file naming:** Automatically handles filename conflicts with unique naming
- **Error handling:** User-friendly messages with recovery suggestions

## 🛠️ Technologies
- **SwiftUI** – Modern UI development for macOS
- **Core Image** – Image processing and compression
- **ImageIO / CGImageDestination** – Native WebP, AVIF, and HEIC compression
- **NSBitmapImageRep** – Efficient JPEG/PNG compression with quality control
- **Async/Await** – Modern Swift concurrency for responsive UI during image processing
- **OSLog** – Unified logging system for debugging and monitoring
- **Protocol-Oriented Design** – Dependency injection and testability

## ⚙️ Architecture

TrimrPix følger MVVM-arkitektur med protocol-orienteret design. Se [ARCHITECTURE.md](ARCHITECTURE.md) for detaljeret dokumentation.

**Nøgleprincipper:**
- MVVM med klar separation of concerns
- Protocol-based dependency injection
- Security-scoped resource access for sandboxing
- Async/await for concurrent processing
- Centraliseret error handling og logging

## 📁 Project Structure
```
TrimrPix/
├── TrimrPixApp.swift              # App entry point
├── ContentView.swift              # Main view with UI components
├── Models/
│   ├── ImageItem.swift            # Image data model with lazy thumbnails
│   ├── Settings.swift             # User settings and preferences
│   └── TrimrPixError.swift       # Centralized error types
├── ViewModels/
│   └── ImageOptimizationViewModel.swift  # Business logic coordination
├── Views/
│   └── SettingsView.swift         # Settings panel UI
├── Services/
│   ├── CompressionService.swift   # Image compression with security-scoped access
│   ├── WatchFolderService.swift   # File system monitoring
│   ├── Logger.swift               # Structured logging service
│   └── Protocols.swift            # Service protocol definitions
└── Assets.xcassets/               # App icons and assets
```

## 🔧 Technical Details

- **File Type Detection:** UTType-based format identification
- **Security-Scoped Resources:** Automatic handling of sandboxed file access
- **Filename Conflicts:** Automatic unique naming (e.g., `image-optimized-2.png`)
- **Memory Optimization:** Lazy-loaded thumbnails resized to max 120px
- **Concurrent Processing:** TaskGroup-based batch optimization
- **Error Handling:** Detailed error messages with recovery suggestions

## 📖 Installation & Usage

### 🚀 Quick Start

#### Option 1: App Store (Recommended)
- **Get TrimrPix on the Mac App Store:** [apps.apple.com/app/trimrpix/id6758639590](https://apps.apple.com/app/trimrpix/id6758639590)  
- One-time purchase. Requires macOS 15.2 or later.

#### Option 2: Build from Source
1. **Clone the repository:**
   ```bash
   git clone https://github.com/jarllyng/TrimrPix.git
   cd TrimrPix
   ```

2. **Open in Xcode:**
   ```bash
   open TrimrPix.xcodeproj
   ```

3. **Build and run:**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

#### Option 3: Command Line Build
```bash
# Clone and build
git clone https://github.com/jarllyng/TrimrPix.git
cd TrimrPix
./build.sh
```

### 📋 Requirements
- **macOS:** 15.2 or newer
- **Xcode:** 15.0 or newer
- **Swift:** 5.9 or newer

### 🎯 How to Use
1. **Add Images:** Drag and drop images onto the app window
2. **Optimize:** Click "Optimize All" or optimize individual images
3. **Configure:** Use the settings panel (gear icon) to customize compression
4. **Watch Folder:** Enable automatic processing of new images in a folder

## 🔍 Known Limitations
- **GIF Processing:** Validation and copying only (no compression)
- **AVIF:** Depends on macOS system support — falls back to original data if unavailable
- **macOS Version:** Requires macOS 15.2 or newer
- **Sandboxing:** May require save dialog for folders without explicit access

## 🚀 Future Roadmap

### 🎯 Planned Features
- **Enhanced Compression:**
  - SVG optimization
  - GIF compression
- **UI/UX:**
  - Before/after image preview
  - Progress tracking for large batches
- **Integration:**
  - Finder context menu integration
  - Command-line interface

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### 🐛 Bug Reports
If you find a bug, please open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### 💡 Feature Requests
Have an idea for a new feature? Open an issue and let's discuss it!

## 📞 Support

- **Website & support:** [trimrpix.iamjarl.com](https://trimrpix.iamjarl.com/)
- **App Store:** [TrimrPix on the App Store](https://apps.apple.com/app/trimrpix/id6758639590)
- **Source & issues:** [GitHub](https://github.com/JarlLyng/TrimrPix) (for developers)

## 📢 License

MIT License – Free to use and adapt.

---

**Made with ❤️ for the macOS community**