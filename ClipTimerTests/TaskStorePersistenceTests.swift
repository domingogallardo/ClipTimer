//
//  TaskStorePersistenceTests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStorePersistenceTests: XCTestCase {
    
    var taskStore: TaskStore!
    
    override func setUp() {
        super.setUp()
        taskStore = TaskStore()
        taskStore.clearPersistedData()
    }
    
    override func tearDown() {
        taskStore.clearPersistedData()
        super.tearDown()
    }
    
    // MARK: - Local Persistence Tests
    
    func testLocalPersistenceRoundTrip() {
        // Create test tasks
        let task1 = Task(name: "Persistence Task 1", elapsed: 120.5)
        let task2 = Task(name: "Persistence Task 2", elapsed: 300.75)
        taskStore.tasks = [task1, task2]
        
        // Save tasks
        taskStore.forceSave()
        
        // Verify persistence using TaskStore's testing interface
        XCTAssertTrue(taskStore.hasPersistedData())
        XCTAssertEqual(taskStore.getPersistedTaskCount(), 2)
        
        // Verify saved data content
        if let savedTasks = taskStore.getPersistedTasks() {
            XCTAssertEqual(savedTasks.count, 2)
            XCTAssertEqual(savedTasks[0].name, "Persistence Task 1")
            XCTAssertEqual(savedTasks[0].elapsed, 120.5, accuracy: 0.01)
            XCTAssertEqual(savedTasks[1].name, "Persistence Task 2")
            XCTAssertEqual(savedTasks[1].elapsed, 300.75, accuracy: 0.01)
        } else {
            XCTFail("Failed to retrieve persisted tasks")
        }
        
        // Clear current tasks and load from persistence
        taskStore.tasks = []
        
        // Create new TaskStore to simulate app restart
        let newTaskStore = TaskStore()
        
        // Verify tasks were loaded
        XCTAssertEqual(newTaskStore.tasks.count, 2)
        XCTAssertEqual(newTaskStore.tasks[0].name, "Persistence Task 1")
        XCTAssertEqual(newTaskStore.tasks[0].elapsed, 120.5, accuracy: 0.01)
        XCTAssertEqual(newTaskStore.tasks[1].name, "Persistence Task 2")
        XCTAssertEqual(newTaskStore.tasks[1].elapsed, 300.75, accuracy: 0.01)
    }
    
    // MARK: - Auto-Save Tests
    
    func testAutoSaveOnAddTasks() {
        clearTasks()
        
        taskStore.addTasks(from: "Task from clipboard: 1:23:45\nAnother task")
        
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
        
        taskStore.replaceTasks(from: "Replacement task")
        
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
    
    // MARK: - Test Helpers
    

    
    /// Helper method to clear tasks and verify empty state
    private func clearTasks() {
        taskStore.tasks = []
        XCTAssertTrue(taskStore.tasks.isEmpty, "Tasks should be empty")
    }
} 