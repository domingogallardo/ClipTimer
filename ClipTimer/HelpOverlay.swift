//  HelpOverlay.swift
//  ClipTimer
//
//  Slide-in panel that lists keyboard shortcuts.
//  Place this file alongside your other SwiftUI views and
//  follow the integration notes at the end of this file.

import SwiftUI

// MARK: - Model

struct Shortcut: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let description: String
}

// MARK: - Help overlay view

struct HelpOverlay: View {
    private let shortcuts: [Shortcut] = [
        .init(key: "⌘C", description: "Copy task summary"),
        .init(key: "⌘V", description: "Paste tasks (replace)"),
        .init(key: "⇧⌘V", description: "Paste tasks (append)"),
        .init(key: "⌘X", description: "Cut"),
        .init(key: "⌘Z", description: "Undo"),
        .init(key: "⇧⌘Z", description: "Redo"),
        .init(key: "⌘P", description: "Pause active task"),
        .init(key: "⌘R", description: "Restart last paused task")
    ]

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

            // Shortcuts list
            ForEach(shortcuts) { pair in
                HStack {
                    Text(pair.key)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Spacer(minLength: 16)
                    Text(pair.description)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: 280, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .trailing))
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    HelpOverlay()
}
#endif
