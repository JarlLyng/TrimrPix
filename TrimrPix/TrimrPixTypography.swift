//
//  TrimrPixTypography.swift
//  TrimrPix
//
//  Font helpers using only IAMJARL Design System typography tokens.
//  design.md: semibold for headings, regular for body.
//

import SwiftUI
import IAMJARLDesignTokens

extension Font {
    /// Title – 36pt bold (DesignTokens.Typography.Size.xxl, Weight.bold)
    static var trimrPixTitle: Font {
        .system(size: DesignTokens.Typography.Size.xxl, weight: DesignTokens.Typography.Weight.bold)
    }
    /// Title 2 – 24pt semibold
    static var trimrPixTitle2: Font {
        .system(size: DesignTokens.Typography.Size.xl, weight: DesignTokens.Typography.Weight.semibold)
    }
    /// Headline – 16pt semibold
    static var trimrPixHeadline: Font {
        .system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold)
    }
    /// Body – 16pt regular
    static var trimrPixBody: Font {
        .system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.regular)
    }
    /// Subheadline – 14pt regular
    static var trimrPixSubheadline: Font {
        .system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.regular)
    }
    /// Caption – 12pt regular
    static var trimrPixCaption: Font {
        .system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular)
    }
}
