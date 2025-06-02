//  HelpOverlay.swift
//  ClipTimer

import SwiftUI

// MARK: - Model

struct Shortcut: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let description: String
}

// MARK: - Reusable row

private struct ShortcutRow: View {
    var shortcut: Shortcut

    var body: some View {
        HStack {
            Text(shortcut.key)
                .font(.system(.body, design: .monospaced).weight(.semibold))
            Spacer(minLength: 16)
            Text(shortcut.description)
        }
    }
}

// MARK: - Help overlay view

struct HelpOverlay: View {
    // Shortcut groups ------------------------------------------------------
    private let taskShortcuts: [Shortcut] = [
        .init(key: "⌘V",    description: "Paste tasks (replace)"),
        .init(key: "⇧⌘V",   description: "Paste tasks (append)"),
        .init(key: "Right-click", description: "Delete task")
    ]

    private let timerShortcuts: [Shortcut] = [
        .init(key: "⌘P", description: "Pause active task"),
        .init(key: "⌘R", description: "Restart last paused task")
    ]

    private let exportShortcuts: [Shortcut] = [
        .init(key: "⌘C", description: "Copy tasks with times")
    ]

    private let undoShortcuts: [Shortcut] = [
        .init(key: "⌘Z",  description: "Undo"),
        .init(key: "⇧⌘Z", description: "Redo")
    ]

    // Helper to render a titled section
    @ViewBuilder
    private func section(title: String, _ shortcuts: [Shortcut]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(shortcuts) { ShortcutRow(shortcut: $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.title2)
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
            }
            .padding(.bottom, 4)

            section(title: "Tasks Management", taskShortcuts)
            section(title: "Timer Controls", timerShortcuts)
            section(title: "Export Tasks", exportShortcuts)
            section(title: "Undo / Redo", undoShortcuts)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 320, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .trailing))
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    HelpOverlay()
        .frame(width: 320, height: 480)
}
#endif
