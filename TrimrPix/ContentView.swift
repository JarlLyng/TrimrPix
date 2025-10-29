//
//  ContentView.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI
import UniformTypeIdentifiers

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

struct ImageItemView: View {
    let image: ImageItem
    @ObservedObject var viewModel: ImageOptimizationViewModel
    
    var body: some View {
        HStack {
            // Thumbnail
            if let nsImage = image.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
            }
            
            // Filinfo
            VStack(alignment: .leading) {
                Text(image.filename)
                    .font(.headline)
                
                HStack {
                    Text("Original: \(image.originalSize.formattedSize)")
                    
                    if let optimizedSize = image.optimizedSize {
                        Text("→")
                        Text("Optimized: \(optimizedSize.formattedSize)")
                        Text("(\(image.savingsPercentage)% reduction)")
                            .foregroundColor(.green)
                    }
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // Status
            if image.isOptimizing {
                ProgressView()
            } else if image.isOptimized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
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
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
