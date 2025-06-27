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
    
    // MARK: - Task Parsing Tests
    
    func testParseTaskLineBasic() {
        let result = taskStore.parseTaskLine("Test Task")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.rawName, "Test Task")
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 0)
    }
    
    func testParseTaskLineWithTime() {
        let result = taskStore.parseTaskLine("Test Task: 1:30:45")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.rawName, "Test Task")
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 5445) // 1*3600 + 30*60 + 45
    }
    
    func testParseTaskLineWithMinutesSeconds() {
        let result = taskStore.parseTaskLine("Test Task: 30:45")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.rawName, "Test Task")
        XCTAssertEqual(result?.name, "Test Task")
        XCTAssertEqual(result?.elapsed, 1845) // 30*60 + 45
    }
    
    func testParseTaskLineWithBulletPoints() {
        let result = taskStore.parseTaskLine("- Test Task")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.rawName, "- Test Task")
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
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Delete the task
        taskStore.delete(task)
        
        XCTAssertTrue(taskStore.tasks.isEmpty)
    }
    
    func testTotalElapsedCalculation() {
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 100)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 200)
        
        taskStore.tasks = [task1, task2]
        
        XCTAssertEqual(taskStore.totalElapsed, 300)
    }
    
    func testSummaryTextEmpty() {
        // Ensure we start with empty tasks
        taskStore.tasks = []
        XCTAssertEqual(taskStore.summaryText, "No tasks.")
    }
    
    func testSummaryTextWithTasks() {
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 60)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 120)
        
        taskStore.tasks = [task1, task2]
        
        let summary = taskStore.summaryText
        XCTAssertTrue(summary.contains("Task 1: 0:01:00"))
        XCTAssertTrue(summary.contains("Task 2: 0:02:00"))
        XCTAssertTrue(summary.contains("Working time: 0:03:00"))
    }
    
    func testHasActiveTasks() {
        XCTAssertFalse(taskStore.hasActiveTasks)
        
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        taskStore.activeTaskID = task.id
        
        XCTAssertTrue(taskStore.hasActiveTasks)
    }
    
    func testActiveTask() {
        XCTAssertNil(taskStore.activeTask)
        
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        taskStore.activeTaskID = task.id
        
        let activeTask = taskStore.activeTask
        XCTAssertNotNil(activeTask)
        XCTAssertEqual(activeTask?.id, task.id)
    }
    
    // MARK: - Task Toggle Tests
    
    func testToggleTaskActivation() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
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
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 0)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 0)
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
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate and then pause
        taskStore.toggle(task)
        taskStore.pauseActiveTask()
        
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }
    
    func testRestartLastPausedTask() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
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
        let originalTask = Task(rawName: "Test Task", name: "Test Task", elapsed: 123.5)
        
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
            XCTAssertEqual(decodedTask.rawName, originalTask.rawName)
            XCTAssertEqual(decodedTask.name, originalTask.name)
            XCTAssertEqual(decodedTask.elapsed, originalTask.elapsed)
        } catch {
            XCTFail("Task Codable failed: \(error)")
        }
    }

    func testTaskArrayCodable() {
        // Test that arrays of tasks can be encoded/decoded
        let tasks = [
            Task(rawName: "Task 1", name: "Task 1", elapsed: 100),
            Task(rawName: "Task 2", name: "Task 2", elapsed: 200),
            Task(rawName: "Task 3", name: "Task 3", elapsed: 300)
        ]
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tasks)
            
            let decoder = JSONDecoder()
            let decodedTasks = try decoder.decode([Task].self, from: data)
            
            XCTAssertEqual(decodedTasks.count, tasks.count)
            
            for (original, decoded) in zip(tasks, decodedTasks) {
                XCTAssertEqual(decoded.id, original.id)
                XCTAssertEqual(decoded.rawName, original.rawName)
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
        let task1 = Task(rawName: "Persistent Task 1", name: "Persistent Task 1", elapsed: 150)
        let task2 = Task(rawName: "Persistent Task 2", name: "Persistent Task 2", elapsed: 250)
        testStore.tasks = [task1, task2]
        
        // Test the persistence manually
        testStore.testLocalPersistence()
        
        // Verify tasks are still there and match
        XCTAssertEqual(testStore.tasks.count, 2)
        XCTAssertEqual(testStore.tasks[0].name, "Persistent Task 1")
        XCTAssertEqual(testStore.tasks[0].elapsed, 150)
        XCTAssertEqual(testStore.tasks[1].name, "Persistent Task 2")
        XCTAssertEqual(testStore.tasks[1].elapsed, 250)
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
        taskStore.tasks = [Task(rawName: "Existing", name: "Existing", elapsed: 100)]
        
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
        let task1 = Task(rawName: "Keep", name: "Keep", elapsed: 100)
        let task2 = Task(rawName: "Delete", name: "Delete", elapsed: 200)
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
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 100)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 200)
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
        let task1 = Task(rawName: "Restart Task 1", name: "Restart Task 1", elapsed: 300)
        let task2 = Task(rawName: "Restart Task 2", name: "Restart Task 2", elapsed: 400)
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
} 