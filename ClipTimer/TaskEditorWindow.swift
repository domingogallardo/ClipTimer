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
    @Environment(\.presentationMode) var presentationMode
    @State private var tasksText: String = ""
    @State private var showSuccessMessage: Bool = false
    
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
        .frame(width: 500, height: 400)
        .onAppear {
            setupInitialText()
        }
    }
}

private extension TaskEditorWindow {
    
    @ViewBuilder
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Editor")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Write or paste your tasks here, one per line. Format: 'Task name' or 'Task name: 1:30:45'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }
    
    @ViewBuilder
    var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tasks:")
                    .font(.headline)
                
                Spacer()
                
                if showSuccessMessage {
                    Label("Tasks added successfully!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
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
            Button("Clear") {
                tasksText = ""
            }
            .buttonStyle(.plain)
            
            Button("Copy Current Tasks") {
                copySummaryToClipboard()
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Add Tasks") {
                addTasksFromText()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(tasksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialText() {
        // Pre-populate with current tasks if any
        if !store.tasks.isEmpty {
            tasksText = store.tasks.map { task in
                let elapsed = task.currentElapsed(activeTaskID: store.activeTaskID, startTime: store.activeTaskStartTime)
                return "\(task.name): \(elapsed.hms)"
            }.joined(separator: "\n")
        }
    }
    
    private func addTasksFromText() {
        // Use the existing TaskStore functionality to parse and add tasks
        let lines = tasksText.split(separator: "\n").map { String($0) }
        
        // Temporarily put the text in clipboard to use existing functionality
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tasksText, forType: .string)
        
        // Use existing add tasks from clipboard functionality
        store.addTasksFromClipboard()
        
        // Show success message
        showSuccessMessage = true
        
        // Hide success message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessMessage = false
        }
    }
    
    private func copySummaryToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.summaryText, forType: .string)
    }
}

#if DEBUG
#Preview {
    TaskEditorWindow()
        .environmentObject(TaskStore())
}
#endif 