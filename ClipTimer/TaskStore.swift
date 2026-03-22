//
//  TaskStore.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//


import SwiftUI
import AppKit
import os

private let taskStoreLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipTimer",
    category: "TaskStore"
)

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var activeTaskID: UUID?
    @Published var activeTaskStartTime: Date? = nil  // Single Source of Truth for start time
    @Published var itemSymbol: String = ""  // Item symbol for all tasks
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil

    // MARK: - Local Persistence
    private let userDefaults = UserDefaults.standard
    private let localStorageKey = "saved_tasks"
    private let itemSymbolStorageKey = "saved_item_symbol"
    
    // MARK: - Constants
    
    /// Supported item symbols for task formatting
    private static let supportedSymbols = ["• ", "- ", "* ", "→ ", "✓ ", "☐ ", "•\t"]
    

    // Register undo/redo operations for task modifications
    private func registerUndo(previousTasks: [Task], actionName: String) {
        undoManager?.registerUndo(withTarget: self) { target in
            let current = target.tasks
            target.tasks = previousTasks
            target.resetItemSymbolIfNoTasks()
            target.registerUndo(previousTasks: current, actionName: actionName)
            target.saveTasksLocally()
        }
        undoManager?.setActionName(actionName)
    }
    
    // MARK: - Undo/Redo Helper
    
    /// Centralizes task mutation with automatic undo registration and saving
    private func mutateTasks(actionName: String, mutation: (inout [Task]) -> Void) {
        let before = tasks
        mutation(&tasks)
        resetItemSymbolIfNoTasks()
        registerUndo(previousTasks: before, actionName: actionName)
        saveTasksLocally()
    }
    
    init() { 
        loadTasksLocally()  // 🆕 Load tasks on app start
    }

    var totalElapsed: TimeInterval {
        totalElapsed(at: Date())
    }
    
    // Get current elapsed time for a task (including active time if running)
    func currentElapsed(for task: Task, at now: Date = Date()) -> TimeInterval {
        task.currentElapsed(activeTaskID: activeTaskID, startTime: activeTaskStartTime, now: now)
    }

    func totalElapsed(at now: Date) -> TimeInterval {
        tasks.reduce(0) { $0 + currentElapsed(for: $1, at: now) }
    }
    
    // Pause the currently active task (save elapsed time and clear active state)
    private func pauseCurrentActiveTask() {
        guard let activeID = activeTaskID,
              let activeIndex = tasks.firstIndex(where: { $0.id == activeID }),
              let startTime = activeTaskStartTime else {
            taskStoreLogger.debug("pauseCurrentActiveTask ignored because there is no active task")
            return
        }

        let taskName = tasks[activeIndex].name
        let elapsedToAdd = Date().timeIntervalSince(startTime)
        taskStoreLogger.notice(
            "Pausing task name=\(taskName, privacy: .public) id=\(activeID.uuidString, privacy: .public) addedSeconds=\(elapsedToAdd, format: .fixed(precision: 2))"
        )
        
        tasks[activeIndex].elapsed += elapsedToAdd
        activeTaskID = nil
        activeTaskStartTime = nil
        
        // 🚀 Auto-save whenever a task is paused so elapsed time isn't lost
        saveTasksLocally()
    }
    
    // MARK: - Helper to build summary lines
    private func taskLines() -> [String] {
        tasks.map {
            let time = currentElapsed(for: $0).hms
            let name = $0.isCompleted ? "~~\($0.name)~~" : $0.name
            return "\(itemSymbol)\(name): \(time)"
        }
    }
    
    var summaryText: String {
        if tasks.isEmpty { return NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks") }
        return taskLines().joined(separator: "\n") +
        "\n\n\(NSLocalizedString("Working time", comment: "Label for working time")): \(totalElapsed.hms)"
    }
    
    // Toggle task activation - only one task can be active at a time
    func toggle(_ task: Task) {
        guard !task.isCompleted else { return }
        if activeTaskID == task.id {
            // Task is active, deactivate it (pause and save elapsed time)
            lastPausedTaskID = task.id  // Remember this task for potential restart via ⌘R
            pauseCurrentActiveTask()
        } else {
            // First pause any currently active task
            pauseCurrentActiveTask()

            // Activate this task (set start time)
            activeTaskID = task.id
            activeTaskStartTime = Date()
        }
    }

    func finish(_ task: Task) {
        if activeTaskID == task.id {
            pauseCurrentActiveTask()
        }
        mutateTasks(actionName: "Finish task") { tasks in
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].isCompleted = true
            }
        }
    }

    func restart(_ task: Task) {
        pauseCurrentActiveTask()
        mutateTasks(actionName: "Restart task") { tasks in
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].isCompleted = false
            }
        }
        activeTaskID = task.id
        activeTaskStartTime = Date()
    }
    
    func replaceTasksFromClipboard() {
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            replaceTasks(from: tasksString)
        }
    }
    
    func addTasksFromClipboard() {
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            addTasks(from: tasksString)
        }
    }

    // MARK: - String-based task import helpers 🆕

    /// Replace the current list of tasks with the lines contained in `rawString`.
    /// Each line may optionally include a time (e.g. "Design: 1:30:45").
    func replaceTasks(from rawString: String) {
        let lines = rawString.split(separator: "\n").map(String.init)

        mutateTasks(actionName: "Replace tasks") { tasks in
            // Always detect and set item symbol (replacing mode)
            detectAndSetItemSymbol(from: lines, forceDetection: true)

            let newTasks = lines.compactMap { parseTaskLine($0) }
            
            // Preserve UUIDs of existing tasks to maintain references
            var updatedTasks: [Task] = []
            for newTask in newTasks {
                if let existingTask = tasks.first(where: { $0.name == newTask.name }) {
                    // Preserve the UUID of the existing task but adopt new completion state
                    let preservedTask = Task(id: existingTask.id, name: newTask.name, elapsed: newTask.elapsed, isCompleted: newTask.isCompleted)
                    updatedTasks.append(preservedTask)
                } else {
                    // New task, keep its generated UUID
                    updatedTasks.append(newTask)
                }
            }
            
            tasks = updatedTasks
        }
    }

    /// Add or update tasks using the lines contained in `rawString`.
    /// Existing tasks with the same name are updated; new ones are appended.
    func addTasks(from rawString: String) {
        let lines = rawString.split(separator: "\n").map(String.init)

        mutateTasks(actionName: "Add tasks") { tasks in
            // Detect and set item symbol if needed (adding mode)
            detectAndSetItemSymbol(from: lines, forceDetection: false)

            let newTasks = lines.compactMap { parseTaskLine($0) }
            updateOrAddTasks(newTasks, to: &tasks)
        }
    }
    
    /// Helper method to update existing tasks or add new ones
    private func updateOrAddTasks(_ newTasks: [Task], to tasks: inout [Task]) {
        for newTask in newTasks {
            if let existingIndex = tasks.firstIndex(where: { $0.name == newTask.name }) {
                // Task already exists - update its time
                let existingTask = tasks[existingIndex]
                
                // Special case: if the existing task is currently active, pause it first
                // BUT only if we're not already in a paused state (i.e., not in task editor context)
                if activeTaskID == existingTask.id && lastPausedTaskID == nil {
                    pauseCurrentActiveTask()
                }
                
                // Update the task's elapsed time and completion state
                tasks[existingIndex].elapsed = newTask.elapsed
                tasks[existingIndex].isCompleted = newTask.isCompleted
            } else {
                // New task - add it to the list
                tasks.append(newTask)
            }
        }
    }
    
    func cutAllTasks() {
        guard !tasks.isEmpty else { return }
        copySummaryToClipboard()
        mutateTasks(actionName: "Cut all tasks") { tasks in
            tasks.removeAll()
        }
    }
    
    // Parse task line with optional time format or arithmetic (e.g., "Task: 1:30:45 - 0:15:00")
    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Remove any item symbol so completion markers can be detected properly
        let (_, textWithoutSymbol) = parseItemSymbolAndText(from: trimmed)
        let content = textWithoutSymbol

        if let colonIndex = content.firstIndex(of: ":") {
            let namePart = content[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let expressionPart = content[content.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

            if let elapsed = Self.parseTimeExpression(expressionPart) {
                var taskName = String(namePart)
                var isCompleted = false
                if taskName.hasPrefix("~~"), taskName.hasSuffix("~~") {
                    isCompleted = true
                    taskName = String(taskName.dropFirst(2).dropLast(2))
                }
                return createTask(from: taskName, elapsed: elapsed, isCompleted: isCompleted)
            }
        }

        // No time found, treat entire line as task name, detecting strikethrough
        var nameOnly = content
        var isCompleted = false
        if nameOnly.hasPrefix("~~"), nameOnly.hasSuffix("~~") {
            isCompleted = true
            nameOnly = String(nameOnly.dropFirst(2).dropLast(2))
        }
        return createTask(from: nameOnly, elapsed: 0, isCompleted: isCompleted)
    }

    /// Evaluate a time expression such as "1:00:00 - 0:30:00 + 45". Returns `nil` for invalid input.
    private static func parseTimeExpression(_ rawExpression: String) -> TimeInterval? {
        let expression = rawExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty else { return nil }

        var totalSeconds = 0
        var index = expression.startIndex
        var sign = 1
        var consumedValue = false

        while index < expression.endIndex {
            // Skip whitespace between tokens
            while index < expression.endIndex, expression[index].isWhitespace {
                index = expression.index(after: index)
            }

            guard index < expression.endIndex else { break }

            let character = expression[index]

            if character == "+" || character == "-" {
                sign = (character == "+") ? 1 : -1
                consumedValue = false
                index = expression.index(after: index)
                continue
            }

            guard character.isNumber else { return nil }
            guard !consumedValue else { return nil }

            let valueStart = index
            while index < expression.endIndex {
                let current = expression[index]
                if current.isNumber || current == ":" {
                    index = expression.index(after: index)
                } else {
                    break
                }
            }

            let token = expression[valueStart..<index]
            guard let tokenSeconds = parseTimeToken(token) else { return nil }

            totalSeconds += sign * tokenSeconds
            consumedValue = true
            sign = 1
        }

        guard consumedValue else { return nil }

        return TimeInterval(max(0, totalSeconds))
    }

    /// Parse a single time token into seconds. Tokens support "SS", "MM:SS", or "HH:MM:SS".
    private static func parseTimeToken(_ token: Substring) -> Int? {
        let components = token.split(separator: ":")
        guard !components.isEmpty, components.count <= 3 else { return nil }

        var values: [Int] = []
        for (index, part) in components.enumerated() {
            guard !part.isEmpty, part.allSatisfy({ $0.isNumber }) else { return nil }

            if index > 0, part.count != 2 { return nil }
            if index == 0, part.count > 2 { return nil }

            guard let value = Int(part) else { return nil }
            values.append(value)
        }

        switch values.count {
        case 1:
            return values[0]
        case 2:
            return values[0] * 60 + values[1]
        case 3:
            return values[0] * 3600 + values[1] * 60 + values[2]
        default:
            return nil
        }
    }

    // Helper method to create task with cleaned name
    private func createTask(from rawText: String, elapsed: TimeInterval, isCompleted: Bool) -> Task {
        let cleanName = removeItemSymbolFromStart(rawText)
        return Task(name: cleanName, elapsed: elapsed, isCompleted: isCompleted)
    }
    
    // Parse item symbol and clean text from a task line
    private func parseItemSymbolAndText(from line: String) -> (symbol: String?, cleanText: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, "") }
        
        // Check for any supported symbol
        for symbol in TaskStore.supportedSymbols {
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
    
    // Helper method to detect and set item symbol from clipboard lines
    private func detectAndSetItemSymbol(from lines: [String], forceDetection: Bool = false) {
        // Rules:
        // • Replacing (forceDetection = true) → always recalculate symbol (or clear if not found)
        // • Adding  (forceDetection = false) → only if there was no symbol yet
        guard forceDetection || itemSymbol.isEmpty else { return }

        // Find the first valid symbol in the received lines; if none, it will remain "".
        itemSymbol = lines.compactMap(detectItemSymbol).first ?? ""
    }
    
    // Helper method to reset item symbol when no tasks remain
    private func resetItemSymbolIfNoTasks() {
        if tasks.isEmpty {
            itemSymbol = ""
        }
    }
    
    func delete(_ task: Task) {
        mutateTasks(actionName: "Delete task") { tasks in
            tasks.removeAll { $0.id == task.id }
        }
    }
    
    var hasActiveTasks: Bool {
        activeTaskID != nil
    }

    /// Reflect timer state in the menu bar without updating the title every second.
    var menuBarIconName: String {
        hasActiveTasks ? "power.circle.fill" : "power.circle"
    }
    
    func copySummaryToClipboard() {
        let taskSummary = taskLines().joined(separator: "\n")
        let total = totalElapsed
        let summaryWithTotal = taskSummary.isEmpty
            ? NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks")
            : "\(taskSummary)\n\n\(NSLocalizedString("Working time", comment: "Label for working time")): \(total.hms)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(summaryWithTotal, forType: .string)
    }
    
    var activeTask: Task? { 
        guard let activeID = activeTaskID else { return nil }
        return tasks.first(where: { $0.id == activeID })
    }
    
    func pauseActiveTask(trigger: String = "unknown") {
        guard let activeID = activeTaskID else {
            taskStoreLogger.debug("pauseActiveTask ignored trigger=\(trigger, privacy: .public) because there is no active task")
            return
        }

        let taskName = activeTask?.name ?? "Unknown"
        taskStoreLogger.notice(
            "pauseActiveTask trigger=\(trigger, privacy: .public) name=\(taskName, privacy: .public) id=\(activeID.uuidString, privacy: .public)"
        )
        
        lastPausedTaskID = activeID
        pauseCurrentActiveTask()
    }
    
    func restartLastPausedTask(trigger: String = "unknown") {
        guard let pausedID = lastPausedTaskID,
              let _ = tasks.firstIndex(where: { $0.id == pausedID }) else {
            let activeTaskIDDescription = self.activeTaskID?.uuidString ?? "nil"
            taskStoreLogger.debug(
                "restartLastPausedTask ignored trigger=\(trigger, privacy: .public) lastPausedTaskID=nil-or-missing activeTaskID=\(activeTaskIDDescription, privacy: .public)"
            )
            return
        }

        let pausedTaskName = tasks.first(where: { $0.id == pausedID })?.name ?? "Unknown"
        taskStoreLogger.notice(
            "restartLastPausedTask trigger=\(trigger, privacy: .public) name=\(pausedTaskName, privacy: .public) id=\(pausedID.uuidString, privacy: .public)"
        )
        
        // First pause any currently active task
        pauseCurrentActiveTask()
        
        // Restart the paused task
        activeTaskID = pausedID
        activeTaskStartTime = Date()
        
        // Clear the last paused ID to prevent re-triggering
        lastPausedTaskID = nil
    }

    func finishActiveTask() {
        guard let task = activeTask else { return }
        finish(task)
    }

    /// Clear the last paused task ID without affecting the currently active task
    /// This is used when we want to "forget" about a previously paused task
    func clearLastPausedTask() {
        lastPausedTaskID = nil
    }
    
    // MARK: - App Lifecycle Methods
    
    /// Pause active task and save state when app is about to terminate
    func pauseActiveTaskAndSave() {
        guard let activeID = activeTaskID else {
            taskStoreLogger.debug("pauseActiveTaskAndSave ignored because there is no active task")
#if DEBUG
            print("🚪 No active task to pause on app termination")
#endif
            return
        }

        let taskName = activeTask?.name ?? "Unknown"
        taskStoreLogger.notice(
            "pauseActiveTaskAndSave name=\(taskName, privacy: .public) id=\(activeID.uuidString, privacy: .public)"
        )
        
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
            if itemSymbol.isEmpty {
                userDefaults.removeObject(forKey: itemSymbolStorageKey)
            } else {
                userDefaults.set(itemSymbol, forKey: itemSymbolStorageKey)
            }
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
            itemSymbol = userDefaults.string(forKey: itemSymbolStorageKey) ?? ""
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
        userDefaults.removeObject(forKey: itemSymbolStorageKey)
        tasks = []
        itemSymbol = ""
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
