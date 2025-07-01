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
    @Published var activeTaskStartTime: Date? = nil  // Single Source of Truth for start time
    @Published var itemSymbol: String = ""  // Símbolo de itemización para todas las tareas
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil
    private var timer: Timer?
    private var blinkTimer: Timer?

    // MARK: - Local Persistence
    private let userDefaults = UserDefaults.standard
    private let localStorageKey = "saved_tasks"

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
        loadTasksLocally()  // 🆕 Load tasks on app start
    }
    
    var totalElapsed: TimeInterval {
        tasks.reduce(0) { $0 + getCurrentElapsed(for: $1) }
    }
    
    // Get current elapsed time for a task (including active time if running)
    private func getCurrentElapsed(for task: Task) -> TimeInterval {
        return task.currentElapsed(activeTaskID: activeTaskID, startTime: activeTaskStartTime)
    }
    
    // Pause the currently active task (save elapsed time and clear active state)
    private func pauseCurrentActiveTask() {
        guard let activeID = activeTaskID,
              let activeIndex = tasks.firstIndex(where: { $0.id == activeID }),
              let startTime = activeTaskStartTime else { return }
        
        tasks[activeIndex].elapsed += Date().timeIntervalSince(startTime)
        activeTaskID = nil
        activeTaskStartTime = nil
        
        // 🚀 Auto-save whenever a task is paused so elapsed time isn't lost
        saveTasksLocally()
    }
    
    var summaryText: String {
        if tasks.isEmpty { return "No tasks." }
        return tasks
            .map { "\(itemSymbol)\($0.name): \(getCurrentElapsed(for: $0).hms)" }
            .joined(separator: "\n") +
        "\n\nWorking time: \((totalElapsed).hms)"
    }
    
    // Toggle task activation - only one task can be active at a time
    func toggle(_ task: Task) {
        if activeTaskID == task.id {
            // Task is active, deactivate it (pause and save elapsed time)
            pauseCurrentActiveTask()
        } else {
            // First pause any currently active task
            pauseCurrentActiveTask()
            
            // Activate this task (set start time)
            activeTaskID = task.id
            activeTaskStartTime = Date()
        }
    }
    
    func replaceTasksFromClipboard() {
        let before = tasks
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let lines = tasksString.split(separator: "\n").map { String($0) }
            
            // If itemSymbol is empty, detect it from the first line that has a symbol
            if itemSymbol.isEmpty {
                for line in lines {
                    if let detectedSymbol = detectItemSymbol(from: line) {
                        itemSymbol = detectedSymbol
                        break
                    }
                }
            }
            
            let newTasks = lines.compactMap { parseTaskLine($0) }
            tasks = newTasks
            registerUndo(previousTasks: before, actionName: "Replace tasks")
            saveTasksLocally()  // 🆕 Auto-save after modifying tasks
        }
    }
    
    func addTasksFromClipboard() {
        let before = tasks
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let lines = tasksString.split(separator: "\n").map { String($0) }
            
            // If itemSymbol is empty, detect it from the first line that has a symbol
            if itemSymbol.isEmpty {
                for line in lines {
                    if let detectedSymbol = detectItemSymbol(from: line) {
                        itemSymbol = detectedSymbol
                        break
                    }
                }
            }
            
            let addedTasks = lines.compactMap { parseTaskLine($0) }
            tasks.append(contentsOf: addedTasks)
            registerUndo(previousTasks: before, actionName: "Add tasks")
            saveTasksLocally()  // 🆕 Auto-save after modifying tasks
        }
    }
    
    func cutAllTasks() {
        guard !tasks.isEmpty else { return }
        let before = tasks
        copySummaryToClipboard()
        tasks.removeAll()
        registerUndo(previousTasks: before, actionName: "Cut all tasks")
        saveTasksLocally()  // 🆕 Auto-save after modifying tasks
    }
    
    // Parse task line with optional time format (e.g., "Task name: 1:30:45" or "Task name")
    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Define separate regex patterns for different time formats
        let hoursMinutesSecondsRegex = try! NSRegularExpression(pattern: #"^(.*?):\s*(\d{1,2}):(\d{2}):(\d{2})\s*$"#)
        let minutesSecondsRegex = try! NSRegularExpression(pattern: #"^(.*?):\s*(\d{1,2}):(\d{2})\s*$"#)
        
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        
        // Try H:MM:SS format first (more specific)
        if let match = hoursMinutesSecondsRegex.firstMatch(in: trimmed, range: range) {
            let taskName = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let hours = Int(trimmed[Range(match.range(at: 2), in: trimmed)!]) ?? 0
            let minutes = Int(trimmed[Range(match.range(at: 3), in: trimmed)!]) ?? 0
            let seconds = Int(trimmed[Range(match.range(at: 4), in: trimmed)!]) ?? 0
            let elapsed = Double(hours * 3600 + minutes * 60 + seconds)
            return createTask(from: taskName, elapsed: elapsed)
        }
        
        // Try MM:SS format
        if let match = minutesSecondsRegex.firstMatch(in: trimmed, range: range) {
            let taskName = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let minutes = Int(trimmed[Range(match.range(at: 2), in: trimmed)!]) ?? 0
            let seconds = Int(trimmed[Range(match.range(at: 3), in: trimmed)!]) ?? 0
            let elapsed = Double(minutes * 60 + seconds)
            return createTask(from: taskName, elapsed: elapsed)
        }
        
        // No time found, treat entire line as task name
        return createTask(from: trimmed, elapsed: 0)
    }
    
    // Helper method to create task with cleaned name
    private func createTask(from rawText: String, elapsed: TimeInterval) -> Task {
        let cleanName = removeItemSymbolFromStart(rawText)
        return Task(name: cleanName, elapsed: elapsed)
    }
    
    // Parse item symbol and clean text from a task line
    private func parseItemSymbolAndText(from line: String) -> (symbol: String?, cleanText: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, "") }
        
        // Define all supported symbols in one place
        let supportedSymbols = ["- ", "• ", "* ", "→ ", "✓ ", "☐ ", "-\t", "•\t", "*\t", "→\t", "✓\t", "☐\t"]
        
        // Check for any supported symbol
        for symbol in supportedSymbols {
            if trimmed.hasPrefix(symbol) {
                let cleanText = String(trimmed.dropFirst(symbol.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return (symbol, cleanText)
            }
        }
        
        // No symbol found
        return (nil, trimmed)
    }
    
    // Detect item symbol from a task line (uses shared logic)
    private func detectItemSymbol(from line: String) -> String? {
        return parseItemSymbolAndText(from: line).symbol
    }
    
    // Remove item symbol from the beginning of a task line (uses shared logic)
    private func removeItemSymbolFromStart(_ line: String) -> String {
        return parseItemSymbolAndText(from: line).cleanText
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
        saveTasksLocally()  // 🆕 Auto-save after modifying tasks
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
            .map { "\(itemSymbol)\($0.name): \(getCurrentElapsed(for: $0).hms)" }
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
        
        lastPausedTaskID = activeID
        pauseCurrentActiveTask()
    }
    
    func restartLastPausedTask() {
        guard let pausedID = lastPausedTaskID,
              let _ = tasks.firstIndex(where: { $0.id == pausedID }) else { return }
        
        // First pause any currently active task
        pauseCurrentActiveTask()
        
        // Restart the paused task
        activeTaskID = pausedID
        activeTaskStartTime = Date()
    }
    
    // MARK: - App Lifecycle Methods
    
    /// Pause active task and save state when app is about to terminate
    func pauseActiveTaskAndSave() {
        guard let activeID = activeTaskID else {
#if DEBUG
            print("🚪 No active task to pause on app termination")
#endif
            return
        }
        
#if DEBUG
        print("🚪 Auto-pausing active task on app termination: \(activeTask?.name ?? "Unknown")")
#endif
        
        // Remember which task was active for potential restart
        lastPausedTaskID = activeID
        
        // Pause the active task (this now also saves)
        pauseCurrentActiveTask()
        
#if DEBUG
        print("🚪 App state saved successfully")
#endif
    }

    // MARK: - Local Persistence Methods

    // Save tasks to UserDefaults
    private func saveTasksLocally() {
        do {
            let data = try JSONEncoder().encode(tasks)
            userDefaults.set(data, forKey: localStorageKey)
#if DEBUG
            print("💾 Saved \(tasks.count) tasks locally")
#endif
        } catch {
            print("❌ Local save error: \(error)")
        }
    }
    
    // Load tasks from UserDefaults
    private func loadTasksLocally() {
        guard let data = userDefaults.data(forKey: localStorageKey) else {
#if DEBUG
            print("📥 No local data found - starting with empty task list")
#endif
            return
        }
        
        do {
            let savedTasks = try JSONDecoder().decode([Task].self, from: data)
            tasks = savedTasks
#if DEBUG
            print("📥 Loaded \(savedTasks.count) tasks from local storage")
#endif
        } catch {
            print("❌ Local load error: \(error)")
        }
    }


}

