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
        // Test that EmptyTasksPlaceholder shows the exact text from the AppStore version
        // This prevents accidental changes to the user-facing instructions
        
        // The exact text that should appear in EmptyTasksPlaceholder
        let expectedTitle = "No tasks yet"
        let expectedInstructions = "Copy the list of tasks (with/without times)\n to the clipboard and paste them here."
        
        // Verify the strings exist in the localization file and return the expected Spanish text
        XCTAssertEqual(NSLocalizedString("No tasks yet", comment: "Message shown when there are no tasks"), 
                      "Aún no hay tareas", 
                      "Title should be 'Aún no hay tareas' in Spanish")
        
        XCTAssertEqual(NSLocalizedString("Copy the list of tasks (with/without times)\n to the clipboard and paste them here.", comment: "Instructions for empty state"), 
                      "Copia la lista de tareas (con/sin tiempos)\n al portapapeles y pégalas aquí.", 
                      "Instructions should be properly translated to Spanish")
        
        // Also verify that TaskStore empty state shows the correct message
        clearTasks()
        let emptyMessage = taskStore.summaryText
        XCTAssertEqual(emptyMessage, "Aún no hay tareas", 
                      "TaskStore should show the same empty message as EmptyTasksPlaceholder")
    }
    
    // MARK: - Test Helpers
    
    /// Helper method to clear tasks and verify empty state
    private func clearTasks() {
        taskStore.tasks = []
        XCTAssertTrue(taskStore.tasks.isEmpty, "Tasks should be empty")
    }
} 