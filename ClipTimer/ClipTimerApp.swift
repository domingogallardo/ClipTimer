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
            CommandGroup(before: .pasteboard) {
                Button("Undo") {
                    store.undo()
                }
                .keyboardShortcut("z")
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Copiar resumen de tareas") {
                    store.copySummaryToClipboard()
                }
                .keyboardShortcut("c")       // ⌘C = resumen
                Divider()
                Button("Cortar") {           // ⌘X
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x")
                Button("Pegar tareas (reemplazar)") {
                    store.replaceTasksFromClipboard()
                }
                .keyboardShortcut("v") // ⌘V

                Button("Pegar tareas (añadir)") {
                    store.addTasksFromClipboard()
                }
                .keyboardShortcut("V", modifiers: [.command, .shift]) // ⇧⌘V
            }
        }

        MenuBarExtra {
            Button("Copiar resumen de tareas") {
                store.copySummaryToClipboard()
            }
            Divider()
            Button("Abrir ventana principal") {
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            Text(store.totalElapsed.hms)
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 6)
        }
    }}
