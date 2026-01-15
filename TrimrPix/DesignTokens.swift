//
//  DesignTokens.swift
//  TrimrPix
//
//  Created based on IAMJARL Design System v0.1.0
//  Source: https://jarllyng.github.io/iamjarl-design/tokens.json
//

import SwiftUI

/// Design tokens from IAMJARL Design System
/// Single source of truth for colors, spacing, typography, and radius
/// Supports both light and dark mode
struct DesignTokens {
    
    // MARK: - Colors
    
    struct Colors {
        // Static colors (use sparingly)
        static let black = Color(hex: "#000000")
        static let white = Color(hex: "#FFFFFF")
        
        // Shared state colors
        struct States {
            static let success = Color(hex: "#4CAF50")
            static let warning = Color(hex: "#FF6B35")
            static let error = Color(hex: "#FF3B30")
        }
        
        // Mode-specific colors
        struct Light {
            static let primary = Color(hex: "#00FF7B")
            
            struct Text {
                static let primary = Color(hex: "#000000")
                static let secondary = Color(hex: "#000000").opacity(0.70)
                static let tertiary = Color(hex: "#000000").opacity(0.55)
                static let inverse = Color(hex: "#FFFFFF")
            }
            
            struct Background {
                static let app = Color(hex: "#FFFFFF")
                static let muted = Color(hex: "#000000").opacity(0.04)
                static let card = Color(hex: "#000000").opacity(0.04)
            }
            
            struct Surface {
                static let `default` = Color(hex: "#FFFFFF")
                static let raised = Color(hex: "#000000").opacity(0.02)
            }
            
            struct Border {
                static let subtle = Color(hex: "#000000").opacity(0.10)
                static let `default` = Color(hex: "#000000").opacity(0.16)
            }
        }
        
        struct Dark {
            static let primary = Color(hex: "#D0FF00")
            
            struct Text {
                static let primary = Color(hex: "#FFFFFF")
                static let secondary = Color(hex: "#FFFFFF").opacity(0.75)
                static let tertiary = Color(hex: "#FFFFFF").opacity(0.60)
                static let inverse = Color(hex: "#000000")
            }
            
            struct Background {
                static let app = Color(hex: "#000000")
                static let muted = Color(hex: "#FFFFFF").opacity(0.05)
                static let card = Color(hex: "#FFFFFF").opacity(0.05)
            }
            
            struct Surface {
                static let `default` = Color(hex: "#000000")
                static let raised = Color(hex: "#FFFFFF").opacity(0.03)
            }
            
            struct Border {
                static let subtle = Color(hex: "#FFFFFF").opacity(0.12)
                static let `default` = Color(hex: "#FFFFFF").opacity(0.18)
            }
        }
        
        // Dynamic colors that adapt to color scheme
        // Use these in views with @Environment(\.colorScheme)
        static func primary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.primary : Light.primary
        }
        
        static func textPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Text.primary : Light.Text.primary
        }
        
        static func textSecondary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Text.secondary : Light.Text.secondary
        }
        
        static func textTertiary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Text.tertiary : Light.Text.tertiary
        }
        
        static func textInverse(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Text.inverse : Light.Text.inverse
        }
        
        static func backgroundApp(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Background.app : Light.Background.app
        }
        
        static func backgroundMuted(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Background.muted : Light.Background.muted
        }
        
        static func backgroundCard(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Background.card : Light.Background.card
        }
        
        static func surfaceDefault(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Surface.default : Light.Surface.default
        }
        
        static func surfaceRaised(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Surface.raised : Light.Surface.raised
        }
        
        static func borderSubtle(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Border.subtle : Light.Border.subtle
        }
        
        static func borderDefault(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Dark.Border.default : Light.Border.default
        }
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Radius
    
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Font families
        static let uiFont = "system-ui"
        static let monoFont = "ui-monospace"
        
        // Font weights
        struct Weight {
            static let regular: Font.Weight = .regular
            static let semibold: Font.Weight = .semibold
            static let bold: Font.Weight = .bold
        }
        
        // Font sizes
        struct Size {
            static let xs: CGFloat = 12
            static let sm: CGFloat = 14
            static let base: CGFloat = 16
            static let lg: CGFloat = 18
            static let xl: CGFloat = 24
            static let xxl: CGFloat = 36
        }
        
        // Line heights
        struct LineHeight {
            static let tight: CGFloat = 20
            static let normal: CGFloat = 24
            static let relaxed: CGFloat = 28
            static let xxl: CGFloat = 43.2
            static let sm: CGFloat = 18
        }
        
        // Convenience font styles
        static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        
        static var title: Font {
            font(size: Size.xxl, weight: Weight.bold)
        }
        
        static var title2: Font {
            font(size: Size.xl, weight: Weight.semibold)
        }
        
        static var headline: Font {
            font(size: Size.base, weight: Weight.semibold)
        }
        
        static var body: Font {
            font(size: Size.base, weight: Weight.regular)
        }
        
        static var subheadline: Font {
            font(size: Size.sm, weight: Weight.regular)
        }
        
        static var caption: Font {
            font(size: Size.xs, weight: Weight.regular)
        }
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

