import SwiftUI
import VoiceToTodoCore

struct ChipView: View {
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.inter(13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .frame(minHeight: 26)
            .background(background)
            .clipShape(Capsule())
    }
}

struct CategoryChip: View {
    let category: TodoCategory
    var body: some View {
        ChipView(title: category.title, foreground: category.foreground, background: category.background)
    }
}

struct DueChip: View {
    let label: LabelTenggat.Hasil
    var body: some View {
        if label.terlambat {
            ChipView(title: label.teks, foreground: Color(hex: 0xB91C1C), background: Color(hex: 0xFEF2F2))
        } else {
            ChipView(title: label.teks, foreground: Color(hex: 0x475569), background: Color(hex: 0xF1F5F9))
        }
    }
}

struct StatusChip: View {
    let status: RecordingStatus
    var body: some View {
        ChipView(title: status.label, foreground: status.foreground, background: status.background)
    }
}

struct CheckboxView: View {
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Color.brand : Color.white)
                    .frame(width: 24, height: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isOn ? Color.brand : Color(hex: 0x94A3B8), lineWidth: 2)
                    }
                if isOn {
                    Image("check")
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension View {
    /// Tekan lama sebuah to-do untuk memunculkan menu edit dan hapus. Juga bisa lewat aksi VoiceOver.
    func todoMenu(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        self
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
            .contextMenu {
                Button(action: onEdit) {
                    Label("Edit to-do", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Hapus to-do", systemImage: "trash")
                }
            }
            .accessibilityAction(named: "Edit to-do", onEdit)
            .accessibilityAction(named: "Hapus to-do", onDelete)
    }

    /// Lembar isian untuk mengubah teks to-do. `editing` berisi to-do yang sedang diubah.
    func todoEditSheet(_ editing: Binding<TodoItem?>, onSave: @escaping (UUID, String) -> Void) -> some View {
        sheet(item: editing) { item in
            TodoFormView(heading: "Edit to-do", initialText: item.title) { text, _ in onSave(item.id, text) }
        }
    }

    /// Lembar isian untuk menulis to-do baru beserta kategorinya.
    func todoAddSheet(isPresented: Binding<Bool>, onSave: @escaping (String, TodoCategory) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            TodoFormView(heading: "Tambah to-do", initialText: "", asksCategory: true, onSave: onSave)
        }
    }

    /// Konfirmasi sebelum to-do dihapus. `pending` berisi to-do yang menunggu jawaban.
    func confirmTodoDelete(_ pending: Binding<TodoItem?>, onConfirm: @escaping (UUID) -> Void) -> some View {
        confirmationDialog(
            "Hapus to-do ini?",
            isPresented: Binding(get: { pending.wrappedValue != nil }, set: { if !$0 { pending.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { item in
            Button("Hapus to-do", role: .destructive) { onConfirm(item.id) }
            Button("Batal", role: .cancel) {}
        } message: { item in
            Text("\u{201C}\(item.title)\u{201D} akan dihapus. Kamu masih bisa mengurungkannya beberapa detik setelahnya.")
        }
    }
}

/// Kartu isian satu baris teks untuk to-do (CLAUDE.md 5.7: "Edit / Tambah to-do").
struct TodoFormView: View {
    let heading: String
    let initialText: String
    /// True saat menambah to-do baru: kategori dipilih sendiri. Saat edit, kategori tidak diubah.
    var asksCategory = false
    let onSave: (String, TodoCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category: TodoCategory = .rapat
    @FocusState private var focused: Bool

    private var cleaned: String? { AppStore.cleanTodoTitle(text) }
    private var length: Int { text.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var tooLong: Bool { length > AppStore.maxTodoLength }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.inter(18, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(.top, 8)

            TextField("Contoh: Kirim laporan rapat ke Bu Rina", text: $text, axis: .vertical)
                .font(.inter(16))
                .foregroundStyle(Color.ink)
                .lineLimit(2...6)
                .focused($focused)
                .padding(12)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tooLong ? Color(hex: 0xDC2626) : Color.brand, lineWidth: 1)
                }
                .accessibilityLabel("Teks to-do")

            if tooLong {
                Text("Maksimal \(AppStore.maxTodoLength) karakter (sekarang \(length)).")
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color(hex: 0xB91C1C))
            }

            if asksCategory {
                Text("Kategori")
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
                HStack(spacing: 8) {
                    ForEach(TodoCategory.allCases, id: \.self) { option in
                        Button { category = option } label: {
                            Text(option.title)
                                .font(.inter(13, weight: .medium))
                                .foregroundStyle(option.foreground)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(option.background)
                                .overlay {
                                    Capsule().stroke(option.foreground, lineWidth: category == option ? 1.5 : 0)
                                }
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category == option ? .isSelected : [])
                    }
                }
            }

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Batal")
                        .font(.inter(16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.white)
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1) }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    guard let cleaned else { return }
                    onSave(cleaned, category)
                    dismiss()
                } label: {
                    Text("Simpan")
                        .font(.inter(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(cleaned == nil)
                .opacity(cleaned == nil ? 0.5 : 1)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
        .presentationDetents([.medium])
        .onAppear {
            text = initialText
            focused = true
        }
    }
}

struct TodoCardView: View {
    let item: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CheckboxView(
                isOn: item.isDone,
                label: item.isDone ? "Tandai belum selesai" : "Tandai selesai",
                action: onToggle
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.inter(16))
                    .foregroundStyle(Color.ink)
                    .strikethrough(item.isDone)
                    .opacity(item.isDone ? 0.64 : 1)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)

                HStack(spacing: 8) {
                    CategoryChip(category: item.category)
                    if let due = item.dueLabel() { DueChip(label: due) }
                }

                Text(item.source)
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 3)
        .padding(.trailing, 21)
        .padding(.top, 15)
        .padding(.bottom, 17)
        .cardStyle()
    }
}

struct ResultCardView: View {
    let recording: Recording
    let todos: [TodoItem]
    let onToggle: (UUID) -> Void
    let onSummaryChange: (String) -> Void
    /// Dipanggil saat pengguna memilih "Edit to-do" atau "Hapus to-do" dari menu tekan lama.
    var onEditTodo: ((TodoItem) -> Void)? = nil
    var onDeleteTodo: ((TodoItem) -> Void)? = nil

    @State private var isEditing = false
    /// Salinan ringkasan selama diedit. Baru disimpan saat menekan Simpan; Batal membuangnya.
    @State private var draft = ""
    @State private var copied = false

    private var draftIsEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CategoryChip(category: recording.category)

            if isEditing {
                TextEditor(text: $draft)
                    .font(.inter(16))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .padding(6)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(draftIsEmpty ? Color(hex: 0xDC2626) : Color.brand, lineWidth: 1) }
                    .accessibilityLabel("Ringkasan")
                if draftIsEmpty {
                    Text("Ringkasan tidak boleh kosong.")
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Color(hex: 0xB91C1C))
                }
            } else {
                Text(recording.summary)
                    .font(.inter(16))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(5)
            }

            if !recording.points.isEmpty {
                Text("Poin penting")
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recording.points, id: \.self) { point in
                        Text("• \(point)")
                            .font(.inter(16))
                            .foregroundStyle(Color.ink)
                            .lineSpacing(5)
                    }
                }
            }

            if !todos.isEmpty {
                Text("To-do dari rekaman")
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(todos) { todo in
                        HStack(alignment: .top, spacing: 4) {
                            CheckboxView(isOn: todo.isDone, label: todo.isDone ? "Tandai belum selesai" : "Tandai selesai") { onToggle(todo.id) }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(todo.title)
                                    .font(.inter(16))
                                    .foregroundStyle(Color.ink)
                                    .strikethrough(todo.isDone)
                                    .opacity(todo.isDone ? 0.64 : 1)
                                    .lineSpacing(5)
                                // Tenggat juga tampil di kartu hasil, bukan hanya di daftar Beranda.
                                if let due = todo.dueLabel() { DueChip(label: due) }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
                        }
                        .background(Color.white)
                        .todoMenu(onEdit: { onEditTodo?(todo) }, onDelete: { onDeleteTodo?(todo) })
                    }
                }
            }

            HStack(spacing: 16) {
                if isEditing {
                    actionButton(title: "Batal", icon: nil) { isEditing = false }
                    actionButton(title: "Simpan", icon: "edit", action: saveDraft)
                        .disabled(draftIsEmpty)
                        .opacity(draftIsEmpty ? 0.5 : 1)
                } else {
                    actionButton(title: copied ? "Tersalin" : "Salin", icon: "copy", action: copy)
                    actionButton(title: "Edit", icon: "edit") {
                        draft = recording.summary
                        isEditing = true
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private func saveDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if text != recording.summary { onSummaryChange(text) }
        isEditing = false
    }

    private func actionButton(title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(icon).frame(width: 20, height: 20).accessibilityHidden(true) }
                Text(title).font(.inter(13, weight: .medium))
            }
            .foregroundStyle(Color.brand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func copy() {
        var lines = [recording.summary]
        if !recording.points.isEmpty {
            lines += ["", "Poin penting"] + recording.points.map { "• \($0)" }
        }
        if !todos.isEmpty {
            lines += ["", "To-do dari rekaman"] + todos.map { "- \($0.title)" }
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
    }
}

struct ProcessingCardView: View {
    let duration: String
    /// Teks tahap yang sedang berjalan, atau nil bila rekaman masih menunggu giliran.
    let stage: String?
    @State private var angle = 0.0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("spinner")
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                    .rotationEffect(.degrees(angle))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage ?? "Menunggu giliran...")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Text("Rekaman \(duration). Jangan tutup aplikasi sampai selesai.")
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Color.mutedInk)
                }
            }
            .frame(minHeight: 48, alignment: .top)

            ForEach([16.0, 44.0, 102.0], id: \.self) { trailing in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: 0xF1F5F9))
                    .frame(height: 12)
                    .padding(.trailing, trailing)
                    .opacity(pulse ? 0.5 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
        .onAppear {
            guard !reduceMotion else { return } // "Kurangi gerakan": ikon dan kerangka diam
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { angle = 360 }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FailedCardView: View {
    let message: String
    /// Nil bila "Coba lagi" tidak bisa membantu (misalnya file audio sudah tidak ada).
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("warn").frame(width: 24, height: 24).padding(.top, 2).accessibilityHidden(true)
                Text(message)
                    .font(.inter(16, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onRetry {
                Button(action: onRetry) {
                    Text("Coba lagi")
                        .font(.inter(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

/// Bar kecil "To-do dihapus · Urungkan" yang muncul sebentar setelah aksi yang bisa dibatalkan.
struct UndoBar: View {
    let offer: AppStore.UndoOffer
    let onUndo: () -> Void
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(offer.message)
                .font(.inter(16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                Text("Urungkan")
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC7D2FE))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .task(id: offer.id) {
            // Pengguna VoiceOver butuh waktu lebih lama untuk mencapai tombolnya.
            let voiceOver = UIAccessibility.isVoiceOverRunning
            if voiceOver {
                UIAccessibility.post(notification: .announcement, argument: "\(offer.message). Tombol Urungkan tersedia.")
            }
            try? await Task.sleep(nanoseconds: (voiceOver ? 10 : 5) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image("emptymic")
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                .frame(width: 104, height: 104)
                .background(Color(hex: 0xEEF2FF))
                .clipShape(Circle())
            Text(title)
                .font(.inter(18, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.inter(16))
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }
}

struct RecordAreaView: View {
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onRecord) {
                Image("mic")
                    .frame(width: 24, height: 24)
                    .frame(width: 72, height: 72)
                    .background(Color.recordingRed)
                    .clipShape(Circle())
                    .shadow(color: Color.recordingRed.opacity(0.18), radius: 3, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mulai merekam")

            Text("Ketuk untuk merekam")
                .font(.inter(13, weight: .medium))
                .foregroundStyle(Color.mutedInk)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

enum MainTab { case home, history }

struct BottomNavView: View {
    let selected: MainTab
    let onSelect: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            item("Beranda", image: "home", tab: .home)
            item("Riwayat", image: "history", tab: .history)
        }
        .padding(.horizontal, 15)
        .padding(.top, 5)
        .frame(minHeight: 71, alignment: .top)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.border).frame(height: 1) }
    }

    private func item(_ title: String, image: String, tab: MainTab) -> some View {
        let isSelected = selected == tab
        return Button { onSelect(tab) } label: {
            VStack(spacing: 6) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(title).font(.inter(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.brand : Color.mutedInk)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab-\(title.lowercased())")
    }
}

extension View {
    func cardStyle() -> some View {
        background(Color.white)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
