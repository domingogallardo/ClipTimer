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

    func testFinishActiveTask() {
        let task = Task(name: "Task", elapsed: 100)
        taskStore.tasks = [task]

        taskStore.toggle(task)
        taskStore.finishActiveTask()

        XCTAssertTrue(taskStore.tasks[0].isCompleted)
        XCTAssertNil(taskStore.activeTaskID)
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
    
    // MARK: - Bug Reproduction Tests
    
    func testTaskEditorBugWithPreviouslyPausedTask() {
        // This test reproduces the bug where a previously paused task 
        // gets reactivated when opening/closing the task editor
        
        let task = Task(name: "Bug Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // Step 1: Activate the task
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Step 2: User manually pauses the task using "Pause active task" (⌘P)
        taskStore.pauseActiveTask()
        XCTAssertNil(taskStore.activeTaskID, "Task should be paused")
        XCTAssertNil(taskStore.activeTaskStartTime, "No active start time")
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id, "Task ID should be stored as last paused")
        
        // Step 3: Task is now stopped - user expects it to stay stopped
        // But now user opens the task editor...
        
        // Simulate TaskEditorWindow.onAppear when no task is active
        // Editor should leave lastPausedTaskID untouched and NOT pause anything
        XCTAssertNil(taskStore.activeTaskID, "Still no active task")
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id, "lastPausedTaskID should remain intact")
        
        // Step 4: User closes the task editor without making changes
        // Editor should NOT restart because it did not pause the task
        // Verify task remains paused
        XCTAssertNil(taskStore.activeTaskID, "Task should remain stopped - user manually paused it")
        XCTAssertNil(taskStore.activeTaskStartTime, "No task should be running")
    }
    
    // Editor should NOT restart a task that was already paused before opening
    func testEditorDoesNotRestartPreviouslyPausedTask() {
        let task = Task(name: "Editor Task", elapsed: 120)
        taskStore.tasks = [task]
        
        // Start and immediately pause the task via ⌘P (or toggle+pause)
        taskStore.toggle(task)               // start
        taskStore.pauseActiveTask()          // pause -> lastPausedTaskID set
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id)
        
        // Simulate TaskEditorWindow.onAppear when no task is active (editor does nothing special)
        // Editor should NOT clear lastPausedTaskID and should NOT pause anything (already paused)
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id)
        
        // Simulate TaskEditorWindow.onDisappear – editor should NOT restart because it didn't pause
        // (no call to restartLastPausedTask())
        
        // Verify task remains paused and lastPausedTaskID is intact
        XCTAssertNil(taskStore.activeTaskID, "Task should remain paused after closing editor")
        XCTAssertEqual(taskStore.getLastPausedTaskID(), task.id, "lastPausedTaskID should remain for manual restart")
    }

    func testRestartShortcutAfterStoppingTaskFromList() {
        // Reproduce bug: Start task → Stop from list → Press ⌘R should restart, but doesn't
        let task = Task(name: "Test Task", elapsed: 100)
        taskStore.tasks = [task]
        
        // Step 1: Start the task (like clicking on it in the list)
        taskStore.toggle(task)
        XCTAssertEqual(taskStore.activeTaskID, task.id, "Task should be active after starting")
        XCTAssertNotNil(taskStore.activeTaskStartTime, "Task should have a start time")
        
        // Step 2: Stop the task by clicking on it again in the list
        taskStore.toggle(task)
        XCTAssertNil(taskStore.activeTaskID, "Task should be stopped after clicking again")
        XCTAssertNil(taskStore.activeTaskStartTime, "Task should not have a start time")
        
        // Step 3: Try to restart using ⌘R shortcut (restartLastPausedTask)
        // BUG: This should restart the task but currently does nothing
        taskStore.restartLastPausedTask()
        
        // EXPECTED: Task should be active again
        XCTAssertEqual(taskStore.activeTaskID, task.id, "Task should be restarted after ⌘R shortcut")
        XCTAssertNotNil(taskStore.activeTaskStartTime, "Restarted task should have a start time")
        XCTAssertNil(taskStore.getLastPausedTaskID(), "lastPausedTaskID should be cleared after restart")
    }
} 