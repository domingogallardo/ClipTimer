//
//  TaskRow.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 4/6/25.
//


import SwiftUI

struct TaskRow: View {
    let task: Task
    let toggle: () -> Void
    @State private var isAnimating = false

    var body: some View {
        HStack {
            Text(task.name)
            Spacer()
            Text(task.elapsed.hms)
                .monospacedDigit()
            Button {
                toggle()
            } label: {
                Image(systemName: task.isActive ? "power.circle.fill" : "power.circle")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(task.isActive ? .green : .secondary)
                    .scaleEffect(isAnimating ? 1.25 : 1.0)
                    .animation(task.isActive
                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                        : .default,
                        value: isAnimating)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .onAppear { isAnimating = task.isActive }
            .onChange(of: task.isActive) { _, newValue in isAnimating = newValue }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview {
    VStack(spacing: 12) {
        TaskRow(
            task: Task(rawName: "Write Report", name: "Write Report", elapsed: 123, isActive: false),
            toggle: {}
        )
        TaskRow(
            task: Task(rawName: "Review Email", name: "Review Email", elapsed: 4523, isActive: true),
            toggle: {}
        )
    }
    .padding()
    .frame(width: 340)
}
#endif
