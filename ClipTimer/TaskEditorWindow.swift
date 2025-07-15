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
    @FocusState private var isTextEditorFocused: Bool

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
            loadExistingTasks()
            // Focus the text editor so it can receive key events
            isTextEditorFocused = true
            // Pause active task when editor opens
            store.pauseActiveTask()
        }
        .onDisappear {
            // Restart paused task when editor closes
            store.restartLastPausedTask()
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
                .focusable()
                .focused($isTextEditorFocused)
            
            // Placeholder text - only show when no tasks exist and text is empty
            if tasksText.isEmpty && store.tasks.isEmpty {
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
            if store.tasks.isEmpty {
                // When no tasks exist, only show add button
                Button {
                    commitTasks(replacing: false)
                } label: {
                    Text("Add tasks (⌘⏎)", comment: "Button to add new tasks")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                // When tasks exist - single update button
                Button {
                    commitTasks(replacing: true)
                } label: {
                    Text("Update tasks (⌘⏎)", comment: "Button to update existing tasks")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load existing tasks into the editor when window opens
    private func loadExistingTasks() {
        if !store.tasks.isEmpty {
            // Load existing tasks with their current times
            tasksText = generateTasksText()
        } else {
            // Clear text when no tasks exist
            tasksText = ""
        }
    }
    
    /// Generate formatted text representation of current tasks
    private func generateTasksText() -> String {
        return store.tasks.map { task in
            let currentElapsed = task.currentElapsed(activeTaskID: store.activeTaskID, startTime: store.activeTaskStartTime)
            return "\(store.itemSymbol)\(task.name): \(currentElapsed.hms)"
        }.joined(separator: "\n")
    }

    /// Adds or replaces tasks based on `replacing` parameter.
    private func commitTasks(replacing: Bool) {
        let trimmedText = tasksText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if replacing {
            store.replaceTasks(from: trimmedText)
        } else {
            store.addTasks(from: trimmedText)
        }
        
        // Restart the previously paused task after updating
        store.restartLastPausedTask()
        
        dismiss()
    }
}

#if DEBUG
#Preview {
    TaskEditorWindow()
        .environmentObject(TaskStore())
}
#endif 
