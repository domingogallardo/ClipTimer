//
//  ContentView.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.undoManager) private var undoManager
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {

            header

            Divider()

            // Animated transition between empty state and task list
            ZStack {
                if store.tasks.isEmpty {
                    EmptyTasksPlaceholder()
                        .transition(.opacity)
                } else {
                    TaskListView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: store.tasks.isEmpty)

            Divider()

            footer
        }
        .onAppear { store.undoManager = undoManager }
        .overlay(helpOverlay)
    }
}


private extension ContentView {
    @ViewBuilder
    var header: some View {
        HStack {
            Text("Tasks")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            #if DEBUG
            // 🧪 Temporary test button for persistence
            Button {
                store.testLocalPersistence()
            } label: {
                Image(systemName: "internaldrive")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Test local persistence")
            .padding(.horizontal, 8)
            #endif

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

    // Sliding help overlay with tap-to-dismiss functionality
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
        Task(rawName: "Write Report", name: "Write Report", elapsed: 432),
        Task(rawName: "Email Review", name: "Email Review", elapsed: 1230)
    ]
    // Make first task active
    store.activeTaskID = store.tasks[0].id
    
    return ContentView()
        .environmentObject(store)
        .frame(width: 380, height: 600)
}

#endif
