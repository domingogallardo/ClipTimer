//
//  ClipTimerApp.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI

// MARK: - AppDelegate for handling app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    var taskStore: TaskStore?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable automatic window tabbing for single-window app
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        taskStore?.pauseActiveTaskAndSave()
    }
}

@main
struct ClipTimerApp: App {
    @StateObject private var store = TaskStore()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Function to handle paste command based on active window
    private func handlePasteCommand() {
        // Check which window is currently active
        guard let keyWindow = NSApp.keyWindow else {
            // If no key window, default to main window behavior
            store.replaceTasksFromClipboard()
            return
        }
        
        // Check if the active window is the task editor
        if keyWindow.identifier?.rawValue == "task-editor" {
            // For task editor window, we need to send the paste event to the focused text editor
            // This will be handled by the TextEditor's native paste functionality
            keyWindow.firstResponder?.tryToPerform(#selector(NSText.paste(_:)), with: nil)
        } else {
            // For main window or other windows, use the normal behavior
            store.replaceTasksFromClipboard()
        }
    }
    
    // Function to handle copy command based on active window
    private func handleCopyCommand() {
        // Check which window is currently active
        guard let keyWindow = NSApp.keyWindow else {
            // If no key window, default to main window behavior
            store.copySummaryToClipboard()
            return
        }
        
        // Check if the active window is the task editor
        if keyWindow.identifier?.rawValue == "task-editor" {
            // For task editor window, we need to send the copy event to the focused text editor
            // This will be handled by the TextEditor's native copy functionality
            keyWindow.firstResponder?.tryToPerform(#selector(NSText.copy(_:)), with: nil)
        } else {
            // For main window or other windows, use the normal behavior
            store.copySummaryToClipboard()
        }
    }
    
    // Function to handle cut command based on active window
    private func handleCutCommand() {
        // Check which window is currently active
        guard let keyWindow = NSApp.keyWindow else {
            // If no key window, default to main window behavior
            store.cutAllTasks()
            return
        }
        
        // Check if the active window is the task editor
        if keyWindow.identifier?.rawValue == "task-editor" {
            // For task editor window, we need to send the cut event to the focused text editor
            // This will be handled by the TextEditor's native cut functionality
            keyWindow.firstResponder?.tryToPerform(#selector(NSText.cut(_:)), with: nil)
        } else {
            // For main window or other windows, use the normal behavior
            store.cutAllTasks()
        }
    }

    var body: some Scene {
        Window("ClipTimer", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(
                    minWidth: 380, idealWidth: 380,
                    minHeight: 540, idealHeight: 540
                ).onAppear {
                    // Center window on screen when app launches
                    NSApp.windows.first?.center()
                    // Connect TaskStore to AppDelegate for termination handling
                    appDelegate.taskStore = store
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 540)
        .commands {
            CommandGroup(replacing: .help) {
                Button("ClipTimer Help") {
                    openWindow(id: "help")
                }
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Cut all tasks") {
                    handleCutCommand()
                }
                .keyboardShortcut("x")
                
                Button("Paste tasks (replace)") {
                    handlePasteCommand()
                }
                .keyboardShortcut("v")

                Button("Paste tasks (append)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift])

                Divider()

                Button("Copy tasks with times") {
                    handleCopyCommand()
                }
                .keyboardShortcut("c")                     
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.keyWindow?.undoManager?.undo()
                }
                .keyboardShortcut("z")
                
                Button("Redo") {
                    NSApp.keyWindow?.undoManager?.redo()
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
            }

            CommandMenu("Timer") {
                Button("Pause active task") {
                    store.pauseActiveTask()
                }
                .keyboardShortcut("p")
                Button("Restart last paused task") {
                    store.restartLastPausedTask()
                }
                .keyboardShortcut("r")
            }
            

        }
        // Help window
        Window("ClipTimer Help", id: "help") {
            HelpWindow()
        }
        .defaultSize(width: 540, height: 540)
        
        // Task Editor window
        Window("Task Editor", id: "task-editor") {
            TaskEditorWindow()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 250)
        .keyboardShortcut("e", modifiers: .command)

        // Menu bar timer display with context menu
        MenuBarExtra {
            Button("Copy tasks with times") {
                store.copySummaryToClipboard()
            }
            Divider()
            Button("Open main window") {
                // Find and restore main window or create new one
                if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    if win.isMiniaturized {
                        win.deminiaturize(nil)
                    }
                    win.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)

                } else {
                    openWindow(id: "main")
                }
            }
        } label: {
            Text(store.totalElapsed.hms(showSecondsColon: store.showColons))
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 6)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .frame(width: 380, height: 540)
}
