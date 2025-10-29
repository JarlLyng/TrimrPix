# TrimrPix

[![macOS](https://img.shields.io/badge/macOS-15.2+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<img src="Screenshots/app_screenshot.png" width="600" alt="TrimrPix Screenshot">

## 📋 Description
TrimrPix is a macOS app built with SwiftUI, focusing on high-quality image compression with a simple user interface. The goal is to offer a modern and efficient image optimization solution with the same core functionality as [ImageOptim](https://github.com/ImageOptim/ImageOptim), but with newer technology and optimized performance.

## ✨ Features

### 🖼️ Image Processing
- **High-quality compression** with focus on optimal file size reduction
- **Multi-format support:** JPEG, PNG, GIF, WebP, and AVIF
- **Smart compression:** JPEG with configurable quality (60%-95%)
- **Format validation:** Ensures file integrity before processing

### 🎯 User Experience
- **Drag & Drop Interface** for intuitive image addition
- **Batch processing** with concurrent optimization for speed
- **Individual optimization** for single images
- **Real-time feedback:** Before/after file size and percentage reduction
- **Auto-save functionality** - saves optimized images in the same folder as originals
- **Manual save option** for custom file locations

### ⚙️ Advanced Features
- **Compression presets:** Low (60%), Medium (80%), High (95%), Custom
- **Watch Folder:** Automatically processes new images added to a monitored folder
- **Settings panel** with comprehensive customization options
- **Overwrite protection:** Option to overwrite originals or create new files
- **Error handling** with user-friendly error messages and recovery

## 🛠️ Technologies
- **SwiftUI** – Modern UI development for macOS
- **Core Image** – Image processing and compression
- **NSBitmapImageRep** – Efficient image compression with quality control
- **Async/Await** – Modern Swift concurrency for responsive UI during image processing

## ⚙️ Architecture

### 🏗️ Design Patterns
- **MVVM Architecture:** Clean separation of concerns with Model-View-ViewModel pattern
- **Sandboxed App:** Secure file system access with proper entitlements
- **Async/Await:** Modern Swift concurrency for responsive UI and background processing

### 🔧 Core Components
- **Models:** Data structures for images, settings, and application state
- **Views:** SwiftUI-based user interface with reactive updates
- **ViewModels:** Business logic coordination and data flow management
- **Services:** Specialized classes for compression and file system monitoring

### 🛡️ Security & Performance
- **File System Protection:** Sandboxed environment with controlled file access
- **Memory Management:** Efficient image processing with proper resource cleanup
- **Concurrent Processing:** Background optimization with UI responsiveness

## 📁 Project Structure
```
TrimrPix/
├── TrimrPixApp.swift       # App entry point
├── ContentView.swift       # Main view with UI components
├── Models/
│   ├── ImageItem.swift     # Data model for images
│   └── Settings.swift      # User settings and preferences
├── ViewModels/
│   └── ImageOptimizationViewModel.swift  # Handles image optimization
├── Views/
│   └── SettingsView.swift  # Settings panel UI
├── Services/
│   ├── CompressionService.swift  # Image compression logic
│   └── WatchFolderService.swift  # Watch folder monitoring
├── Assets.xcassets/        # App icons and assets
└── TrimrPix.entitlements   # App sandboxing and permissions
```

## 🔧 Technical Implementation

### 🖱️ User Interface
- **Drag & Drop:** SwiftUI's `.onDrop` modifier with UTType support
- **Reactive UI:** Real-time updates with `@Published` properties and `@StateObject`
- **Settings Panel:** Comprehensive configuration with persistent storage

### 🖼️ Image Processing
- **JPEG:** Configurable quality compression (60%-95%) via NSBitmapImageRep
- **PNG:** Optimized compression with default settings
- **GIF:** Format validation and safe copying (no compression in MVP)
- **WebP:** Format validation and copying (macOS limitation)
- **AVIF:** Format validation and copying (macOS limitation)

### ⚡ Performance & Concurrency
- **Async/Await:** Modern Swift concurrency for non-blocking operations
- **TaskGroup:** Concurrent batch processing for improved performance
- **@MainActor:** Thread-safe UI updates
- **Memory Management:** Efficient resource handling with proper cleanup

### 📁 File Management
- **Auto-save:** Automatic saving in same folder as originals
- **Manual Save:** Optional user-controlled file placement
- **Watch Folder:** Real-time file system monitoring with debouncing
- **Sandboxing:** Secure file access with proper entitlements

## 📖 Installation & Usage

### 🚀 Quick Start
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
- **GIF Processing:** Limited to validation and copying (no compression in MVP)
- **WebP/AVIF:** Format validation only due to macOS NSBitmapImageRep limitations
- **macOS Version:** Requires macOS 15.2 or newer
- **Watch Folder:** Requires manual folder selection in settings

## 🚀 Future Roadmap

### 🎯 Planned Features
- **Enhanced Compression:**
  - True WebP/AVIF compression with external libraries
  - SVG optimization with SVGO integration
  - HEIC format support
  - Advanced PNG optimization

### 🔧 UI/UX Improvements
- **Visual Enhancements:**
  - Before/after image preview
  - Progress tracking for large batches
  - Dark mode optimization
- **Workflow Features:**
  - Batch job system for large quantities
  - Scheduled optimization tasks
  - Export/import settings profiles

### 🏗️ Technical Improvements
- **Performance:**
  - GPU-accelerated compression
  - Memory usage optimization
  - Background processing improvements
- **Integration:**
  - Finder context menu integration
  - Command-line interface
  - API for third-party apps

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

- **Issues:** [GitHub Issues](https://github.com/jarllyng/TrimrPix/issues)
- **Discussions:** [GitHub Discussions](https://github.com/jarllyng/TrimrPix/discussions)

## 📢 License

MIT License – Free to use and adapt.

---

**Made with ❤️ for the macOS community**