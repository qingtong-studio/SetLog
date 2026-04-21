import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Orange Accent
    static let orange     = Color(hex: 0xFF7314)          // in-progress, tab active, primary accent
    static let orangeDeep = Color(hex: 0xFF6D00)          // gradient end, deeper accent
    static let orangeTint = Color(hex: 0xFFE8D6)          // tinted background
    static let orange12   = Color(hex: 0xFF7314, alpha: 0.12)

    // MARK: - Foreground
    static let fg1 = Color(hex: 0x1A1F2E)   // primary text
    static let fg2 = Color(hex: 0x4A515F)   // secondary text
    static let fg3 = Color(hex: 0x8A8F9A)   // tertiary / placeholder
    static let fg4 = Color(hex: 0xC5C9D0)   // disabled / divider

    // MARK: - Backgrounds & Fills
    static let bgCard     = Color(hex: 0xFFFFFF)
    static let fillSubtle = Color(hex: 0xF7F7FB)
    static let bgPage     = Color(hex: 0xF2F2F7)
    static let fillMedium = Color(hex: 0xEBEBF0)

    // MARK: - Semantic
    static let confirm  = Color(hex: 0x34C759)   // set-completed, positive confirm only
    static let danger   = Color(hex: 0xFF3B30)   // destructive – delete workout / template
    static let ctaFill  = Color(hex: 0x1A1F2E)   // primary CTA buttons (add, apply, copy)

    // MARK: - Legacy aliases (keeps existing call sites compiling)
    static let pageBackground  = bgPage
    static let cardBackground  = bgCard
    static let subtleFill      = fillSubtle
    static let cardBorder      = fg4.opacity(0.22)
    static let strong          = fg1
    static let invertedStrong  = Color.white
    static let accent          = orange
}

// MARK: - UIKit bridge (for UIView-based components)
extension AppTheme {
    static let uiOrange      = UIColor(hex: 0xFF7314)
    static let uiFillSubtle  = UIColor(hex: 0xF7F7FB)
    static let uiBgPage      = UIColor(hex: 0xF2F2F7)
    static let uiBgCard      = UIColor(hex: 0xFFFFFF)
    static let uiFillMedium  = UIColor(hex: 0xEBEBF0)
    static let uiFg1         = UIColor(hex: 0x1A1F2E)
    static let uiFg2         = UIColor(hex: 0x4A515F)
    static let uiFg3         = UIColor(hex: 0x8A8F9A)
    static let uiFg4         = UIColor(hex: 0xC5C9D0)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}
