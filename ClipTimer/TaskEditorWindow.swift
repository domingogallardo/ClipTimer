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
    // Tracks whether the editor itself paused a task when it opened
    @State private var didEditorPauseTask: Bool = false
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
        .background(WindowAccessor { window in
            positionWindowNextToMainWindow(window)
        })
        .onAppear {
            loadExistingTasks()
            // Focus the text editor so it can receive key events
            isTextEditorFocused = true
            // Pause active task when editor opens
            if store.activeTaskID != nil {
                // There's an active task, pause it and remember that we did so
                store.pauseActiveTask()
                didEditorPauseTask = true
            } else {
                // Editor did not pause anything
                didEditorPauseTask = false
            }
        }
        .onDisappear {
            // Restart only if the editor itself paused a task
            if didEditorPauseTask {
                store.restartLastPausedTask()
            }
        }
    }
}

private extension TaskEditorWindow {
    func positionWindowNextToMainWindow(_ window: NSWindow) {
        guard window.identifier?.rawValue == "task-editor" else { return }

        let mainWindow = NSApp.windows.first {
            $0.identifier?.rawValue == "main" && $0 !== window
        }
        let screen = mainWindow?.screen ?? window.screen ?? NSScreen.main
        guard let screen else { return }

        let visible = screen.visibleFrame
        let frame = window.frame
        let gap: CGFloat = 12

        if let mainWindow {
            let mainFrame = mainWindow.frame
            var origin = NSPoint(
                x: mainFrame.maxX + gap,
                y: mainFrame.maxY - frame.height
            )

            // If it doesn't fit to the right, place to the left of main window.
            if origin.x + frame.width > visible.maxX {
                origin.x = mainFrame.minX - frame.width - gap
            }

            // Clamp within visible area.
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)

            guard window.frame.origin != origin else { return }
            window.setFrameOrigin(origin)
        } else {
            let centered = NSPoint(
                x: visible.midX - (frame.width / 2),
                y: visible.midY - (frame.height / 2)
            )

            guard window.frame.origin != centered else { return }
            window.setFrameOrigin(centered)
        }
    }

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
            let name = task.isCompleted ? "~~\(task.name)~~" : task.name
            return "\(store.itemSymbol)\(name): \(currentElapsed.hms)"
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
        
        dismiss()
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.resolveWindow(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.resolveWindow(from: nsView)
    }

    final class Coordinator {
        private weak var resolvedWindow: NSWindow?
        private let onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
        }

        func resolveWindow(from view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard
                    let self,
                    let window = view?.window,
                    window !== self.resolvedWindow
                else {
                    return
                }

                self.resolvedWindow = window
                self.onResolve(window)
            }
        }
    }
}

#if DEBUG
#Preview {
    TaskEditorWindow()
        .environmentObject(TaskStore())
}
#endif 
