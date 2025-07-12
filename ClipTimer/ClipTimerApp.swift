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
    
    func applicationWillTerminate(_ notification: Notification) {
        taskStore?.pauseActiveTaskAndSave()
    }
}

@main
struct ClipTimerApp: App {
    @StateObject private var store = TaskStore()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("ClipTimer", id: "main") {
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
        .defaultSize(width: 380, height: 540)
        .commands {
            CommandGroup(replacing: .help) {
                Button("ClipTimer Help") {
                    openWindow(id: "help")
                }
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Cut all tasks") {
                    store.cutAllTasks()
                }
                .keyboardShortcut("x")
                
                Button("Paste tasks (replace)") {
                    store.replaceTasksFromClipboard()
                }
                .keyboardShortcut("v")

                Button("Paste tasks (append)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift])

                Divider()

                Button("Copy tasks with times") {
                    store.copySummaryToClipboard()
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
            
            CommandMenu("Tasks") {
                Button("Open Task Editor") {
                    openWindow(id: "task-editor")
                }
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