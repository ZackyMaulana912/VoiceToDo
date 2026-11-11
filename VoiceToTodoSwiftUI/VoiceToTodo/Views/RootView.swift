import SwiftUI

struct RootView: View {
    private enum Screen: Equatable {
        case home, recording, history
        case detail(UUID)
    }

    @StateObject private var store = AppStore()
    @StateObject private var recorder = SpeechRecorder()
    @State private var screen: Screen = .home
    @State private var permissionMessage: String?

    private var selectedTab: MainTab {
        switch screen {
        case .history, .detail: return .history
        default: return .home
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                content
                if screen != .recording {
                    BottomNavView(selected: selectedTab) { tab in
                        store.dismissResultBanner()
                        screen = tab == .home ? .home : .history
                    }
                }
            }
        }
        .environmentObject(store)
        .alert("Izin dibutuhkan", isPresented: Binding(
            get: { permissionMessage != nil },
            set: { if !$0 { permissionMessage = nil } }
        )) {
            Button("Buka Pengaturan") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text(permissionMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .home:
            HomeView(onRecord: startRecording)
        case .recording:
            RecordingView(
                recorder: recorder,
                onCancel: { screen = .home },
                onFinish: { audio in
                    store.finishRecording(audio)
                    screen = .home
                }
            )
        case .history:
            HistoryView { screen = .detail($0) }
        case .detail(let id):
            DetailView(
                recordingID: id,
                onBack: { screen = .history },
                onRetry: {
                    store.retry(id)
                    screen = .home
                }
            )
        }
    }

    private func startRecording() {
        Task {
            switch await SpeechRecorder.requestPermissions() {
            case .granted:
                screen = .recording
            case .denied(let message):
                permissionMessage = message
            }
        }
    }
}
