//
//  ContentView.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 22/5/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.undoManager) private var undoManager
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {

            // ——— Cabecera ———
            header

            Divider()

            // ——— Lista o marcador ———
            ZStack {                                   // anima transiciones
                if store.tasks.isEmpty {
                    EmptyTasksPlaceholder()             // panel en blanco
                        .transition(.opacity)
                } else {
                    TaskListView()                      // vista separada
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: store.tasks.isEmpty)

            Divider()

            // ——— Total ———
            footer
        }
        .onAppear { store.undoManager = undoManager }
        .overlay(helpOverlay)                           // ayuda
    }
}


private extension ContentView {

    // Cabecera
    @ViewBuilder                     // permite varias vistas dentro
    var header: some View {
        HStack {
            Text("Tasks")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Button {
                withAnimation { showHelp.toggle() }
            } label: {
                Image(systemName: "keyboard")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Show keyboard shortcuts")
            .padding(.horizontal, 16)
        }
    }

    // Pie con tiempo total
    var footer: some View {
        HStack {
            Text("Working time")
                .font(.headline)
            Spacer()
            Text(store.totalElapsed.hms)
                .font(.headline)
                .monospacedDigit()
        }
        .padding()
    }

    // Overlay de ayuda (aparece/desaparece animado)
    @ViewBuilder
    var helpOverlay: some View {
        ZStack(alignment: .trailing) {
            if showHelp {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                HelpOverlay()
                    .background(Color(NSColor.windowBackgroundColor))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.3),
                            radius: 14, x: -8, y: 0)
                    .transition(.move(edge: .trailing))
            }
        }
        .onTapGesture {
            withAnimation { showHelp = false }
        }
        .animation(.easeInOut(duration: 0.5), value: showHelp)
    }
}

#if DEBUG

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .frame(width: 380, height: 600)
}

#Preview {
    let store = TaskStore()
    store.tasks = [
        Task(rawName: "Write Report", name: "Write Report", elapsed: 432, isActive: true),
        Task(rawName: "Email Review", name: "Email Review", elapsed: 1230, isActive: false)
    ]
    
    return ContentView()
        .environmentObject(store)
        .frame(width: 380, height: 600)
}

#endif
