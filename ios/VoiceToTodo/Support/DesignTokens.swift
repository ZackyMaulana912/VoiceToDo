import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static let appBackground = Color(hex: 0xF8FAFC)
    static let ink = Color(hex: 0x0F172A)
    static let mutedInk = Color(hex: 0x64748B)
    static let brand = Color(hex: 0x4F46E5)
    static let border = Color(hex: 0xE2E8F0)
    static let recordingRed = Color(hex: 0xE5484D)
}

extension Font {
    /// Huruf Inter yang ikut membesar mengikuti ukuran teks di Pengaturan (Dynamic Type, CLAUDE.md 5.7).
    /// Ukuran desain Figma dipakai sebagai ukuran dasar; gaya teks acuan dipilih dari ukurannya.
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<14: return .footnote
        case ..<17: return .body
        case ..<20: return .headline
        case ..<30: return .title2
        default: return .largeTitle
        }
    }
}
