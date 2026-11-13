import SwiftUI

struct RootView: View {
    private enum Screen: Equatable {
        case home, recording, history
        case detail(UUID)
    }

    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = SpeechRecorder()
    @State private var screen: Screen = .home
    @State private var permissionMessage: String?
    /// Pesan saat rekaman berhenti sendiri (telepon masuk, layar dikunci, dll.).
    @State private var stopNotice: String?

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
                    .overlay(alignment: .top) {
                        // Di atas, supaya tidak menutupi tombol rekam di bawah.
                        if let offer = store.undoOffer, screen != .recording {
                            UndoBar(offer: offer, onUndo: { withAnimation(.easeInOut(duration: 0.2)) { store.undo() } }) {
                                withAnimation(.easeInOut(duration: 0.2)) { store.expireUndo(offer.id) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .alert("Rekaman dihentikan", isPresented: Binding(
                        get: { stopNotice != nil },
                        set: { if !$0 { stopNotice = nil } }
                    )) {
                        Button("Oke", role: .cancel) {}
                    } message: {
                        Text(stopNotice ?? "")
                    }
                if screen != .recording {
                    BottomNavView(selected: selectedTab) { tab in
                        store.dismissResultBanner()
                        screen = tab == .home ? .home : .history
                    }
                }
            }
            .alert(store.problem?.title ?? "", isPresented: Binding(
                get: { store.problem != nil },
                set: { if !$0 { store.problem = nil } }
            )) {
                Button("Oke", role: .cancel) {}
            } message: {
                Text(store.problem?.message ?? "")
            }
        }
        .environmentObject(store)
        .onChange(of: scenePhase) { _, phase in
            // iOS tidak mengizinkan proses AI berat di latar belakang (CLAUDE.md 5.1).
            if phase == .background { store.interruptProcessing() }
        }
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
                    if let note = audio.stopNote {
                        stopNotice = note + " Bagian yang sudah terekam (\(Formatters.duration(audio.duration))) tetap disimpan dan diproses."
                    }
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
