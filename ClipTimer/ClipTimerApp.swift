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
    @Environment(\.openWindow) private var openWindow

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
        Window("ClipTimer Help", id: "help") {
            HelpWindow()
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
                .keyboardShortcut("x")                      // ⌘X
                
                Button("Paste tasks (replace)") {
                    store.replaceTasksFromClipboard()
                }
                .keyboardShortcut("v")                      // ⌘V

                Button("Paste tasks (append)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift]) // ⇧⌘V

                Divider()

                Button("Copy tasks with times") {
                    store.copySummaryToClipboard()
                }
                .keyboardShortcut("c")                      // ⌘C
            }
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

        MenuBarExtra {
            Button("Copy tasks with times") {
                store.copySummaryToClipboard()
            }
            Divider()
            Button("Open main window") {
                if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {

                    // 1. Si está minimizada, la restauramos sin animación extra
                    if win.isMiniaturized {
                        win.deminiaturize(nil)       // ← evita el parpadeo
                    }

                    // 2. Traemos la ventana al frente y la hacemos clave
                    win.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)

                } else {
                    // Si no existe (cerrada), creamos una nueva
                    openWindow(id: "main")
                }
            }
        } label: {
            Text(store.totalElapsed.hms)
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 6)
        }
    }}
