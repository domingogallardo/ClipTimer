//  HelpOverlay.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI

struct HelpOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.title2)
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
            }
            .padding(.bottom, 4)

            Text("Tasks Management")
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 4)
            HStack {
                Text("⌘V")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Paste tasks (replace)")
            }
            .padding(.leading, 12)
            HStack {
                Text("⇧⌘V")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Paste tasks (append)")
            }
            .padding(.leading, 12)
            HStack {
                Text("Right-click")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Delete task")
            }
            .padding(.leading, 12)
            Text("Timer Controls")
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 4)
            HStack {
                Text("⌘P")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Pause active task")
            }
            .padding(.leading, 12)
            HStack {
                Text("⌘R")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Restart last paused task")
            }
            .padding(.leading, 12)

            Text("Export Tasks")
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 4)
            HStack {
                Text("⌘C")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Copy tasks with times")
            }
            .padding(.leading, 12)
            HStack {
                Text("⌘X")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Cut tasks with times")
            }
            .padding(.leading, 12)
            
            Text("Undo / Redo")
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 4)
            HStack {
                Text("⌘Z")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Undo")
            }
            .padding(.leading, 12)
            HStack {
                Text("⇧⌘Z")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer(minLength: 16)
                Text("Redo")
            }
            .padding(.leading, 12)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 320, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .trailing))
    }
}

#if DEBUG
struct HelpOverlay_Previews: PreviewProvider {
    static var previews: some View {
        HelpOverlay()
            .frame(width: 320, height: 540)
    }
}
#endif
