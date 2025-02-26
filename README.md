# TrimrPix

<img src="Screenshots/app_screenshot.png" width="600" alt="TrimrPix Screenshot">

## 📋 Description
TrimrPix is a macOS app built with SwiftUI, focusing on high-quality image compression with a simple user interface. The goal is to offer a modern and efficient image optimization solution with the same core functionality as [ImageOptim](https://github.com/ImageOptim/ImageOptim), but with newer technology and optimized performance.

## ✨ Features
- **Image compression** with focus on high quality and reduced file size
- **Support for popular formats:** JPEG, PNG, and GIF (WebP and AVIF planned for future versions)
- **Drag & Drop Interface** for easy addition of images
- **Batch optimization** (optimize multiple images at once)
- **Visual feedback:** Before/after file size and percentage reduction
- **User-selected save location** for optimized images

## 🛠️ Technologies
- **SwiftUI** – Modern UI development for macOS
- **Core Image** – Image processing and compression
- **NSBitmapImageRep** – Efficient image compression with quality control
- **Async/Await** – Modern Swift concurrency for responsive UI during image processing

## ⚙️ Architecture
- **Sandboxed App:** The app is sandboxed to ensure file system protection. File access is handled via **NSOpenPanel** and **NSSavePanel**.
- **Compression Logic:** We use NSBitmapImageRep for image optimization with controlled quality.
- **File Writing:** Optimized images are saved as new files by default (e.g., `image-optimized.png`) to avoid data loss.
- **MVVM Architecture:** The app follows the Model-View-ViewModel pattern for clear separation of responsibilities:
  - **Models:** Represent image data and metadata
  - **Views:** Handle the user interface and interactions
  - **ViewModels:** Coordinate data flow and business logic

## 📁 Project Structure
```
TrimrPix/
├── TrimrPixApp.swift       # App entry point
├── ContentView.swift       # Main view with UI components
├── Models/
│   └── ImageItem.swift     # Data model for images
├── ViewModels/
│   └── ImageOptimizationViewModel.swift  # Handles image optimization
├── Services/
│   └── CompressionService.swift  # Image compression logic
├── Assets.xcassets/        # App icons and assets
└── TrimrPix.entitlements   # App sandboxing and permissions
```

## 🔧 Technical Implementation
- **Drag & Drop:** Implemented with SwiftUI's `.onDrop` modifier and UTType
- **Image Compression:**
  - JPEG: Compression with 80% quality for optimal balance between size and quality
  - PNG: Optimized with default settings via NSBitmapImageRep
  - GIF: Basic handling (copying in MVP)
- **Concurrency:** Uses Swift's modern async/await pattern with @MainActor for UI updates
- **File Handling:** NSSavePanel gives the user control over where optimized images are saved
- **Sandboxing:** Implemented with proper entitlements for secure file access

## 📖 Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/jarllyng/TrimrPix.git
   ```
2. Open the project in Xcode
3. Build and run the project on macOS

## 🔍 Known Limitations
- GIF optimization is limited to copying in the current version
- The app requires macOS 15.2 or newer
- Image optimization happens synchronously for each image, which may affect performance with large batches

## 🚀 Future Features
- **User Settings:**
  - Option to choose compression strength (low/medium/high)
  - Choice between overwriting original files or saving as new ones
  - Output folder settings
- **Extended Format Support:**
  - Support for WebP and AVIF
  - SVG optimization with SVGO
- **Automation:**
  - Watch-folder functionality (automatic optimization of new files in a folder)
  - Batch job system for larger quantities of files
- **Additional UI Improvements:**
  - Settings menu for configuration
  - Before/after image preview

## 📢 License
MIT License – Free to use and adapt.

---