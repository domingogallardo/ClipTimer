//
//  TaskStoreTimerTests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStoreTimerTests: XCTestCase {
    
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
    
    // MARK: - Task Activation Tests
    
    func testToggleTaskActivation() {
        let task = Task(name: "Toggle Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // Initially no task should be active
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        
        // Activate the task
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Deactivate the task
        taskStore.toggle(task)
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }
    
    func testToggleOnlyOneTaskActiveAtTime() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Activate first task
        taskStore.toggle(task1)
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        
        // Activate second task (should deactivate first)
        taskStore.toggle(task2)
        XCTAssertEqual(taskStore.activeTaskID, task2.id)
        XCTAssertNotEqual(taskStore.activeTaskID, task1.id)
        
        // Only one task should be active at a time
        let activeTasks = taskStore.tasks.filter { task in
            task.id == taskStore.activeTaskID
        }
        XCTAssertEqual(activeTasks.count, 1)
    }
    
    func testPauseActiveTask() {
        let task = Task(name: "Pause Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // Activate task
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        
        // Pause active task
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        
        // Verify task was set as last paused
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id)
    }
    
    func testRestartLastPausedTask() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Activate and pause task1
        taskStore.toggle(task1)
        taskStore.pauseActiveTask()
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task1.id)
        
        // Activate task2
        taskStore.toggle(task2)
        XCTAssertEqual(taskStore.activeTaskID, task2.id)
        
        // Restart last paused task (should switch back to task1)
        taskStore.restartLastPausedTask()
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        XCTAssertNotEqual(taskStore.activeTaskID, task2.id)
    }
    
    func testTaskEditorPauseResumeWorkflow() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Activate task1
        taskStore.toggle(task1)
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Simulate task editor opening (pause active task)
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task1.id)
        
        // Simulate task editor closing (restart paused task)
        taskStore.restartLastPausedTask()
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Verify the same task is still active
        XCTAssertEqual(taskStore.activeTask?.name, "Task 1")
    }
    
    func testTaskEditorWithNoActiveTask() {
        let task = Task(name: "Inactive Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // No task is active initially
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.getLastPausedTaskID())
        
        // Simulate task editor opening (pause active task - should be no-op)
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.getLastPausedTaskID())
        
        // Simulate task editor closing (restart paused task - should be no-op)
        taskStore.restartLastPausedTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
    }
    
    func testTaskEditorUpdatesTimeOfPausedTaskBeforeRestart() {
        // Create a task and make it active
        let task = Task(name: "Test Task", elapsed: 100.0) // 100 seconds initially
        taskStore.tasks = [task]
        
        // Activate the task
        taskStore.toggle(task)
        let originalTaskID = task.id
        XCTAssertEqual(taskStore.activeTaskID, originalTaskID)
        
        // Simulate task editor opening (pause active task)
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), originalTaskID)
        
        // Simulate user editing the task time in the editor
        // User changes "Test Task: 1:40" to "Test Task: 5:30" (330 seconds)
        taskStore.addTasks(from: "Test Task: 5:30")
        
        // Verify the task time was updated
        let updatedTask = taskStore.tasks.first { $0.name == "Test Task" }!
        XCTAssertEqual(updatedTask.elapsed, 330.0) // 5:30 = 330 seconds
        XCTAssertEqual(updatedTask.id, originalTaskID) // Same task ID
        
        // Simulate task editor closing (explicit restart by TaskEditorWindow)
        taskStore.restartLastPausedTask()
        
        // Verify the task restarted after explicit restart call
        XCTAssertEqual(taskStore.activeTaskID, originalTaskID, "Task should be active again after editor updates")
        XCTAssertNotNil(taskStore.activeTaskStartTime, "Task should have a start time when restarted")
        XCTAssertNil(taskStore.getLastPausedTaskID(), "lastPausedTaskID should be cleared after restart")
        
        // Verify the task has the updated elapsed time
        let finalTask = taskStore.tasks.first { $0.name == "Test Task" }!
        XCTAssertEqual(finalTask.elapsed, 330.0) // Updated time is preserved
        XCTAssertEqual(finalTask.id, originalTaskID) // Same task ID
    }
    
    func testTaskEditorUpdatesActiveTaskAndRestartsIt() {
        // Create a task and make it active
        let task = Task(name: "Active Task", elapsed: 60.0) // 1 minute initially
        taskStore.tasks = [task]
        
        // Activate the task
        taskStore.toggle(task)
        let originalTaskID = task.id
        XCTAssertEqual(taskStore.activeTaskID, originalTaskID)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Simulate task editor opening (pause active task)
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), originalTaskID)
        
        // Simulate user editing the active task time in the editor
        // User changes "Active Task: 1:00" to "Active Task: 10:00" (600 seconds)
        taskStore.addTasks(from: "Active Task: 10:00")
        
        // Verify the task time was updated
        let updatedTask = taskStore.tasks.first { $0.name == "Active Task" }!
        XCTAssertEqual(updatedTask.elapsed, 600.0) // 10:00 = 600 seconds
        XCTAssertEqual(updatedTask.id, originalTaskID) // Same task ID
        
        // Simulate task editor closing (explicit restart by TaskEditorWindow)
        taskStore.restartLastPausedTask()
        
        // Verify the task restarted after explicit restart call
        XCTAssertEqual(taskStore.activeTaskID, originalTaskID, "Task should be active again after editor updates")
        XCTAssertNotNil(taskStore.activeTaskStartTime, "Task should have a start time when restarted")
        XCTAssertNil(taskStore.getLastPausedTaskID(), "lastPausedTaskID should be cleared after restart")
        
        // Verify the task has the updated elapsed time
        let finalTask = taskStore.tasks.first { $0.name == "Active Task" }!
        XCTAssertEqual(finalTask.elapsed, 600.0) // Updated time is preserved
        XCTAssertEqual(finalTask.id, originalTaskID) // Same task ID
    }
} 