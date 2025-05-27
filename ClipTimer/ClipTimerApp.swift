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
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 380, idealWidth: 480,
                       minHeight: 300, idealHeight: 420)
        }
        .commands {
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
            CommandGroup(replacing: .pasteboard) {
                Button("Copy task summary") {
                    store.copySummaryToClipboard()
                }
                .keyboardShortcut("c")       // ⌘C = resumen
                Divider()
                Button("Cut") {           // ⌘X
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x")
                Button("Paste tasks (replace)") {
                    store.replaceTasksFromClipboard()
                }
                .keyboardShortcut("v") // ⌘V

                Button("Paste tasks (append)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift]) // ⇧⌘V
            }
        }

        MenuBarExtra {
            Button("Copy task summary") {
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
