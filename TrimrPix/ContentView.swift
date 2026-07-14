//
//  ContentView.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import IAMJARLDesignTokens
import PhosphorSwift

/// Main content view for the TrimrPix application
/// Uses IAMJARL Design System: DesignTokens.Common, Spacing, Radius, ColorToken.State
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
                    .frame(width: 24, height: 24)
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                Text("TrimrPix")
                    .font(.trimrPixTitle)
                    .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                Spacer()

                HStack(spacing: DesignTokens.Spacing.md) {
                    if viewModel.isWatchFolderActive {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Ph.eye.fill
                                .color(DesignTokens.ColorToken.State.success)
                                .frame(width: 20, height: 20)
                                .aspectRatio(contentMode: .fit)
                            Text("Watch Folder")
                                .font(.trimrPixCaption)
                                .foregroundStyle(DesignTokens.ColorToken.State.success)
                        }
                    }

                    Button(action: { showSettings = true }) {
                        Ph.gear.regular
                            .color(DesignTokens.Common.Text.primary(colorScheme))
                            .frame(width: 24, height: 24)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(.borderless)
                }
            }

            DropZoneView(viewModel: viewModel)

            if viewModel.images.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Drag images here to optimize")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                    Text("Supported formats: JPEG, PNG, GIF, WebP, AVIF, HEIC")
                        .font(.trimrPixSubheadline)
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ImageListView(viewModel: viewModel)
            }

            HStack {
                Button(action: { viewModel.clearImages() }) {
                    Text("Clear All")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.ColorToken.State.onError)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(DesignTokens.ColorToken.State.error)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.images.isEmpty)

                Spacer()

                if let progress = viewModel.batchProgress {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                            .progressViewStyle(.linear)
                            .frame(width: 160)
                        Text("\(progress.completed) of \(progress.total)")
                            .font(.trimrPixCaption)
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                    }

                    Spacer()
                }

                Button(action: { viewModel.optimizeAllImages() }) {
                    Text("Optimize All")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(DesignTokens.Common.primary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.images.isEmpty || viewModel.isOptimizing)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(minWidth: 600, minHeight: 400)
        .background(DesignTokens.Common.Background.app(colorScheme))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear { viewModel.startWatchFolder() }
        .onDisappear { viewModel.stopWatchFolder() }
    }
}

/// Drag and drop zone – border and background from design tokens
struct DropZoneView: View {
    @ObservedObject var viewModel: ImageOptimizationViewModel
    @State private var isHighlighted = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .strokeBorder(
                    isHighlighted
                        ? DesignTokens.Common.primary(colorScheme)
                        : DesignTokens.Common.Border.subtle(colorScheme),
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                .background(DesignTokens.Common.Background.muted(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

            VStack {
                Ph.downloadSimple.regular
                    .color(DesignTokens.Common.Text.primary(colorScheme))
                    .frame(width: 24, height: 24)
                    .aspectRatio(contentMode: .fit)
                Text("Drop images here")
                    .font(.trimrPixHeadline)
                    .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            }
        }
        .frame(height: 120)
        .onDrop(of: [UTType.image.identifier], isTargeted: $isHighlighted) { providers in
            Task { await viewModel.handleDrop(providers: providers) }
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
    let imageId: UUID
    @ObservedObject var viewModel: ImageOptimizationViewModel
    @State private var thumbnail: CGImage?
    @Environment(\.colorScheme) private var colorScheme

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
                if let cgImage = thumbnail {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Common.Background.muted(colorScheme))
                        .frame(width: 60, height: 60)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(image.filename)
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Original: \(image.originalSize.formattedSize)")
                            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

                        if let optimizedSize = image.optimizedSize {
                            Text("→")
                                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                            Text("Optimized: \(optimizedSize.formattedSize)")
                                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                            Text("(\(image.savingsPercentage)% reduction)")
                                .foregroundStyle(DesignTokens.ColorToken.State.success)
                                .fontWeight(DesignTokens.Typography.Weight.semibold)
                        }
                    }
                    .font(.trimrPixSubheadline)
                }

                Spacer()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button(action: { viewModel.removeImage(id: image.id) }) {
                        Ph.xCircle.fill
                            .color(DesignTokens.Common.Text.secondary(colorScheme))
                            .frame(width: 20, height: 20)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove image from list")
                    .disabled(image.isOptimizing)

                    if image.isOptimizing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if image.isOptimized {
                        Ph.checkCircle.fill
                            .color(DesignTokens.ColorToken.State.success)
                            .frame(width: 24, height: 24)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Button("Optimize") {
                            if let index = viewModel.images.firstIndex(where: { $0.id == image.id }) {
                                Task { await viewModel.optimizeImage(at: index) }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Common.primary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                        .disabled(image.isOptimizing || image.isOptimized)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .task(id: imageId) {
                // Generate the thumbnail off the main actor, decoded at preview size,
                // so large photos never block the UI or occupy full-resolution memory.
                if thumbnail == nil {
                    thumbnail = await ImageItem.loadThumbnail(from: image.url)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif
