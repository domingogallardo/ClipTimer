//
//  TaskStoreTests.swift
//  ClipTimerTests
//
//  Created by Tests
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStoreTests: XCTestCase {
    
    var taskStore: TaskStore!
    
    override func setUp() {
        super.setUp()
        
        taskStore = TaskStore()
        // Clear persisted data using TaskStore's testing interface
        taskStore.clearPersistedData()
    }
    
    override func tearDown() {
        // Clean up after each test using TaskStore's testing interface
        taskStore.clearPersistedData()
        taskStore = nil
        super.tearDown()
    }
    
    // MARK: - Task Formatting Tests
    
    func testTaskFormattingWithBulletSymbols() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Tasks with bullet symbols
        let clipboardContent = "• Write Report\n• Review Code\n• Fix Bug"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify output uses consistent formatting
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("• Write Report: 0:00:00"))
        XCTAssertTrue(summaryText.contains("• Review Code: 0:00:00"))
        XCTAssertTrue(summaryText.contains("• Fix Bug: 0:00:00"))
    }
    
    func testTaskFormattingWithDashSymbols() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Tasks with dash symbols
        let clipboardContent = "- First Task\n- Second Task"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Replace tasks from clipboard
        taskStore.replaceTasksFromClipboard()
        
        // Verify output uses consistent formatting
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("- First Task: 0:00:00"))
        XCTAssertTrue(summaryText.contains("- Second Task: 0:00:00"))
    }
    
    func testTaskFormattingWithMixedSymbols() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Tasks with mixed symbols (should use first one found)
        let clipboardContent = "* Task One\n→ Task Two\n✓ Task Three"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify output uses consistent formatting (first symbol detected)
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("* Task One: 0:00:00"))
        XCTAssertTrue(summaryText.contains("* Task Two: 0:00:00"))
        XCTAssertTrue(summaryText.contains("* Task Three: 0:00:00"))
    }
    
    func testTaskFormattingWithPlainText() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Plain text without symbols
        let clipboardContent = "Plain Task One\nPlain Task Two"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify output without symbols
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("Plain Task One: 0:00:00"))
        XCTAssertTrue(summaryText.contains("Plain Task Two: 0:00:00"))
        XCTAssertFalse(summaryText.contains("• Plain"))
        XCTAssertFalse(summaryText.contains("- Plain"))
        XCTAssertFalse(summaryText.contains("* Plain"))
    }
    
    func testTaskFormattingWithTabSymbols() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Tasks with tab-separated symbols
        let clipboardContent = "•\tTab Task One\n•\tTab Task Two"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify output uses consistent formatting
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("•\tTab Task One: 0:00:00"))
        XCTAssertTrue(summaryText.contains("•\tTab Task Two: 0:00:00"))
    }
    
    func testTaskFormattingPreservesSymbolsInTaskNames() {
        // Clear any existing tasks
        taskStore.tasks = []
        
        // Input: Tasks with symbols in the name (not at the beginning)
        let clipboardContent = "- Fix bug-123\n- Review item • important"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify symbols within task names are preserved
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("- Fix bug-123: 0:00:00"))
        XCTAssertTrue(summaryText.contains("- Review item • important: 0:00:00"))
    }
    
    // MARK: - Symbol Precedence Behavior Tests
    
    func testExistingSymbolTakesPrecedenceWhenAddingTasks() {
        // Start with tasks that have an established symbol
        taskStore.tasks = []
        
        // First, add tasks with bullet symbols to establish the symbol
        let firstContent = "• Existing Task 1\n• Existing Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(firstContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Now ADD (not replace) tasks with different symbols
        let secondContent = "- New Task 1\n* New Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(secondContent, forType: .string)
        taskStore.addTasksFromClipboard()  // Using ADD, not replace
        
        // Verify all tasks use the existing symbol (bullet) when adding
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("• Existing Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("• Existing Task 2: 0:00:00"))
        XCTAssertTrue(summaryText.contains("• New Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("• New Task 2: 0:00:00"))
        
        // Verify it doesn't use the new symbols when adding
        XCTAssertFalse(summaryText.contains("- New Task"))
        XCTAssertFalse(summaryText.contains("* New Task"))
        XCTAssertEqual(taskStore.itemSymbol, "• ")
    }
    
    func testNewSymbolDetectedWhenNoExistingSymbol() {
        // Start with plain text tasks (no symbols)
        taskStore.tasks = [
            Task(name: "Plain Task 1", elapsed: 30),
            Task(name: "Plain Task 2", elapsed: 45)
        ]
        
        // Add tasks with symbols
        let clipboardContent = "→ Arrow Task 1\n→ Arrow Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Verify ALL tasks (existing + new) use the newly detected symbol
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("→ Plain Task 1: 0:00:30"))
        XCTAssertTrue(summaryText.contains("→ Plain Task 2: 0:00:45"))
        XCTAssertTrue(summaryText.contains("→ Arrow Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("→ Arrow Task 2: 0:00:00"))
    }
    
    func testReplaceTasksAdoptsNewSymbol() {
        // Start with tasks with existing symbol
        taskStore.tasks = []
        
        // Add tasks with bullet symbol first
        let firstContent = "• Old Task 1\n• Old Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(firstContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Replace all tasks with different symbol
        let replaceContent = "✓ New Task 1\n✓ New Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(replaceContent, forType: .string)
        taskStore.replaceTasksFromClipboard()
        
        // Verify all tasks use the new symbol (replacing takes precedence)
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("✓ New Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("✓ New Task 2: 0:00:00"))
        XCTAssertFalse(summaryText.contains("• New Task"))
        XCTAssertFalse(summaryText.contains("• Old Task")) // Old tasks are gone
        XCTAssertEqual(taskStore.itemSymbol, "✓ ")
    }
    
    func testReplaceTasksDetectsNewSymbolWhenNoExistingSymbol() {
        // Start with plain text tasks (no symbol established)
        taskStore.tasks = [
            Task(name: "Plain Task 1", elapsed: 30),
            Task(name: "Plain Task 2", elapsed: 60)
        ]
        
        // Replace with symbolized tasks
        let replaceContent = "✓ Replacement Task 1\n✓ Replacement Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(replaceContent, forType: .string)
        taskStore.replaceTasksFromClipboard()
        
        // Verify new tasks use the detected symbol
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("✓ Replacement Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("✓ Replacement Task 2: 0:00:00"))
        XCTAssertFalse(summaryText.contains("Plain Task")) // Old tasks are gone
    }
    
    func testReplaceSymbolizedTasksWithPlainTextResetsSymbol() {
        // Start with symbolized tasks
        taskStore.tasks = []
        
        // Add tasks with symbol first
        let symbolContent = "• Bullet Task 1\n• Bullet Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(symbolContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Verify symbol was established
        XCTAssertEqual(taskStore.itemSymbol, "• ")
        
        // Replace with plain text tasks (no symbols)
        let plainContent = "Plain Task 1\nPlain Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainContent, forType: .string)
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was reset and tasks appear without symbols
        XCTAssertEqual(taskStore.itemSymbol, "")
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("Plain Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("Plain Task 2: 0:00:00"))
        XCTAssertFalse(summaryText.contains("• Plain Task"))
        XCTAssertFalse(summaryText.contains("• Bullet Task"))
    }
    
    func testAddPlainTextToSymbolizedTasksKeepsExistingSymbol() {
        // Start with tasks that have symbols
        taskStore.tasks = []
        
        // First, establish symbol with formatted tasks
        let symbolContent = "☐ Checkbox Task 1\n☐ Checkbox Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(symbolContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Add plain text tasks
        let plainContent = "Plain Task 1\nPlain Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Verify all tasks use the existing symbol
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("☐ Checkbox Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("☐ Checkbox Task 2: 0:00:00"))
        XCTAssertTrue(summaryText.contains("☐ Plain Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("☐ Plain Task 2: 0:00:00"))
    }
    
    func testAddSymbolizedTasksToPlainTextDetectsNewSymbol() {
        // Start with plain text tasks only
        taskStore.tasks = [
            Task(name: "Existing Plain 1", elapsed: 60),
            Task(name: "Existing Plain 2", elapsed: 120)
        ]
        
        // Add symbolized tasks 
        let symbolContent = "* Star Task 1\n* Star Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(symbolContent, forType: .string)
        taskStore.addTasksFromClipboard()
        
        // Verify ALL tasks now use the detected symbol
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("* Existing Plain 1: 0:01:00"))
        XCTAssertTrue(summaryText.contains("* Existing Plain 2: 0:02:00"))
        XCTAssertTrue(summaryText.contains("* Star Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("* Star Task 2: 0:00:00"))
    }

    // MARK: - Task Parsing Tests
    
    func testParseTaskLineBasic() {
        let result = taskStore.parseTaskLine("Test Task")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 0)
    }
    
    func testParseTaskLineWithTime() {
        let result = taskStore.parseTaskLine("Test Task: 1:30:45")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 5445) // 1*3600 + 30*60 + 45
    }
    
    func testParseTaskLineWithMinutesSeconds() {
        let result = taskStore.parseTaskLine("Test Task: 30:45")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 1845) // 30*60 + 45
    }
    
    func testParseTaskLineWithBulletPoints() {
        let result = taskStore.parseTaskLine("- Test Task")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Task") // Should be cleaned
    }
    
    func testParseTaskLineWithMultipleBulletTypes() {
        let bulletTasks = [
            "- Task 1",
            "* Task 2", 
            "• Task 3"
        ]
        
        for taskLine in bulletTasks {
            let result = taskStore.parseTaskLine(taskLine)
            XCTAssertNotNil(result)
            XCTAssertTrue(result!.name.hasPrefix("Task"))
            XCTAssertFalse(result!.name.contains("-"))
            XCTAssertFalse(result!.name.contains("*"))
            XCTAssertFalse(result!.name.contains("•"))
        }
    }
    
    func testParseTaskLineEmptyString() {
        let result = taskStore.parseTaskLine("")
        XCTAssertNil(result)
    }
    
    func testParseTaskLineWhitespaceOnly() {
        let result = taskStore.parseTaskLine("   \t\n   ")
        XCTAssertNil(result)
    }
    
    // MARK: - Task Management Tests
    
    func testInitialState() {
        // Clear tasks to test the initial state properly
        taskStore.tasks = []
        
        XCTAssertTrue(taskStore.tasks.isEmpty)
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertTrue(taskStore.showColons)
        XCTAssertEqual(taskStore.totalElapsed, 0)
    }
    
    func testDeleteTask() {
        // Add a task
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Delete the task
        taskStore.delete(task)
        
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testTotalElapsedCalculation() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        
        taskStore.tasks = [task1, task2]
        
        XCTAssertEqual(taskStore.totalElapsed, 300)
    }
    
    func testSummaryTextEmpty() {
        // Ensure we start with empty tasks
        taskStore.tasks = []
        XCTAssertEqual(taskStore.summaryText, "No tasks.")
    }
    
    func testSummaryTextWithTasks() {
        let task1 = Task(name: "Task 1", elapsed: 60)
        let task2 = Task(name: "Task 2", elapsed: 120)
        
        taskStore.tasks = [task1, task2]
        
        let summary = taskStore.summaryText
        XCTAssertTrue(summary.contains("Task 1: 0:01:00"))
        XCTAssertTrue(summary.contains("Task 2: 0:02:00"))
        XCTAssertTrue(summary.contains("Working time: 0:03:00"))
    }
    
    func testHasActiveTasks() {
        XCTAssertFalse(taskStore.hasActiveTasks)
        
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        taskStore.activeTaskID = task.id
        
        XCTAssertTrue(taskStore.hasActiveTasks)
    }
    
    func testActiveTask() {
        XCTAssertNil(taskStore.activeTask)
        
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        taskStore.activeTaskID = task.id
        
        let activeTask = taskStore.activeTask
        XCTAssertNotNil(activeTask)
        XCTAssertEqual(activeTask?.id, task.id)
    }
    
    // MARK: - Task Toggle Tests
    
    func testToggleTaskActivation() {
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate task
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Deactivate task
        taskStore.toggle(task)
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }
    
    func testToggleOnlyOneTaskActiveAtTime() {
        let task1 = Task(name: "Task 1", elapsed: 0)
        let task2 = Task(name: "Task 2", elapsed: 0)
        taskStore.tasks = [task1, task2]
        
        // Activate first task
        taskStore.toggle(task1)
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        
        // Activate second task (should deactivate first)
        taskStore.toggle(task2)
        XCTAssertEqual(taskStore.activeTaskID, task2.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime) // Should have start time for active task
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseActiveTask() {
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate and then pause
        taskStore.toggle(task)
        taskStore.pauseActiveTask()
        
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }
    
    func testRestartLastPausedTask() {
        let task = Task(name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate, pause, then restart
        taskStore.toggle(task)
        taskStore.pauseActiveTask()
        taskStore.restartLastPausedTask()
        
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
    }

    // MARK: - Local Persistence Tests

    func testTaskCodable() {
        // Test Task can be encoded and decoded
        let originalTask = Task(name: "Test Task", elapsed: 123.5)
        
        do {
            // Encode
            let encoder = JSONEncoder()
            let data = try encoder.encode(originalTask)
            XCTAssertGreaterThan(data.count, 0)
            
            // Decode
            let decoder = JSONDecoder()
            let decodedTask = try decoder.decode(Task.self, from: data)
            
            // Verify all properties match
            XCTAssertEqual(decodedTask.id, originalTask.id)
            XCTAssertEqual(decodedTask.name, originalTask.name)
            XCTAssertEqual(decodedTask.elapsed, originalTask.elapsed)
        } catch {
            XCTFail("Task Codable failed: \(error)")
        }
    }

    func testTaskArrayCodable() {
        // Test that arrays of tasks can be encoded/decoded
        let tasks = [
            Task(name: "Task 1", elapsed: 100),
            Task(name: "Task 2", elapsed: 200),
            Task(name: "Task 3", elapsed: 300)
        ]
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tasks)
            
            let decoder = JSONDecoder()
            let decodedTasks = try decoder.decode([Task].self, from: data)
            
            XCTAssertEqual(decodedTasks.count, tasks.count)
            
            for (original, decoded) in zip(tasks, decodedTasks) {
                XCTAssertEqual(decoded.id, original.id)
                XCTAssertEqual(decoded.name, original.name)
                XCTAssertEqual(decoded.elapsed, original.elapsed)
            }
        } catch {
            XCTFail("Task array Codable failed: \(error)")
        }
    }

    func testLocalPersistenceRoundTrip() {
        // Create a fresh TaskStore for this test to avoid interference
        let testStore = TaskStore()
        
        // Clear any existing data
        testStore.clearPersistedData()
        
        // Add some tasks
        let task1 = Task(name: "Persistent Task 1", elapsed: 150)
        let task2 = Task(name: "Persistent Task 2", elapsed: 250)
        testStore.tasks = [task1, task2]
        
        // Force save the tasks
        testStore.forceSave()
        
        // Clear tasks from memory and reload
        testStore.tasks = []
        
        // Create a new store to simulate app restart
        let newStore = TaskStore()
        
        // Verify tasks were loaded automatically
        XCTAssertEqual(newStore.tasks.count, 2)
        XCTAssertEqual(newStore.tasks[0].name, "Persistent Task 1")
        XCTAssertEqual(newStore.tasks[0].elapsed, 150)
        XCTAssertEqual(newStore.tasks[1].name, "Persistent Task 2")
        XCTAssertEqual(newStore.tasks[1].elapsed, 250)
    }

    func testAutoSaveOnAddTasks() {
        // Start with empty task list
        taskStore.tasks = []
        
        // Mock clipboard content
        let clipboardContent = "Task from clipboard: 1:23:45\nAnother task"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Add tasks from clipboard
        taskStore.addTasksFromClipboard()
        
        // Verify tasks were added
        XCTAssertEqual(taskStore.tasks.count, 2)
        
        // Verify tasks were saved using TaskStore's testing interface
        XCTAssertTrue(taskStore.hasPersistedData())
        XCTAssertEqual(taskStore.getPersistedTaskCount(), 2)
        
        // Verify saved data content
        if let savedTasks = taskStore.getPersistedTasks() {
            XCTAssertEqual(savedTasks.count, 2)
            XCTAssertEqual(savedTasks[0].name, "Task from clipboard")
            XCTAssertEqual(savedTasks[0].elapsed, 5025) // 1:23:45 = 5025 seconds
        } else {
            XCTFail("Failed to retrieve persisted tasks")
        }
    }

    func testAutoSaveOnReplaceTasks() {
        // Start with some existing tasks
        taskStore.tasks = [Task(name: "Existing", elapsed: 100)]
        
        // Mock clipboard content
        let clipboardContent = "Replacement task"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        // Replace tasks
        taskStore.replaceTasksFromClipboard()
        
        // Verify tasks were replaced
        XCTAssertEqual(taskStore.tasks.count, 1)
        XCTAssertEqual(taskStore.tasks[0].name, "Replacement task")
        
        // Verify auto-save occurred using TaskStore's testing interface
        XCTAssertTrue(taskStore.hasPersistedData())
        XCTAssertEqual(taskStore.getPersistedTaskCount(), 1)
        
        if let savedTasks = taskStore.getPersistedTasks() {
            XCTAssertEqual(savedTasks.count, 1)
            XCTAssertEqual(savedTasks[0].name, "Replacement task")
        } else {
            XCTFail("Failed to retrieve persisted tasks after replace")
        }
    }

    func testAutoSaveOnDeleteTask() {
        // Create tasks
        let task1 = Task(name: "Keep", elapsed: 100)
        let task2 = Task(name: "Delete", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Delete one task
        taskStore.delete(task2)
        
        // Verify task was deleted
        XCTAssertEqual(taskStore.tasks.count, 1)
        XCTAssertEqual(taskStore.tasks[0].name, "Keep")
        
        // Verify auto-save occurred using TaskStore's testing interface
        XCTAssertTrue(taskStore.hasPersistedData())
        XCTAssertEqual(taskStore.getPersistedTaskCount(), 1)
        
        if let savedTasks = taskStore.getPersistedTasks() {
            XCTAssertEqual(savedTasks.count, 1)
            XCTAssertEqual(savedTasks[0].name, "Keep")
        } else {
            XCTFail("Failed to retrieve persisted tasks after delete")
        }
    }

    func testAutoSaveOnCutAllTasks() {
        // Create tasks
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Cut all tasks
        taskStore.cutAllTasks()
        
        // Verify all tasks were removed
        XCTAssertEqual(taskStore.tasks.count, 0)
        
        // Verify auto-save occurred (empty array) using TaskStore's testing interface
        XCTAssertTrue(taskStore.hasPersistedData()) // Data exists but is empty
        XCTAssertEqual(taskStore.getPersistedTaskCount(), 0)
        
        if let savedTasks = taskStore.getPersistedTasks() {
            XCTAssertEqual(savedTasks.count, 0)
        } else {
            XCTFail("Failed to retrieve persisted tasks after cut all")
        }
    }

    func testPersistenceOnAppRestart() {
        // Simulate app restart by creating a new TaskStore
        let originalStore = TaskStore()
        originalStore.clearPersistedData() // Clean slate
        
        // Add tasks to original store
        let task1 = Task(name: "Restart Task 1", elapsed: 300)
        let task2 = Task(name: "Restart Task 2", elapsed: 400)
        originalStore.tasks = [task1, task2]
        
        // Manually save (simulating auto-save)
        originalStore.forceSave()
        
        // Create new store (simulating app restart)
        let newStore = TaskStore()
        
        // Verify tasks were loaded automatically
        XCTAssertEqual(newStore.tasks.count, 2)
        XCTAssertEqual(newStore.tasks[0].name, "Restart Task 1")
        XCTAssertEqual(newStore.tasks[0].elapsed, 300)
        XCTAssertEqual(newStore.tasks[1].name, "Restart Task 2")
        XCTAssertEqual(newStore.tasks[1].elapsed, 400)
    }

    // MARK: - App Lifecycle Tests

    func testPauseActiveTaskAndSaveWithNoActiveTask() {
        // Test when no task is active
        taskStore.tasks = [
            Task(name: "Task 1", elapsed: 100)
        ]
        
        // Should not crash and should handle gracefully
        taskStore.pauseActiveTaskAndSave()
        
        // Verify no task is active
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }

    func testPauseActiveTaskAndSaveWithActiveTask() {
        // Create a task and make it active
        let task = Task(name: "Active Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // Activate the task
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Simulate some time passing
        let originalElapsed = task.elapsed
        Thread.sleep(forTimeInterval: 0.1) // 100ms
        
        // Call pauseActiveTaskAndSave (simulating app termination)
        taskStore.pauseActiveTaskAndSave()
        
        // Verify task is no longer active
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        
        // Verify the task was set as last paused
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id)
        
        // Verify elapsed time was updated (should be slightly more than original)
        XCTAssertGreaterThan(taskStore.tasks[0].elapsed, originalElapsed)
        
        // Verify data was saved
        XCTAssertTrue(taskStore.hasPersistedData())
    }

    func testPauseActiveTaskAndSavePreservesLastPausedTask() {
        // Create two tasks
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Activate first task, then pause it manually
        taskStore.toggle(task1)
        taskStore.pauseActiveTask()
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task1.id)
        
        // Activate second task
        taskStore.toggle(task2)
        XCTAssertEqual(taskStore.activeTaskID, task2.id)
        
        // Call pauseActiveTaskAndSave (simulating app termination)
        taskStore.pauseActiveTaskAndSave()
        
        // Verify the second task is now the last paused task
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task2.id)
        XCTAssertNil(taskStore.activeTaskID)
    }

    func testAppTerminationWorkflow() {
        // Simulate a complete workflow: start task, work on it, app closes, app reopens
        
        // Step 1: Create and start a task
        let task = Task(name: "Work Task", elapsed: 500)
        taskStore.tasks = [task]
        taskStore.toggle(task)
        
        let originalElapsed = task.elapsed
        Thread.sleep(forTimeInterval: 0.1) // Simulate some work time
        
        // Step 2: App terminates (pauseActiveTaskAndSave is called)
        taskStore.pauseActiveTaskAndSave()
        
        // Verify state after termination
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id)
        XCTAssertTrue(taskStore.hasPersistedData())
        
        // Step 3: Simulate app restart
        let newTaskStore = TaskStore()
        
        // Verify tasks were loaded
        XCTAssertEqual(newTaskStore.tasks.count, 1)
        XCTAssertEqual(newTaskStore.tasks[0].name, "Work Task")
        XCTAssertGreaterThan(newTaskStore.tasks[0].elapsed, originalElapsed)
        
        // Verify we can restart the last paused task
        // Note: lastPausedTaskID is not persisted across app restarts by design
        // This could be a future enhancement if needed
    }
    
    func testElapsedTimePreservationOnAppTermination() {
        // Create a task and simulate some elapsed time
        let task = Task(name: "Time Test", elapsed: 100.0) // Start with 100 seconds
        taskStore.tasks = [task]
        
        let initialElapsed = task.elapsed
        print("🔍 Initial elapsed: \(initialElapsed)")
        
        // Activate the task (this should start the timer)
        taskStore.toggle(task)
        
        // Simulate some active time
        Thread.sleep(forTimeInterval: 0.2) // 200ms
        
        // Get current elapsed (should be initial + active time)
        let currentElapsed = task.currentElapsed(activeTaskID: taskStore.activeTaskID, startTime: taskStore.activeTaskStartTime)
        print("🔍 Current elapsed before termination: \(currentElapsed)")
        XCTAssertGreaterThan(currentElapsed, initialElapsed)
        
        // Terminate app (this should pause and save)
        taskStore.pauseActiveTaskAndSave()
        
        // Verify task is no longer active
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        
        // Verify elapsed time was preserved in the task itself
        print("🔍 Task elapsed after pause: \(taskStore.tasks[0].elapsed)")
        XCTAssertGreaterThan(taskStore.tasks[0].elapsed, initialElapsed)
        XCTAssertEqual(taskStore.tasks[0].elapsed, currentElapsed, accuracy: 0.01)
        
        // Simulate app restart
        let newTaskStore = TaskStore()
        
        // Verify the persisted elapsed time is correct
        XCTAssertEqual(newTaskStore.tasks.count, 1)
        print("🔍 Loaded task elapsed: \(newTaskStore.tasks[0].elapsed)")
        XCTAssertGreaterThan(newTaskStore.tasks[0].elapsed, initialElapsed)
        XCTAssertEqual(newTaskStore.tasks[0].elapsed, currentElapsed, accuracy: 0.01)
    }
    
    // MARK: - Item Symbol Reset Tests
    
    func testCutAllTasksResetsItemSymbol() {
        // Setup: Add tasks with symbol
        let clipboardContent = "• Task 1\n• Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was detected
        XCTAssertEqual(taskStore.itemSymbol, "• ")
        
        // Cut all tasks
        taskStore.cutAllTasks()
        
        // Verify symbol was reset
        XCTAssertEqual(taskStore.itemSymbol, "")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testDeleteLastTaskResetsItemSymbol() {
        // Setup: Add tasks with symbol
        let clipboardContent = "- Only Task"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was detected and we have one task
        XCTAssertEqual(taskStore.itemSymbol, "- ")
        XCTAssertEqual(taskStore.tasks.count, 1)
        
        // Delete the only task
        taskStore.delete(taskStore.tasks[0])
        
        // Verify symbol was reset
        XCTAssertEqual(taskStore.itemSymbol, "")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testDeleteTaskKeepsSymbolWhenTasksRemain() {
        // Setup: Add multiple tasks with symbol
        let clipboardContent = "* Task 1\n* Task 2\n* Task 3"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was detected and we have three tasks
        XCTAssertEqual(taskStore.itemSymbol, "* ")
        XCTAssertEqual(taskStore.tasks.count, 3)
        
        // Delete one task
        taskStore.delete(taskStore.tasks[0])
        
        // Verify symbol is kept and we have two tasks
        XCTAssertEqual(taskStore.itemSymbol, "* ")
        XCTAssertEqual(taskStore.tasks.count, 2)
    }
    
    func testReplaceWithEmptyListResetsItemSymbol() {
        // Setup: Add tasks with symbol
        let clipboardContent = "→ Task 1\n→ Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was detected
        XCTAssertEqual(taskStore.itemSymbol, "→ ")
        XCTAssertEqual(taskStore.tasks.count, 2)
        
        // Replace with empty content
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("", forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was reset
        XCTAssertEqual(taskStore.itemSymbol, "")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testReplaceWithWhitespaceOnlyResetsItemSymbol() {
        // Setup: Add tasks with symbol
        let clipboardContent = "✓ Task 1\n✓ Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was detected
        XCTAssertEqual(taskStore.itemSymbol, "✓ ")
        XCTAssertEqual(taskStore.tasks.count, 2)
        
        // Replace with whitespace only
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("   \n\t\n   ", forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was reset
        XCTAssertEqual(taskStore.itemSymbol, "")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testSymbolResetAllowsNewSymbolDetection() {
        // Setup: Add tasks with first symbol
        let firstContent = "• Task 1\n• Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(firstContent, forType: .string)
        
        taskStore.replaceTasksFromClipboard()
        
        // Verify first symbol was detected
        XCTAssertEqual(taskStore.itemSymbol, "• ")
        
        // Cut all tasks (resets symbol)
        taskStore.cutAllTasks()
        XCTAssertEqual(taskStore.itemSymbol, "")
        
        // Add tasks with different symbol
        let secondContent = "- New Task 1\n- New Task 2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(secondContent, forType: .string)
        
        taskStore.addTasksFromClipboard()
        
        // Verify new symbol was detected
        XCTAssertEqual(taskStore.itemSymbol, "- ")
        
        // Verify output uses new symbol
        let summaryText = taskStore.summaryText
        XCTAssertTrue(summaryText.contains("- New Task 1: 0:00:00"))
        XCTAssertTrue(summaryText.contains("- New Task 2: 0:00:00"))
    }
} 