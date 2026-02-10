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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            HStack {
                Image("CowIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(DesignTokens.Colors.primary(for: colorScheme))
                Text("TrimrPix")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                
                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Watch folder status
                    if viewModel.isWatchFolderActive {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(DesignTokens.Colors.States.success)
                            Text("Watch Folder")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.States.success)
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
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Drag images here to optimize")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    Text("Supported formats: JPEG, PNG, GIF, WebP, AVIF")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
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
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(minWidth: 600, minHeight: 400)
        .background(DesignTokens.Colors.backgroundApp(for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .strokeBorder(
                    isHighlighted 
                        ? DesignTokens.Colors.primary(for: colorScheme)
                        : DesignTokens.Colors.borderSubtle(for: colorScheme),
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                .background(DesignTokens.Colors.backgroundMuted(for: colorScheme))
                .cornerRadius(DesignTokens.Radius.md)
            
            VStack {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: DesignTokens.Typography.Size.xl))
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                Text("Drop images here")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme
    
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
                        .cornerRadius(DesignTokens.Radius.sm)
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Colors.backgroundMuted(for: colorScheme))
                        .frame(width: 60, height: 60)
                        .onAppear {
                            // Load thumbnail when view appears
                            var mutableImage = image
                            thumbnail = mutableImage.thumbnail
                        }
                }
                
                // Filinfo
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(image.filename)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Original: \(image.originalSize.formattedSize)")
                            .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                        
                        if let optimizedSize = image.optimizedSize {
                            Text("→")
                                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                            Text("Optimized: \(optimizedSize.formattedSize)")
                                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                            Text("(\(image.savingsPercentage)% reduction)")
                                .foregroundStyle(DesignTokens.Colors.States.success)
                                .fontWeight(DesignTokens.Typography.Weight.semibold)
                        }
                    }
                    .font(DesignTokens.Typography.subheadline)
                }
                
                Spacer()
                
                // Status and actions
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Remove button
                    Button(action: {
                        viewModel.removeImage(id: image.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
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
                            .foregroundStyle(DesignTokens.Colors.States.success)
                            .font(.system(size: DesignTokens.Typography.Size.xl))
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
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }
}

#Preview {
    ContentView()
}
