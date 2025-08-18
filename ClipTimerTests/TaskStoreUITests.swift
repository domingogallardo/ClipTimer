//
//  TaskStoreUITests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStoreUITests: XCTestCase {
    
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
    
    // MARK: - Summary Text Tests
    
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
    
    // MARK: - UI Text Tests
    
    func testEmptyTasksPlaceholderText() {
        // Verify TaskStore uses whatever the current runtime localization resolves to
        clearTasks()
        let emptyMessage = taskStore.summaryText
        let expectedRuntimeString = NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks")
        XCTAssertEqual(
            emptyMessage,
            expectedRuntimeString,
            "TaskStore should show the empty state message matching current runtime localization"
        )
    }
    
    // MARK: - Test Helpers
    
    /// Helper method to clear tasks and verify empty state
    private func clearTasks() {
        taskStore.tasks = []
        XCTAssertTrue(taskStore.tasks.isEmpty, "Tasks should be empty")
    }
} 
