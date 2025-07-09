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

    // Tamaños constantes para evitar números mágicos
    private static let editorWidth: CGFloat = 380
    private static let editorHeight: CGFloat = 400
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            header
            
            // Text editor area
            textEditor
            
            // Action buttons
            actionButtons
        }
        .padding(20)
        .frame(width: Self.editorWidth, height: Self.editorHeight)
        .onAppear {
            // Clear text every time the window opens
            tasksText = ""
        }
    }
}

private extension TaskEditorWindow {
    
    @ViewBuilder
    var header: some View {
        Text("Write one task per line. Format: 'Task name' or 'Task name: 1:30:45'", comment: "Instructions for task editor format")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
    }
    
    @ViewBuilder
    var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks:", comment: "Label for tasks text area")
                .font(.headline)
            
            TextEditor(text: $tasksText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 200)
        }
    }
    
    @ViewBuilder
    var actionButtons: some View {
        HStack {
            Button {
                commitTasks(replacing: true)
            } label: {
                Text("Paste tasks (replace)", comment: "Button to replace all tasks with new ones")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button {
                commitTasks(replacing: false)
            } label: {
                Text("Paste tasks (append)", comment: "Button to add new tasks to existing ones")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - Helper Methods

    /// Agrega o reemplaza las tareas según `replacing`.
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
    
    // copySummary ya no es necesario
}

#if DEBUG
#Preview {
    TaskEditorWindow()
        .environmentObject(TaskStore())
}
#endif 