//
//  TaskEditorWindow.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI
import AppKit

struct TaskEditorWindow: View {
    @EnvironmentObject private var store: TaskStore
    @State private var tasksText: String = ""
    @Environment(\.dismiss) private var dismiss

    // Size constants to avoid magic numbers
    private static let editorWidth: CGFloat = 380
    private static let editorHeight: CGFloat = 250
    
    var body: some View {
        VStack(spacing: 16) {
            // Text editor area
            textEditor
            
            // Action buttons
            actionButtons
        }
        .padding(20)
        .frame(
            minWidth: Self.editorWidth, idealWidth: Self.editorWidth, maxWidth: Self.editorWidth,
            minHeight: Self.editorHeight, idealHeight: Self.editorHeight, maxHeight: Self.editorHeight
        )
        .onAppear {
            // Clear text every time the window opens
            tasksText = ""
        }
    }
}

private extension TaskEditorWindow {
    @ViewBuilder
    var textEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $tasksText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 180)
            
            // Placeholder text
            if tasksText.isEmpty {
                Text("- Task 1\n- Task 2: 1:30:00")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .allowsHitTesting(false)
            }
        }
    }
    
    @ViewBuilder
    var actionButtons: some View {
        HStack {
            Button {
                commitTasks(replacing: false)
            } label: {
                Text("Add tasks (⇧⌘⏎)", comment: "Button to add new tasks to existing ones")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button {
                commitTasks(replacing: true)
            } label: {
                Text("Replace tasks (⌘⏎)", comment: "Button to replace all tasks with new ones")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - Helper Methods

    /// Adds or replaces tasks based on `replacing` parameter.
    private func commitTasks(replacing: Bool) {
        let trimmedText = tasksText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if replacing {
            store.replaceTasks(from: trimmedText)
        } else {
            store.addTasks(from: trimmedText)
        }
        
        dismiss()
    }
}

#if DEBUG
#Preview {
    TaskEditorWindow()
        .environmentObject(TaskStore())
}
#endif 