// MARK: - Testing Support
#if DEBUG
extension TaskStore {
    /// Decode persisted tasks - helper method for testing
    private func decodePersistentTasks() -> [Task]? {
        guard let data = userDefaults.data(forKey: localStorageKey) else { return nil }
        
        do {
            return try JSONDecoder().decode([Task].self, from: data)
        } catch {
            print("❌ Error decoding persisted tasks for testing: \(error)")
            return nil
        }
    }
    
    /// Clear all persisted data - for testing only
    func clearPersistedData() {
        userDefaults.removeObject(forKey: localStorageKey)
        print("🧪 Cleared persisted data for testing")
    }
    
    /// Check if there is persisted data - for testing only
    func hasPersistedData() -> Bool {
        return userDefaults.data(forKey: localStorageKey) != nil
    }
    
    /// Get count of persisted tasks - for testing only
    func getPersistedTaskCount() -> Int? {
        return decodePersistentTasks()?.count
    }
    
    /// Get persisted tasks - for testing only
    func getPersistedTasks() -> [Task]? {
        return decodePersistentTasks()
    }
    
    /// Force save current tasks - for testing only
    func forceSave() {
        saveTasksLocally()
    }
    
    /// Get last paused task ID - for testing only
    func getLastPausedTaskID() -> UUID? {
        return lastPausedTaskID
    }
}
#endif
