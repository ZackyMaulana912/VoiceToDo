import UIKit

/// Menjaga layar tetap menyala selama ada yang membutuhkan (merekam atau memproses).
/// Layar baru boleh padam lagi setelah semua pemegang selesai, supaya selesainya rekaman tidak mematikan
/// layar saat rekaman lain masih diproses.
@MainActor
enum ScreenAwake {
    private static var holders = Set<String>()

    static func set(_ holder: String, _ on: Bool) {
        if on { holders.insert(holder) } else { holders.remove(holder) }
        UIApplication.shared.isIdleTimerDisabled = !holders.isEmpty
    }
}
