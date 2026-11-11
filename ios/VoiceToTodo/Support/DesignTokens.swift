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
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", fixedSize: size).weight(weight)
    }
}
