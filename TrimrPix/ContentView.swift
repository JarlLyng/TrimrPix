//
//  ContentView.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main content view for the TrimrPix application
/// Provides the primary user interface for image optimization
/// Includes drag & drop support, image list, and optimization controls
struct ContentView: View {
    @StateObject private var viewModel = ImageOptimizationViewModel()
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "photo.stack")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("TrimrPix")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Watch folder status
                    if viewModel.isWatchFolderActive {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.green)
                            Text("Watch Folder")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Drag & Drop område
            DropZoneView(viewModel: viewModel)
            
            // Billedeliste
            if viewModel.images.isEmpty {
                VStack(spacing: 10) {
                    Text("Drag images here to optimize")
                        .font(.headline)
                    Text("Supported formats: JPEG, PNG, GIF, WebP, AVIF")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ImageListView(viewModel: viewModel)
            }
            
            // Knapper
            HStack {
                Button(action: {
                    viewModel.clearImages()
                }) {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(viewModel.images.isEmpty)
                
                Spacer()
                
                Button(action: {
                    viewModel.optimizeAllImages()
                }) {
                    Label("Optimize All", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.images.isEmpty || viewModel.isOptimizing)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            viewModel.startWatchFolder()
        }
        .onDisappear {
            viewModel.stopWatchFolder()
        }
    }
}

/// Drag and drop zone view for accepting image files
/// Provides visual feedback when files are dragged over the drop zone
struct DropZoneView: View {
    @ObservedObject var viewModel: ImageOptimizationViewModel
    @State private var isHighlighted = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHighlighted ? Color.accentColor : Color.gray,
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            
            VStack {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 24))
                Text("Drop images here")
                    .font(.headline)
            }
        }
        .frame(height: 120)
        .onDrop(of: [UTType.image.identifier], isTargeted: $isHighlighted) { providers in
            Task {
                await viewModel.handleDrop(providers: providers)
            }
            return true
        }
    }
}

/// List view displaying all images loaded for optimization
/// Shows thumbnails, file sizes, and optimization status for each image
struct ImageListView: View {
    @ObservedObject var viewModel: ImageOptimizationViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.images) { image in
                ImageItemView(image: image, viewModel: viewModel)
            }
        }
        .listStyle(.plain)
    }
}

/// Individual image item view within the list
/// Displays thumbnail, filename, file sizes, and optimization controls
/// Shows progress indicator during optimization and checkmark when complete
struct ImageItemView: View {
    let imageId: UUID
    @ObservedObject var viewModel: ImageOptimizationViewModel
    @State private var thumbnail: NSImage?
    
    // Computed property to get current image from viewModel
    private var image: ImageItem? {
        viewModel.images.first(where: { $0.id == imageId })
    }
    
    init(image: ImageItem, viewModel: ImageOptimizationViewModel) {
        self.imageId = image.id
        self.viewModel = viewModel
        self._thumbnail = State(initialValue: nil)
    }
    
    var body: some View {
        if let image = image {
            HStack {
                // Thumbnail (lazy loaded)
                if let nsImage = thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .onAppear {
                            // Load thumbnail when view appears
                            var mutableImage = image
                            thumbnail = mutableImage.thumbnail
                        }
                }
                
                // Filinfo
                VStack(alignment: .leading, spacing: 4) {
                    Text(image.filename)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text("Original: \(image.originalSize.formattedSize)")
                            .foregroundColor(.secondary)
                        
                        if let optimizedSize = image.optimizedSize {
                            Text("→")
                                .foregroundColor(.secondary)
                            Text("Optimized: \(optimizedSize.formattedSize)")
                                .foregroundColor(.primary)
                            Text("(\(image.savingsPercentage)% reduction)")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                    .font(.subheadline)
                }
                
                Spacer()
                
                // Status and actions
                HStack(spacing: 8) {
                    // Remove button
                    Button(action: {
                        viewModel.removeImage(id: image.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove image from list")
                    .disabled(image.isOptimizing)
                    
                    // Status or optimize button
                    if image.isOptimizing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if image.isOptimized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button("Optimize") {
                            if let index = viewModel.images.firstIndex(where: { $0.id == image.id }) {
                                Task {
                                    await viewModel.optimizeImage(at: index)
                                }
                            }
                        }
                        .disabled(image.isOptimizing || image.isOptimized)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ContentView()
}
