//
//  TaskStoreTests.swift
//  ClipTimerTests
//
//  Created by Tests
//

import XCTest
import Combine
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
        clearTasks()
        setupClipboard(with: bulletTasksContent())
        
        taskStore.addTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "• Write Report: 0:00:00",
            "• Review Code: 0:00:00", 
            "• Fix Bug: 0:00:00"
        ], in: summaryText)
    }
    
    func testTaskFormattingWithDashSymbols() {
        clearTasks()
        setupClipboard(with: dashTasksContent())
        
        taskStore.replaceTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "- First Task: 0:00:00",
            "- Second Task: 0:00:00"
        ], in: summaryText)
    }
    
    func testTaskFormattingWithMixedSymbols() {
        clearTasks()
        setupClipboard(with: mixedSymbolTasksContent())
        
        taskStore.addTasksFromClipboard()
        
        // Verify output uses consistent formatting (first symbol detected)
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "* Task One: 0:00:00",
            "* Task Two: 0:00:00",
            "* Task Three: 0:00:00"
        ], in: summaryText)
    }
    
    func testTaskFormattingWithPlainText() {
        clearTasks()
        setupClipboard(with: plainTextTasksContent())
        
        taskStore.addTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "Plain Task One: 0:00:00",
            "Plain Task Two: 0:00:00"
        ], in: summaryText)
        assertTasksNotInSummary([
            "• Plain",
            "- Plain", 
            "* Plain"
        ], in: summaryText)
    }
    
    func testTaskFormattingWithTabSymbols() {
        clearTasks()
        setupClipboard(with: tabSymbolTasksContent())
        
        taskStore.addTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "•\tTab Task One: 0:00:00",
            "•\tTab Task Two: 0:00:00"
        ], in: summaryText)
    }
    
    func testTaskFormattingPreservesSymbolsInTaskNames() {
        clearTasks()
        setupClipboard(with: "- Fix bug-123\n- Review item • important")
        
        taskStore.addTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "- Fix bug-123: 0:00:00",
            "- Review item • important: 0:00:00"
        ], in: summaryText)
    }
    
    // MARK: - Symbol Precedence Behavior Tests
    
    func testExistingSymbolTakesPrecedenceWhenAddingTasks() {
        clearTasks()
        
        // First, add tasks with bullet symbols to establish the symbol
        setupClipboard(with: "• Existing Task 1\n• Existing Task 2")
        taskStore.addTasksFromClipboard()
        
        // Now ADD (not replace) tasks with different symbols
        setupClipboard(with: "- New Task 1\n* New Task 2")
        taskStore.addTasksFromClipboard()  // Using ADD, not replace
        
        // Verify all tasks use the existing symbol (bullet) when adding
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "• Existing Task 1: 0:00:00",
            "• Existing Task 2: 0:00:00",
            "• New Task 1: 0:00:00",
            "• New Task 2: 0:00:00"
        ], in: summaryText)
        
        // Verify it doesn't use the new symbols when adding
        assertTasksNotInSummary([
            "- New Task",
            "* New Task"
        ], in: summaryText)
        
        assertItemSymbol("• ")
    }
    
    func testNewSymbolDetectedWhenNoExistingSymbol() {
        // Start with plain text tasks (no symbols)
        taskStore.tasks = [
            Task(name: "Plain Task 1", elapsed: 30),
            Task(name: "Plain Task 2", elapsed: 45)
        ]
        
        setupClipboard(with: "→ Arrow Task 1\n→ Arrow Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify ALL tasks (existing + new) use the newly detected symbol
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "→ Plain Task 1: 0:00:30",
            "→ Plain Task 2: 0:00:45",
            "→ Arrow Task 1: 0:00:00",
            "→ Arrow Task 2: 0:00:00"
        ], in: summaryText)
    }
    
    func testReplaceTasksAdoptsNewSymbol() {
        clearTasks()
        
        // Add tasks with bullet symbol first
        setupClipboard(with: "• Old Task 1\n• Old Task 2")
        taskStore.addTasksFromClipboard()
        
        // Replace all tasks with different symbol
        setupClipboard(with: "✓ New Task 1\n✓ New Task 2")
        taskStore.replaceTasksFromClipboard()
        
        // Verify all tasks use the new symbol (replacing takes precedence)
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "✓ New Task 1: 0:00:00",
            "✓ New Task 2: 0:00:00"
        ], in: summaryText)
        assertTasksNotInSummary([
            "• New Task",
            "• Old Task"
        ], in: summaryText)
        assertItemSymbol("✓ ")
    }
    
    func testReplaceTasksDetectsNewSymbolWhenNoExistingSymbol() {
        // Start with plain text tasks (no symbol established)
        taskStore.tasks = [
            Task(name: "Plain Task 1", elapsed: 30),
            Task(name: "Plain Task 2", elapsed: 60)
        ]
        
        setupClipboard(with: "✓ Replacement Task 1\n✓ Replacement Task 2")
        taskStore.replaceTasksFromClipboard()
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "✓ Replacement Task 1: 0:00:00",
            "✓ Replacement Task 2: 0:00:00"
        ], in: summaryText)
        assertTasksNotInSummary(["Plain Task"], in: summaryText)
    }
    
    func testReplaceSymbolizedTasksWithPlainTextResetsSymbol() {
        clearTasks()
        
        // Add tasks with symbol first
        setupClipboard(with: "• Bullet Task 1\n• Bullet Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify symbol was established
        assertItemSymbol("• ")
        
        // Replace with plain text tasks (no symbols)
        setupClipboard(with: plainTextTasksContent())
        taskStore.replaceTasksFromClipboard()
        
        // Verify symbol was reset and tasks appear without symbols
        assertItemSymbol("")
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "Plain Task One: 0:00:00",
            "Plain Task Two: 0:00:00"
        ], in: summaryText)
        assertTasksNotInSummary([
            "• Plain Task",
            "• Bullet Task"
        ], in: summaryText)
    }
    
    func testAddPlainTextToSymbolizedTasksKeepsExistingSymbol() {
        clearTasks()
        
        // First, establish symbol with formatted tasks
        setupClipboard(with: "☐ Checkbox Task 1\n☐ Checkbox Task 2")
        taskStore.addTasksFromClipboard()
        
        // Add plain text tasks
        setupClipboard(with: "Plain Task 1\nPlain Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify all tasks use the existing symbol
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "☐ Checkbox Task 1: 0:00:00",
            "☐ Checkbox Task 2: 0:00:00",
            "☐ Plain Task 1: 0:00:00",
            "☐ Plain Task 2: 0:00:00"
        ], in: summaryText)
    }
    
    func testAddSymbolizedTasksToPlainTextDetectsNewSymbol() {
        // Start with plain text tasks only
        taskStore.tasks = [
            Task(name: "Existing Plain 1", elapsed: 60),
            Task(name: "Existing Plain 2", elapsed: 120)
        ]
        
        setupClipboard(with: "* Star Task 1\n* Star Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify ALL tasks now use the detected symbol
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "* Existing Plain 1: 0:01:00",
            "* Existing Plain 2: 0:02:00",
            "* Star Task 1: 0:00:00",
            "* Star Task 2: 0:00:00"
        ], in: summaryText)
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
        XCTAssertEqual(taskStore.summaryText, NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks"))
    }
    
    func testSummaryTextWithTasks() {
        let task1 = Task(name: "Task 1", elapsed: 60)
        let task2 = Task(name: "Task 2", elapsed: 120)
        
        taskStore.tasks = [task1, task2]
        
        let summary = taskStore.summaryText
        XCTAssertTrue(summary.contains("Task 1: 0:01:00"))
        XCTAssertTrue(summary.contains("Task 2: 0:02:00"))
        XCTAssertTrue(summary.contains("\(NSLocalizedString("Working time", comment: "Label for working time")): 0:03:00"))
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
        clearTasks()
        
        setupClipboard(with: "Task from clipboard: 1:23:45\nAnother task")
        taskStore.addTasksFromClipboard()
        
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
        
        setupClipboard(with: "Replacement task")
        taskStore.replaceTasksFromClipboard()
        
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
        setupClipboard(with: "• Task 1\n• Task 2")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("• ")
        
        taskStore.cutAllTasks()
        
        assertItemSymbol("")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testDeleteLastTaskResetsItemSymbol() {
        setupClipboard(with: "- Only Task")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("- ")
        XCTAssertEqual(taskStore.tasks.count, 1)
        
        taskStore.delete(taskStore.tasks[0])
        
        assertItemSymbol("")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testDeleteTaskKeepsSymbolWhenTasksRemain() {
        setupClipboard(with: "* Task 1\n* Task 2\n* Task 3")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("* ")
        XCTAssertEqual(taskStore.tasks.count, 3)
        
        taskStore.delete(taskStore.tasks[0])
        
        assertItemSymbol("* ")
        XCTAssertEqual(taskStore.tasks.count, 2)
    }
    
    func testReplaceWithEmptyListResetsItemSymbol() {
        setupClipboard(with: "→ Task 1\n→ Task 2")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("→ ")
        XCTAssertEqual(taskStore.tasks.count, 2)
        
        setupClipboard(with: "")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testReplaceWithWhitespaceOnlyResetsItemSymbol() {
        setupClipboard(with: "✓ Task 1\n✓ Task 2")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("✓ ")
        XCTAssertEqual(taskStore.tasks.count, 2)
        
        setupClipboard(with: "   \n\t\n   ")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("")
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testSymbolResetAllowsNewSymbolDetection() {
        setupClipboard(with: "• Task 1\n• Task 2")
        taskStore.replaceTasksFromClipboard()
        
        assertItemSymbol("• ")
        
        taskStore.cutAllTasks()
        assertItemSymbol("")
        
        setupClipboard(with: "- New Task 1\n- New Task 2")
        taskStore.addTasksFromClipboard()
        
        assertItemSymbol("- ")
        
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "- New Task 1: 0:00:00",
            "- New Task 2: 0:00:00"
        ], in: summaryText)
    }

    // MARK: - Timer Publisher Tests

    func testBlinkPublisherTogglesShowColons() {
        // Subject simulating the 0.5-s blink timer
        let blinkSubject = PassthroughSubject<Date, Never>()
        // Provide empty timer publisher because not needed
        let store = TaskStore(timerPublisher: Empty().eraseToAnyPublisher(),
                              blinkPublisher: blinkSubject.eraseToAnyPublisher())

        // Add an active task to enable blinking
        let task = Task(name: "Blink", elapsed: 0)
        store.tasks = [task]
        store.activeTaskID = task.id

        let initial = store.showColons
        blinkSubject.send(Date())
        XCTAssertNotEqual(store.showColons, initial)
        blinkSubject.send(Date())
        XCTAssertEqual(store.showColons, initial)
    }

    func testTimerPublisherTriggersObjectWillChange() {
        let timerSubject = PassthroughSubject<Date, Never>()
        let store = TaskStore(timerPublisher: timerSubject.eraseToAnyPublisher(),
                              blinkPublisher: Empty().eraseToAnyPublisher())

        // Activate a task so hasActiveTasks is true
        let task = Task(name: "Timer", elapsed: 0)
        store.tasks = [task]
        store.activeTaskID = task.id

        let expectation = expectation(description: "objectWillChange fired")
        var changeCount = 0
        let cancellable = store.objectWillChange
            .sink {
                changeCount += 1
                expectation.fulfill()
            }

        timerSubject.send(Date())
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(changeCount, 1)
        cancellable.cancel()
    }
    
    // MARK: - Test Helpers
    
    /// Helper method to set up clipboard with given content
    private func setupClipboard(with content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    /// Helper method to assert that expected task strings appear in summary
    private func assertTasksInSummary(_ expectedTasks: [String], in summary: String, file: StaticString = #file, line: UInt = #line) {
        for task in expectedTasks {
            XCTAssertTrue(summary.contains(task), "Missing task: \(task)", file: file, line: line)
        }
    }
    
    /// Helper method to assert that tasks do NOT appear in summary
    private func assertTasksNotInSummary(_ unexpectedTasks: [String], in summary: String, file: StaticString = #file, line: UInt = #line) {
        for task in unexpectedTasks {
            XCTAssertFalse(summary.contains(task), "Unexpected task found: \(task)", file: file, line: line)
        }
    }
    
    /// Helper method to verify item symbol state
    private func assertItemSymbol(_ expectedSymbol: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(taskStore.itemSymbol, expectedSymbol, "Item symbol mismatch", file: file, line: line)
    }
    
    /// Helper method to clear tasks and verify empty state
    private func clearTasks() {
        taskStore.tasks = []
        XCTAssertTrue(taskStore.tasks.isEmpty, "Tasks should be empty")
    }
    
    // MARK: - Test Data Generators
    
    /// Common test data for bullet symbol tasks
    private func bulletTasksContent() -> String {
        return "• Write Report\n• Review Code\n• Fix Bug"
    }
    
    /// Common test data for dash symbol tasks
    private func dashTasksContent() -> String {
        return "- First Task\n- Second Task"
    }
    
    /// Common test data for mixed symbol tasks
    private func mixedSymbolTasksContent() -> String {
        return "* Task One\n→ Task Two\n✓ Task Three"
    }
    
    /// Common test data for plain text tasks
    private func plainTextTasksContent() -> String {
        return "Plain Task One\nPlain Task Two"
    }
    
    /// Common test data for tab-separated symbol tasks
    private func tabSymbolTasksContent() -> String {
        return "•\tTab Task One\n•\tTab Task Two"
    }
} 