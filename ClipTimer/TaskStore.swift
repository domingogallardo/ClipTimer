//
//  TaskStore.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//


import SwiftUI
import AppKit
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var showColons: Bool = true
    @Published var activeTaskID: UUID?
    @Published var activeTaskStartTime: Date? = nil  // Single Source of Truth for start time
    @Published var itemSymbol: String = ""  // Símbolo de itemización para todas las tareas
    weak var undoManager: UndoManager?
    private var lastPausedTaskID: UUID? = nil
    private var timerCancellable: AnyCancellable?
    private var blinkCancellable: AnyCancellable?

    // MARK: - Local Persistence
    private let userDefaults = UserDefaults.standard
    private let localStorageKey = "saved_tasks"
    
    // MARK: - Constants
    
    /// All supported task list symbols for parsing and formatting
    private static let supportedSymbols = ["- ", "• ", "* ", "→ ", "✓ ", "☐ ", "-\t", "•\t", "*\t", "→\t", "✓\t", "☐\t"]

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
    
    init(timerPublisher: AnyPublisher<Date, Never>? = nil,
         blinkPublisher: AnyPublisher<Date, Never>? = nil) {
        startTimer(with: timerPublisher)
        startBlinkTimer(with: blinkPublisher)
        loadTasksLocally()  // 🆕 Load tasks on app start
    }
    
    deinit {
        timerCancellable?.cancel()
        blinkCancellable?.cancel()
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
    
    // MARK: - Helper para construir líneas de resumen
    private func taskLines() -> [String] {
        tasks.map { "\(itemSymbol)\($0.name): \(getCurrentElapsed(for: $0).hms)" }
    }
    
    var summaryText: String {
        if tasks.isEmpty { return "No tasks." }
        return taskLines().joined(separator: "\n") +
        "\n\nWorking time: \(totalElapsed.hms)"
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
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let lines = tasksString.split(separator: "\n").map { String($0) }
            
            mutateTasks(actionName: "Replace tasks") { tasks in
                // Always detect and set item symbol (replacing mode)
                detectAndSetItemSymbol(from: lines, forceDetection: true)
                
                let newTasks = lines.compactMap { parseTaskLine($0) }
                tasks = newTasks
            }
        }
    }
    
    func addTasksFromClipboard() {
        if let tasksString = NSPasteboard.general.string(forType: .string) {
            let lines = tasksString.split(separator: "\n").map { String($0) }
            
            mutateTasks(actionName: "Add tasks") { tasks in
                // Detect and set item symbol if needed (adding mode)
                detectAndSetItemSymbol(from: lines, forceDetection: false)
                
                let addedTasks = lines.compactMap { parseTaskLine($0) }
                tasks.append(contentsOf: addedTasks)
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

        // Único patrón que detecta "Nombre: H:MM:SS" o "Nombre: MM:SS"
        // 1- Task name (lazily up to colon)
        // 2- Primer bloque numérico (horas o minutos)
        // 3- Segundo bloque numérico opcional (minutos o segundos)
        // 4- Tercer bloque numérico opcional (segundos)
        let pattern = #"^(.*?):\s*(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*$"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = regex.firstMatch(in: trimmed, range: range) {
            let taskName = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let first  = Int(trimmed[Range(match.range(at: 2), in: trimmed)!]) ?? 0
            let second = match.range(at: 3).location != NSNotFound ? Int(trimmed[Range(match.range(at: 3), in: trimmed)!]) ?? 0 : nil
            let third  = match.range(at: 4).location != NSNotFound ? Int(trimmed[Range(match.range(at: 4), in: trimmed)!]) ?? 0 : nil

            let (hours, minutes, seconds): (Int, Int, Int)
            if let third = third { // H:MM:SS (all three numbers present)
                hours = first
                minutes = second ?? 0
                seconds = third
            } else if let second = second { // MM:SS
                hours = 0
                minutes = first
                seconds = second
            } else { // Solo un número tras los dos puntos → tratamos como segundos
                hours = 0
                minutes = 0
                seconds = first
            }

            let elapsed = Double(hours * 3600 + minutes * 60 + seconds)
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
        // Reglas:
        // • Replacing (forceDetection = true) → siempre recalcular símbolo (o vaciar si no se encuentra)
        // • Adding  (forceDetection = false) → sólo si aún no había símbolo
        guard forceDetection || itemSymbol.isEmpty else { return }

        // Buscar el primer símbolo válido en las líneas recibidas; si no hay, quedará "".
        itemSymbol = lines.compactMap(detectItemSymbol).first ?? ""
    }
    
    // Helper method to reset item symbol when no tasks remain
    private func resetItemSymbolIfNoTasks() {
        if tasks.isEmpty {
            itemSymbol = ""
        }
    }
    
    private func startTimer(with publisher: AnyPublisher<Date, Never>? = nil) {
        // Cancel previous subscription if any
        timerCancellable?.cancel()
        let pub = publisher ?? Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
        timerCancellable = pub
            .sink { [weak self] _ in
                guard let self, self.hasActiveTasks else { return }
                self.objectWillChange.send()
            }
    }
    
    private func startBlinkTimer(with publisher: AnyPublisher<Date, Never>? = nil) {
        blinkCancellable?.cancel()
        let pub = publisher ?? Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
        blinkCancellable = pub
            .sink { [weak self] _ in
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
