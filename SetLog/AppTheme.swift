import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Orange Accent
    static let orange     = dynamic(light: 0xFF7314, dark: 0xFF8A3D)   // in-progress, tab active, primary accent
    static let orangeDeep = dynamic(light: 0xFF6D00, dark: 0xFF8533)   // gradient end, deeper accent
    static let orangeTint = dynamic(light: 0xFFE8D6, dark: 0x3A2815)   // tinted background
    static let orange12   = dynamic(light: 0xFF7314, dark: 0xFF8A3D, alpha: 0.18)

    // MARK: - Foreground (text)
    static let fg1 = dynamic(light: 0x1A1F2E, dark: 0xF4F5F8)   // primary text
    static let fg2 = dynamic(light: 0x4A515F, dark: 0xB8BDC7)   // secondary text
    static let fg3 = dynamic(light: 0x8A8F9A, dark: 0x8E929B)   // tertiary / placeholder
    static let fg4 = dynamic(light: 0xC5C9D0, dark: 0x4A4E57)   // disabled / divider

    // MARK: - Backgrounds & Fills
    static let bgCard     = dynamic(light: 0xFFFFFF, dark: 0x1C1D22)
    static let fillSubtle = dynamic(light: 0xF7F7FB, dark: 0x26272D)
    static let bgPage     = dynamic(light: 0xF2F2F7, dark: 0x111216)
    static let fillMedium = dynamic(light: 0xEBEBF0, dark: 0x2E3038)

    // MARK: - Semantic
    static let confirm  = dynamic(light: 0x34C759, dark: 0x3DD15E)   // set-completed, positive confirm only
    static let danger   = dynamic(light: 0xFF3B30, dark: 0xFF5A50)   // destructive – delete workout / template
    static let ctaFill  = dynamic(light: 0x1A1F2E, dark: 0xF4F5F8)   // primary CTA buttons (add, apply, copy)

    // MARK: - Legacy aliases (keeps existing call sites compiling)
    static let pageBackground  = bgPage
    static let cardBackground  = bgCard
    static let subtleFill      = fillSubtle
    static let cardBorder      = fg4.opacity(0.22)
    static let strong          = fg1
    static let invertedStrong  = dynamic(light: 0xFFFFFF, dark: 0x1A1F2E)
    static let accent          = orange

    private static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex).withAlphaComponent(alpha)
        })
    }

    // MARK: - RPE (Rate of Perceived Exertion) colors
    // 6: easy / warmup-ish, 7: ~3 reps in reserve, 8: ~2 RIR, 9: ~1 RIR, 10: failure
    static let rpeAmber = dynamic(light: 0xF2B01C, dark: 0xFFC949)
    static let rpeRed   = dynamic(light: 0xE53E3E, dark: 0xFF6B6B)

    static func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 6:  return AppTheme.fg2
        case 7:  return AppTheme.confirm
        case 8:  return AppTheme.rpeAmber
        case 9:  return AppTheme.orange
        case 10: return AppTheme.rpeRed
        default: return AppTheme.fg3
        }
    }
}

// MARK: - UIKit bridge (for UIView-based components)
extension AppTheme {
    static let uiOrange      = dynamicUIColor(light: 0xFF7314, dark: 0xFF8A3D)
    static let uiFillSubtle  = dynamicUIColor(light: 0xF7F7FB, dark: 0x26272D)
    static let uiBgPage      = dynamicUIColor(light: 0xF2F2F7, dark: 0x111216)
    static let uiBgCard      = dynamicUIColor(light: 0xFFFFFF, dark: 0x1C1D22)
    static let uiFillMedium  = dynamicUIColor(light: 0xEBEBF0, dark: 0x2E3038)
    static let uiFg1         = dynamicUIColor(light: 0x1A1F2E, dark: 0xF4F5F8)
    static let uiFg2         = dynamicUIColor(light: 0x4A515F, dark: 0xB8BDC7)
    static let uiFg3         = dynamicUIColor(light: 0x8A8F9A, dark: 0x8E929B)
    static let uiFg4         = dynamicUIColor(light: 0xC5C9D0, dark: 0x4A4E57)

    private static func dynamicUIColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
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
