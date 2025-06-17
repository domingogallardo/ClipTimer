//
//  TaskListView.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//


import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        List {
            ForEach(store.tasks) { task in
                TaskRow(task: task) { store.toggle(task) }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.delete(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .frame(minHeight: 300)
        .padding(.horizontal)
    }
}

#if DEBUG
#Preview {
    let store = TaskStore()
    store.tasks = [
        Task(rawName: "Demo 1", name: "Demo 1", elapsed: 120),
        Task(rawName: "Demo 2", name: "Demo 2", elapsed: 45)
    ]
    // Make second task active
    store.activeTaskID = store.tasks[1].id
    
    return TaskListView()
        .environmentObject(store)
        .frame(width: 380, height: 300)
}
#endif
