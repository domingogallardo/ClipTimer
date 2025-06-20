//
//  TaskRow.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//


import SwiftUI

struct TaskRow: View {
    let task: Task
    let toggle: () -> Void
    @EnvironmentObject private var store: TaskStore
    @State private var isAnimating = false

    private var isActive: Bool {
        store.activeTaskID == task.id
    }
    
    private var currentElapsed: TimeInterval {
        return task.currentElapsed(activeTaskID: store.activeTaskID)
    }

    var body: some View {
        HStack {
            Text(task.name)
            Spacer()
            Text(currentElapsed.hms)
                .monospacedDigit()
            Button {
                toggle()
            } label: {
                Image(systemName: isActive ? "power.circle.fill" : "power.circle")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(isActive ? .green : .secondary)
                    .scaleEffect(isAnimating ? 1.25 : 1.0)
                    .animation(isActive
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                        value: isAnimating)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .onAppear { isAnimating = isActive }
            .onChange(of: isActive) { _, newValue in isAnimating = newValue }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview {
    let store = TaskStore()
    store.tasks = [
        Task(rawName: "Write Report", name: "Write Report", elapsed: 123),
        Task(rawName: "Review Email", name: "Review Email", elapsed: 4523)
    ]
    // Make second task active
    store.activeTaskID = store.tasks[1].id
    
    return VStack(spacing: 12) {
        TaskRow(
            task: store.tasks[0],
            toggle: {}
        )
        TaskRow(
            task: store.tasks[1],
            toggle: {}
        )
    }
    .environmentObject(store)
    .padding()
    .frame(width: 340)
}
#endif
