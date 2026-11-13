import SwiftUI

@main
struct VoiceToTodoApp: App {
    /// Alat uji kelayakan AI (Fase 1) hanya dibuka dengan argumen peluncuran `-ujiKelayakan`.
    private let ujiKelayakan = CommandLine.arguments.contains("-ujiKelayakan")

    var body: some Scene {
        WindowGroup {
            if ujiKelayakan {
                UjiKelayakanView()
            } else {
                RootView()
            }
        }
    }
}
