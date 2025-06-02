//
//  ClipTimerApp.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 22/5/25.
//

import SwiftUI

@main
struct ClipTimerApp: App {
    @StateObject private var store = TaskStore()
    
    var body: some Scene {
        // ── Ventana principal ─────────────────────────────────────────────
        Window("CipTimer", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(
                    minWidth: 380, idealWidth: 380,
                    minHeight: 540, idealHeight: 540
                ).onAppear {
                    // Centrar la ventana en pantalla al arrancar
                    NSApp.windows.first?.center()
                }
        }
        .commands {
            // Undo / Redo (Edit menu, estándar)
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

            // Paste tasks (Tasks menu)
            CommandMenu("Tasks") {
                Button("Paste tasks (replace)") {
                    store.replaceTasksFromClipboard()
                }
                .keyboardShortcut("v")
                Button("Paste tasks (append)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift])
                // Timer controls
                Divider()
                Button("Pause active task") {
                    store.pauseActiveTask()
                }
                .keyboardShortcut("p")

                Button("Restart last paused task") {
                    store.restartLastPausedTask()
                }
                .keyboardShortcut("r")
                Divider()
                // Export tasks with times
                Button("Copy tasks with times") {
                    store.copySummaryToClipboard()
                }
                .keyboardShortcut("c")
            }
       }

        MenuBarExtra {
            Button("Copy tasks with times") {
                store.copySummaryToClipboard()
            }
            Divider()
            Button("Open main window") {
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            Text(store.totalElapsed.hms)
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 6)
        }
    }}
