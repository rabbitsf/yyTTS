//
//  ThemeManager.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI
import UIKit

struct AppTheme {
    // Primary gradient colors - light orange for navigation bar
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.85, blue: 0.7), Color(red: 1.0, green: 0.9, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color(red: 0.9, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.7, blue: 0.4), Color(red: 1.0, green: 0.8, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.4, green: 0.9, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Solid colors
    static let primaryColor = Color(red: 1.0, green: 0.87, blue: 0.75)
    static let secondaryColor = Color(red: 0.95, green: 0.5, blue: 0.25)
    static let accentColor = Color(red: 1.0, green: 0.75, blue: 0.45)
    static let folderColor = Color(red: 1.0, green: 0.65, blue: 0.3)  // Orange color for folder icon
    static let fileColor = Color(red: 1.0, green: 0.7, blue: 0.4)
    
    // Background gradients - use system background that adapts automatically
    static var backgroundGradient: LinearGradient {
        // Use system background colors that adapt to light/dark mode
        #if os(iOS)
        return LinearGradient(
            colors: [
                Color(UIColor.systemBackground),
                Color(UIColor.secondarySystemBackground),
                Color(UIColor.tertiarySystemBackground),
                Color(UIColor.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #else
        return LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.9, blue: 0.8),
                Color(red: 1.0, green: 0.92, blue: 0.85),
                Color(red: 1.0, green: 0.95, blue: 0.9),
                Color(red: 1.0, green: 0.97, blue: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #endif
    }
    
    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.9),
            Color(red: 1.0, green: 0.98, blue: 0.95).opacity(0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Text colors - adaptive for light/dark mode
    static var primaryText: Color {
        // Use UIColor which has better dark mode support, then convert to Color
        #if os(iOS)
        return Color(UIColor.label) // Automatically adapts: black in light mode, white in dark mode
        #else
        return Color.primary
        #endif
    }
    static var secondaryText: Color {
        #if os(iOS)
        return Color(UIColor.secondaryLabel) // Automatically adapts to light/dark mode
        #else
        return Color.secondary
        #endif
    }
}

extension View {
    func primaryButton() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.primaryGradient)
            .cornerRadius(12)
            .shadow(color: AppTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func secondaryButton() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.secondaryGradient)
            .cornerRadius(12)
            .shadow(color: AppTheme.secondaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func accentButton() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.accentGradient)
            .cornerRadius(12)
            .shadow(color: AppTheme.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func colorfulCard() -> some View {
        self
            .background(AppTheme.cardGradient)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

