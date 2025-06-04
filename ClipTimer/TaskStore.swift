//
//  TaskStore.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 4/6/25.
//


import SwiftUI
import AppKit

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil
    private var timer: Timer?

    // ------------- Lógica de negocio (sin cambios) ------------------------
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
    
    init() { startTimer() }
    
    var totalElapsed: TimeInterval {
        tasks.reduce(0) { $0 + $1.elapsed }
    }
    
    var summaryText: String {
        if tasks.isEmpty { return "No tasks." }
        return tasks
            .map { "- \($0.name): \($0.elapsed.hms)" }
            .joined(separator: "\n") +
        "\n\nWorking time: \((totalElapsed).hms)"
    }
    
    func toggle(_ task: Task) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }),
           tasks[idx].isActive {
            tasks[idx].isActive = false
        } else {
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
            registerUndo(previousTasks: before, actionName: "Replace tasks")
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
            registerUndo(previousTasks: before, actionName: "Add tasks")
        }
    }
    
    func cutAllTasks() {
        guard !tasks.isEmpty else { return }
        let before = tasks
        copySummaryToClipboard()
        tasks.removeAll()
        registerUndo(previousTasks: before, actionName: "Cut all tasks")
    }
    
    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let regex = try! NSRegularExpression(
            pattern: #"^(.*?)(?::\s*(\d{1,2}:)?(\d{1,2}):(\d{2}))?\s*$"#)
        
        if let match = regex.firstMatch(
            in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            
            let nameRange = Range(match.range(at: 1), in: trimmed)
            let rawName = nameRange.map { String(trimmed[$0]) } ?? trimmed
            
            let hours = match.range(at: 2).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 2), in: trimmed)!]
                    .dropLast()
                    .trimmingCharacters(in: .whitespaces)) ?? 0 : 0
            let minutes = match.range(at: 3).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 3), in: trimmed)!]) ?? 0 : 0
            let seconds = match.range(at: 4).location != NSNotFound ?
                Int(trimmed[Range(match.range(at: 4), in: trimmed)!]) ?? 0 : 0
            
            let elapsed = Double(hours * 3600 + minutes * 60 + seconds)
            return Task(
                rawName: rawName,
                name: rawName.trimmingCharacters(in: .init(charactersIn: "-*• \t")),
                elapsed: elapsed)
        } else {
            return Task(
                rawName: trimmed,
                name: trimmed.trimmingCharacters(in: .init(charactersIn: "-*• \t")),
                elapsed: 0)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerDidFire(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    func delete(_ task: Task) {
        let before = tasks
        tasks.removeAll { $0.id == task.id }
        registerUndo(previousTasks: before, actionName: "Delete task")
    }
    
    @objc private func timerDidFire(_ timer: Timer) {
        for index in tasks.indices where tasks[index].isActive {
            tasks[index].elapsed += 1
        }
    }
    
    func copySummaryToClipboard() {
        let taskSummary = tasks
            .map { "\($0.rawName): \($0.elapsed.hms)" }
            .joined(separator: "\n")
        let total = tasks.reduce(0) { $0 + $1.elapsed }
        let summaryWithTotal = taskSummary.isEmpty
            ? "Sin tareas."
            : "\(taskSummary)\n\nTotal: \(total.hms)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(summaryWithTotal, forType: .string)
    }
    
    var activeTask: Task? { tasks.first(where: { $0.isActive }) }
    
    func pauseActiveTask() {
        if let idx = tasks.firstIndex(where: { $0.isActive }) {
            tasks[idx].isActive = false
            lastPausedTaskID = tasks[idx].id
        }
    }
    
    func restartLastPausedTask() {
        guard let id = lastPausedTaskID,
              let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        for i in tasks.indices { tasks[i].isActive = false }
        tasks[idx].isActive = true
    }
}
