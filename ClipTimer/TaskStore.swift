//
//  TaskStore.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//


import SwiftUI
import AppKit

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var showColons: Bool = true
    @Published var activeTaskID: UUID?
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil
    private var timer: Timer?
    private var blinkTimer: Timer?

    // Register undo/redo operations for task modifications
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
        startBlinkTimer()
    }
    
    var totalElapsed: TimeInterval {
        tasks.reduce(0) { $0 + getCurrentElapsed(for: $1) }
    }
    
    // Get current elapsed time for a task (including active time if running)
    private func getCurrentElapsed(for task: Task) -> TimeInterval {
        var elapsed = task.elapsed
        
        // If this task is currently active, add the time since it started
        if activeTaskID == task.id, let startTime = task.startTime {
            elapsed += Date().timeIntervalSince(startTime)
        }
        
        return elapsed
    }
    
    var summaryText: String {
        if tasks.isEmpty { return "No tasks." }
        return tasks
            .map { "- \($0.name): \(getCurrentElapsed(for: $0).hms)" }
            .joined(separator: "\n") +
        "\n\nWorking time: \((totalElapsed).hms)"
    }
    
    // Toggle task activation - only one task can be active at a time
    func toggle(_ task: Task) {
        if activeTaskID == task.id {
            // Task is active, deactivate it (pause and save elapsed time)
            if let activeIndex = tasks.firstIndex(where: { $0.id == task.id }),
               let startTime = tasks[activeIndex].startTime {
                tasks[activeIndex].elapsed += Date().timeIntervalSince(startTime)
                tasks[activeIndex].startTime = nil
            }
            activeTaskID = nil
        } else {
            // First pause any currently active task
            if let currentActiveID = activeTaskID,
               let currentActiveIndex = tasks.firstIndex(where: { $0.id == currentActiveID }),
               let currentStartTime = tasks[currentActiveIndex].startTime {
                tasks[currentActiveIndex].elapsed += Date().timeIntervalSince(currentStartTime)
                tasks[currentActiveIndex].startTime = nil
            }
            
            // Activate this task (set start time)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].startTime = Date()
            }
            activeTaskID = task.id
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
    
    // Parse task line with optional time format (e.g., "Task name: 1:30:45" or "Task name")
    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Regex to extract task name and optional time (hours:minutes:seconds or minutes:seconds)
        let regex = try! NSRegularExpression(
            pattern: #"^(.*?)(?::\s*(\d{1,2}:)?(\d{1,2}):(\d{2}))?\s*$"#)
        
        if let match = regex.firstMatch(
            in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            
            let nameRange = Range(match.range(at: 1), in: trimmed)
            let rawName = nameRange.map { String(trimmed[$0]) } ?? trimmed
            
            // Extract time components from regex groups
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
                name: rawName.trimmingCharacters(in: .init(charactersIn: "-*• \t")), // Clean task name
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
    
    private func startBlinkTimer() {
        blinkTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(blinkTimerDidFire(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    func delete(_ task: Task) {
        let before = tasks
        tasks.removeAll { $0.id == task.id }
        registerUndo(previousTasks: before, actionName: "Delete task")
    }
    
    // Timer callback - updates UI for active task (time calculation is continuous)
    @objc private func timerDidFire(_ timer: Timer) {
        // Timer now only triggers UI updates - actual time is calculated continuously
        // This ensures the UI updates every second even when laptop lid is closed
        if hasActiveTasks {
            objectWillChange.send()
        }
    }
    
    // Blink timer callback - toggles colon visibility every 0.5 seconds
    @objc private func blinkTimerDidFire(_ timer: Timer) {
        if hasActiveTasks {
            showColons.toggle()
        } else {
            showColons = true
        }
    }
    
    var hasActiveTasks: Bool {
        activeTaskID != nil
    }
    
    func copySummaryToClipboard() {
        let taskSummary = tasks
            .map { "\($0.rawName): \(getCurrentElapsed(for: $0).hms)" }
            .joined(separator: "\n")
        let total = totalElapsed
        let summaryWithTotal = taskSummary.isEmpty
            ? "Sin tareas."
            : "\(taskSummary)\n\nTotal: \(total.hms)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(summaryWithTotal, forType: .string)
    }
    
    var activeTask: Task? { 
        guard let activeID = activeTaskID else { return nil }
        return tasks.first(where: { $0.id == activeID })
    }
    
    func pauseActiveTask() {
        guard let activeID = activeTaskID else { return }
        
        // Save elapsed time before pausing
        if let activeIndex = tasks.firstIndex(where: { $0.id == activeID }),
           let startTime = tasks[activeIndex].startTime {
            tasks[activeIndex].elapsed += Date().timeIntervalSince(startTime)
            tasks[activeIndex].startTime = nil
        }
        
        lastPausedTaskID = activeID
        activeTaskID = nil
    }
    
    func restartLastPausedTask() {
        guard let pausedID = lastPausedTaskID,
              let pausedIndex = tasks.firstIndex(where: { $0.id == pausedID }) else { return }
        
        // First pause any currently active task
        if let currentActiveID = activeTaskID,
           let currentActiveIndex = tasks.firstIndex(where: { $0.id == currentActiveID }),
           let currentStartTime = tasks[currentActiveIndex].startTime {
            tasks[currentActiveIndex].elapsed += Date().timeIntervalSince(currentStartTime)
            tasks[currentActiveIndex].startTime = nil
        }
        
        // Restart the paused task
        tasks[pausedIndex].startTime = Date()
        activeTaskID = pausedID
    }
}
