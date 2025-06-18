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
    }
    
    override func tearDown() {
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
        XCTAssertNotNil(taskStore.tasks[0].startTime)
        
        // Deactivate task
        taskStore.toggle(task)
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.tasks[0].startTime)
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
        XCTAssertNil(taskStore.tasks[0].startTime) // First task should be paused
        XCTAssertNotNil(taskStore.tasks[1].startTime) // Second task should be active
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseActiveTask() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate and then pause
        taskStore.toggle(task)
        taskStore.pauseActiveTask()
        
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.tasks[0].startTime)
    }
    
    func testRestartLastPausedTask() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 0)
        taskStore.tasks = [task]
        
        // Activate, pause, then restart
        taskStore.toggle(task)
        taskStore.pauseActiveTask()
        taskStore.restartLastPausedTask()
        
        XCTAssertEqual(taskStore.activeTaskID, task.id)
        XCTAssertNotNil(taskStore.tasks[0].startTime)
    }
} 