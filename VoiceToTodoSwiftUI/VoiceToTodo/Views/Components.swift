import SwiftUI

struct ChipView: View {
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.inter(13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(height: 26)
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
    let title: String
    var body: some View {
        ChipView(title: title, foreground: Color(hex: 0x475569), background: Color(hex: 0xF1F5F9))
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
                    if let due = item.due { DueChip(title: due) }
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

    @State private var isEditing = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CategoryChip(category: recording.category)

            if isEditing {
                TextEditor(text: Binding(get: { recording.summary }, set: onSummaryChange))
                    .font(.inter(16))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .padding(6)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.brand, lineWidth: 1) }
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
                            CheckboxView(isOn: todo.isDone, label: todo.title) { onToggle(todo.id) }
                            Text(todo.title)
                                .font(.inter(16))
                                .foregroundStyle(Color.ink)
                                .strikethrough(todo.isDone)
                                .opacity(todo.isDone ? 0.64 : 1)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                actionButton(title: copied ? "Tersalin" : "Salin", icon: "copy", action: copy)
                actionButton(title: isEditing ? "Simpan" : "Edit", icon: "edit") { isEditing.toggle() }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon).frame(width: 20, height: 20)
                Text(title).font(.inter(13, weight: .medium))
            }
            .foregroundStyle(Color.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
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
    @State private var angle = 0.0
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("spinner")
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(angle))
                    .padding(.top, 2)
                Text("Merangkum rekaman \(duration)...")
                    .font(.inter(16, weight: .medium))
                    .foregroundStyle(Color.ink)
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
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { angle = 360 }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FailedCardView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("warn").frame(width: 24, height: 24).padding(.top, 2)
                Text("Gagal memproses. Rekamanmu aman tersimpan.")
                    .font(.inter(16, weight: .medium))
                    .foregroundStyle(Color.ink)
            }
            Button(action: onRetry) {
                Text("Coba lagi")
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image("emptymic")
                .frame(width: 64, height: 64)
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
        .frame(height: 71, alignment: .top)
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
                Text(title).font(.inter(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.brand : Color.mutedInk)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func cardStyle() -> some View {
        background(Color.white)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
