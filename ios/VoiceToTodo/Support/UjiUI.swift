import Foundation

/// Persiapan untuk uji UI otomatis (VoiceToTodoUITests). Hanya ada di build Debug dan hanya aktif dengan
/// argumen `-ujiUI`, jadi aplikasi rilis tidak terpengaruh.
///
/// Data aplikasi di Simulator dikosongkan, lalu bila variabel `UJI_AUDIO` berisi path file WAV, file itu disalin
/// ke folder rekaman. Saat dibuka, aplikasi memulihkannya sebagai rekaman yang bisa diproses dengan "Coba lagi".
/// Bila variabel `UJI_DATA` berisi JSON data aplikasi, isinya dipakai sebagai data awal (tanpa proses AI).
enum UjiUI {
    static func siapkanBilaDiminta() {
        #if DEBUG
        guard CommandLine.arguments.contains("-ujiUI") else { return }
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fm.removeItem(at: docs.appendingPathComponent("voice-to-todo.json"))
        try? fm.removeItem(at: docs.appendingPathComponent("Recordings"))
        if let json = ProcessInfo.processInfo.environment["UJI_DATA"] {
            try? Data(json.utf8).write(to: docs.appendingPathComponent("voice-to-todo.json"))
        }
        if let path = ProcessInfo.processInfo.environment["UJI_AUDIO"], fm.fileExists(atPath: path) {
            let folder = docs.appendingPathComponent("Recordings", isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? fm.copyItem(at: URL(fileURLWithPath: path), to: folder.appendingPathComponent("uji.wav"))
        }
        #endif
    }
}
