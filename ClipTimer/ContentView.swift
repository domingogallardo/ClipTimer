//
//  ContentView.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 22/5/25.
//

import SwiftUI
import AppKit

// MARK: - Modelo + Store


struct Task: Identifiable {
    let id = UUID()
    let rawName: String
    var name: String
    var elapsed: TimeInterval    // segundos
    var isActive: Bool = false
}

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    weak var undoManager: UndoManager?

    private var timer: Timer?

    private func registerUndo(previousTasks: [Task], actionName: String) {
        undoManager?.registerUndo(withTarget: self) { target in
            DispatchQueue.main.async {
                let current = target.tasks
                target.tasks = previousTasks
                target.registerUndo(previousTasks: current, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }
    
    init() {
        startTimer()
    }

    var totalElapsed: TimeInterval {
        tasks.reduce(0) { $0 + $1.elapsed }
    }
    
    var summaryText: String {
        if tasks.isEmpty { return "Sin tareas." }
        return tasks
            .map { "- \($0.name): \($0.elapsed.hms)" }
            .joined(separator: "\n") +
        "\n\nWorking time: \((totalElapsed).hms)"
    }

    func toggle(_ task: Task) {
        // If the tapped task is already active, pause it (no active tasks)
        if let idx = tasks.firstIndex(where: { $0.id == task.id }),
           tasks[idx].isActive {
            tasks[idx].isActive = false
        } else {
            // Otherwise, activate this task exclusively
            for index in tasks.indices {
                tasks[index].isActive = (tasks[index].id == task.id)
            }
        }
    }
    
    func replaceTasksFromClipboard() {
        let before = tasks
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let newTasks = tasksString
                .split(separator: "\n")
                .map { String($0) }
                .compactMap { parseTaskLine($0) }
            tasks = newTasks
            registerUndo(previousTasks: before, actionName: "Reemplazar tareas")
        }
    }

    func addTasksFromClipboard() {
        let before = tasks
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let addedTasks = tasksString
                .split(separator: "\n")
                .map { String($0) }
                .compactMap { parseTaskLine($0) }
            tasks.append(contentsOf: addedTasks)
            registerUndo(previousTasks: before, actionName: "Añadir tareas")
        }
    }

    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let regex = try! NSRegularExpression(pattern: #"^(.*?)(?::\s*(\d{1,2}:)?(\d{1,2}):(\d{2}))?\s*$"#)
        if let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let nameRange = Range(match.range(at: 1), in: trimmed)
            let rawName = nameRange.map { String(trimmed[$0]) } ?? trimmed

            let hours = match.range(at: 2).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 2), in: trimmed)!].dropLast().trimmingCharacters(in: .whitespaces)) ?? 0 : 0
            let minutes = match.range(at: 3).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 3), in: trimmed)!]) ?? 0 : 0
            let seconds = match.range(at: 4).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 4), in: trimmed)!]) ?? 0 : 0

            let elapsed: TimeInterval = Double(hours * 3600 + minutes * 60 + seconds)
            return Task(rawName: rawName, name: rawName.trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t")), elapsed: elapsed)
        } else {
            return Task(rawName: trimmed, name: trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t")), elapsed: 0)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1,
                                     target: self,
                                     selector: #selector(timerDidFire(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    

    func delete(_ task: Task) {
        let before = tasks
        tasks.removeAll { $0.id == task.id }
        registerUndo(previousTasks: before, actionName: "Eliminar tarea")
    }

    @objc private func timerDidFire(_ timer: Timer) {
        for index in tasks.indices where tasks[index].isActive {
            tasks[index].elapsed += 1
        }
    }
    
    @discardableResult
    func copySummaryToClipboard() -> Bool {
        let taskSummary = tasks
            .map { "\($0.rawName): \($0.elapsed.hms)" }
            .joined(separator: "\n")
        let total = tasks.reduce(0) { $0 + $1.elapsed }
        let summaryWithTotal = taskSummary.isEmpty
            ? "Sin tareas."
            : "\(taskSummary)\n\nTotal: \(total.hms)"
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(summaryWithTotal, forType: .string)
    }
}

// MARK: - Vistas

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.undoManager) private var undoManager
    
    var instruction: String {
        if store.tasks.isEmpty {
            return "Press ⌘V to add tasks from the clipboard."
        } else {
            return "Press ⌘V to replace tasks or ⇧⌘V to add tasks from the clipboard.\nPress ⌘C to copy a summary."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // Cabecera (título + botón “+” en toolbar)
            Text("Tasks")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            
            Divider()
            
            // Lista de tareas
            List {
                ForEach(store.tasks) { task in
                    TaskRow(task: task) { store.toggle(task) }
                        .contextMenu {                            // ← clic derecho
                            Button(role: .destructive) {
                                store.delete(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 300) // Mínimo espacio para la lista
            .padding(.horizontal)
            
            // Instrucciones para copiar resumen
            Text(instruction)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .animation(.easeInOut, value: instruction)
            
            Divider()
            
            // Total
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
        .onAppear {
            store.undoManager = undoManager
        }
    }
}

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
                Image(systemName: task.isActive ? "power.circle.fill"
                                                : "power.circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(task.isActive ? .green : .secondary)
                    .padding(4)
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                    .animation(task.isActive
                               ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                               : .default,
                               value: isAnimating)
            }
            .buttonStyle(.plain)
        }
        .onAppear {                      // start/stop animation on first display
            isAnimating = task.isActive
        }
        .onChange(of: task.isActive) { _, newValue in
            isAnimating = newValue
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formateo de tiempo m:ss

extension TimeInterval {
    var hms: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return "\(h):" + String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .frame(width: 380, height: 600)
}
