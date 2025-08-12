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
    @Published var itemSymbol: String = ""  // Item symbol for all tasks
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil
    private var timer: Timer?
    private var blinkTimer: Timer?

    // MARK: - Local Persistence
    private let userDefaults = UserDefaults.standard
    private let localStorageKey = "saved_tasks"
    
    // MARK: - Constants
    
    /// Supported item symbols for task formatting
    private static let supportedSymbols = ["• ", "- ", "* ", "→ ", "✓ ", "☐ ", "•\t"]
    
    /// Static regex for parsing task lines with time format
    private static let timeParsingRegex: NSRegularExpression = {
        // Pattern matches "Task name: H:MM:SS" or "Task name: MM:SS" or "Task name: SS"
        // 1- Task name (lazily up to colon)
        // 2- First numeric block (hours or minutes)
        // 3- Second numeric block optional (minutes or seconds)
        // 4- Third numeric block optional (seconds)
        let pattern = #"^(.*?):\s*(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*$"#
        return try! NSRegularExpression(pattern: pattern)
    }()

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
        moveCompletedTasksToEnd(&tasks)
        resetItemSymbolIfNoTasks()
        registerUndo(previousTasks: before, actionName: actionName)
        saveTasksLocally()
    }

    /// Ensure all completed tasks appear after incomplete ones while preserving relative order
    private func moveCompletedTasksToEnd(_ tasks: inout [Task]) {
        var incomplete: [Task] = []
        var complete: [Task] = []
        for task in tasks {
            if task.isCompleted {
                complete.append(task)
            } else {
                incomplete.append(task)
            }
        }
        tasks = incomplete + complete
    }
    
    init() { 
        startTimer() 
        startBlinkTimer()
        loadTasksLocally()  // 🆕 Load tasks on app start
    }
    
    deinit {
        timer?.invalidate()
        blinkTimer?.invalidate()
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
    
    // MARK: - Helper to build summary lines
    private func taskLines() -> [String] {
        tasks.map {
            let time = getCurrentElapsed(for: $0).hms
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
                var finished = tasks.remove(at: index)
                finished.isCompleted = true
                tasks.append(finished)
            }
        }
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
    
    // Parse task line with optional time format (e.g., "Task name: 1:30:45" or "Task name")
    func parseTaskLine(_ rawLine: String) -> Task? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Remove any item symbol so completion markers can be detected properly
        let (_, textWithoutSymbol) = parseItemSymbolAndText(from: trimmed)
        let content = textWithoutSymbol

        // Attempt to parse "Task name: time" format
        let range = NSRange(content.startIndex..., in: content)
        if let match = Self.timeParsingRegex.firstMatch(in: content, range: range) {
            // Extract task name and detect strikethrough markers just around the name
            var taskName = String(content[Range(match.range(at: 1), in: content)!])
            var isCompleted = false
            if taskName.hasPrefix("~~"), taskName.hasSuffix("~~") {
                isCompleted = true
                taskName = String(taskName.dropFirst(2).dropLast(2))
            }

            let first  = Int(content[Range(match.range(at: 2), in: content)!]) ?? 0
            let second = match.range(at: 3).location != NSNotFound ? Int(content[Range(match.range(at: 3), in: content)!]) ?? 0 : nil
            let third  = match.range(at: 4).location != NSNotFound ? Int(content[Range(match.range(at: 4), in: content)!]) ?? 0 : nil

            let (hours, minutes, seconds): (Int, Int, Int)
            if let third = third { // H:MM:SS
                hours = first
                minutes = second ?? 0
                seconds = third
            } else if let second = second { // MM:SS
                hours = 0
                minutes = first
                seconds = second
            } else { // Only seconds
                hours = 0
                minutes = 0
                seconds = first
            }

            let elapsed = Double(hours * 3600 + minutes * 60 + seconds)
            return createTask(from: taskName, elapsed: elapsed, isCompleted: isCompleted)
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
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.hasActiveTasks else { return }
            self.objectWillChange.send()
        }
    }
    
    private func startBlinkTimer() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.hasActiveTasks {
                self.showColons.toggle()
            } else {
                self.showColons = true
            }
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
    
    func copySummaryToClipboard() {
        let taskSummary = taskLines().joined(separator: "\n")
        let total = totalElapsed
        let summaryWithTotal = taskSummary.isEmpty
            ? NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks")
            : "\(taskSummary)\n\n\(NSLocalizedString("Total", comment: "Label for total time")): \(total.hms)"
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
              let _ = tasks.firstIndex(where: { $0.id == pausedID }) else { 
            return 
        }
        
        // First pause any currently active task
        pauseCurrentActiveTask()
        
        // Restart the paused task
        activeTaskID = pausedID
        activeTaskStartTime = Date()
        
        // Clear the last paused ID to prevent re-triggering
        lastPausedTaskID = nil
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
            moveCompletedTasksToEnd(&tasks)
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
