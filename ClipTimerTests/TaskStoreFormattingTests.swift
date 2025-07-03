//
//  TaskStoreFormattingTests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStoreFormattingTests: XCTestCase {
    
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
    }
    
    func testAddPlainTextToSymbolizedTasksKeepsExistingSymbol() {
        clearTasks()
        
        // Add tasks with symbol first
        setupClipboard(with: "☐ Checkbox Task 1\n☐ Checkbox Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify symbol was established
        assertItemSymbol("☐ ")
        
        // Add plain text tasks (no symbols)
        setupClipboard(with: plainTextTasksContent())
        taskStore.addTasksFromClipboard()
        
        // Verify existing symbol is preserved and applied to new tasks
        assertItemSymbol("☐ ")
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "☐ Checkbox Task 1: 0:00:00",
            "☐ Checkbox Task 2: 0:00:00",
            "☐ Plain Task One: 0:00:00",
            "☐ Plain Task Two: 0:00:00"
        ], in: summaryText)
    }
    
    func testAddSymbolizedTasksToPlainTextDetectsNewSymbol() {
        clearTasks()
        
        // Start with plain text tasks
        setupClipboard(with: plainTextTasksContent())
        taskStore.addTasksFromClipboard()
        
        // Verify no symbol is established
        assertItemSymbol("")
        
        // Add tasks with symbol
        setupClipboard(with: "→ Arrow Task 1\n→ Arrow Task 2")
        taskStore.addTasksFromClipboard()
        
        // Verify new symbol is detected and applied to all tasks
        assertItemSymbol("→ ")
        let summaryText = taskStore.summaryText
        assertTasksInSummary([
            "→ Plain Task One: 0:00:00",
            "→ Plain Task Two: 0:00:00",
            "→ Arrow Task 1: 0:00:00",
            "→ Arrow Task 2: 0:00:00"
        ], in: summaryText)
    }
    
    // MARK: - Task Parsing Tests
    
    func testParseTaskLineBasic() {
        let task = taskStore.parseTaskLine("Simple task")
        XCTAssertEqual(task?.name, "Simple task")
        XCTAssertEqual(task?.elapsed, 0)
    }
    
    func testParseTaskLineWithTime() {
        let task = taskStore.parseTaskLine("Task with time: 1:30:45")
        XCTAssertEqual(task?.name, "Task with time")
        XCTAssertEqual(task?.elapsed, 5445) // 1*3600 + 30*60 + 45
    }
    
    func testParseTaskLineWithMinutesSeconds() {
        let task = taskStore.parseTaskLine("Short task: 5:30")
        XCTAssertEqual(task?.name, "Short task")
        XCTAssertEqual(task?.elapsed, 330) // 5*60 + 30
    }
    
    func testParseTaskLineWithBulletPoints() {
        let task = taskStore.parseTaskLine("• Bullet task: 2:15")
        XCTAssertEqual(task?.name, "Bullet task")
        XCTAssertEqual(task?.elapsed, 135) // 2*60 + 15
    }
    
    func testParseTaskLineWithMultipleBulletTypes() {
        let tasks = [
            ("• Bullet task", "Bullet task"),
            ("- Dash task", "Dash task"),
            ("* Star task", "Star task"),
            ("→ Arrow task", "Arrow task"),
            ("✓ Check task", "Check task"),
            ("☐ Box task", "Box task")
        ]
        
        for (input, expectedName) in tasks {
            let task = taskStore.parseTaskLine(input)
            XCTAssertEqual(task?.name, expectedName, "Failed for input: \(input)")
            XCTAssertEqual(task?.elapsed, 0)
        }
    }
    
    func testParseTaskLineEmptyString() {
        let task = taskStore.parseTaskLine("")
        XCTAssertNil(task)
    }
    
    func testParseTaskLineWhitespaceOnly() {
        let task = taskStore.parseTaskLine("   \t\n   ")
        XCTAssertNil(task)
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
    
    // MARK: - Update Existing Tasks Tests
    
    func testAddTasksUpdatesExistingTaskTime() {
        clearTasks()
        
        // Start with some existing tasks
        taskStore.tasks = [
            Task(name: "Task 1", elapsed: 100),
            Task(name: "Task 2", elapsed: 200),
            Task(name: "Task 3", elapsed: 300)
        ]
        
        // Add tasks where some already exist with different times
        setupClipboard(with: "Task 1: 5:00\nTask 4: 2:30\nTask 2: 10:15")
        taskStore.addTasksFromClipboard()
        
        // Verify we have 4 tasks total (3 original + 1 new)
        XCTAssertEqual(taskStore.tasks.count, 4)
        
        // Verify existing tasks were updated
        let task1 = taskStore.tasks.first { $0.name == "Task 1" }!
        XCTAssertEqual(task1.elapsed, 300) // 5:00 = 300 seconds
        
        let task2 = taskStore.tasks.first { $0.name == "Task 2" }!
        XCTAssertEqual(task2.elapsed, 615) // 10:15 = 615 seconds
        
        // Verify unchanged task remains the same
        let task3 = taskStore.tasks.first { $0.name == "Task 3" }!
        XCTAssertEqual(task3.elapsed, 300) // Unchanged
        
        // Verify new task was added
        let task4 = taskStore.tasks.first { $0.name == "Task 4" }!
        XCTAssertEqual(task4.elapsed, 150) // 2:30 = 150 seconds
    }
    
    func testAddTasksUpdatesActiveTaskAndPausesIt() {
        clearTasks()
        
        // Create tasks with one active
        let task1 = Task(name: "Active Task", elapsed: 100)
        let task2 = Task(name: "Inactive Task", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        // Make task1 active
        taskStore.activeTaskID = task1.id
        taskStore.activeTaskStartTime = Date()
        
        // Verify task is active
        XCTAssertEqual(taskStore.activeTaskID, task1.id)
        XCTAssertNotNil(taskStore.activeTaskStartTime)
        
        // Add tasks that update the active task
        setupClipboard(with: "Active Task: 15:30\nNew Task: 5:00")
        taskStore.addTasksFromClipboard()
        
        // Verify the active task was paused (no longer active)
        XCTAssertNil(taskStore.activeTaskID)
        XCTAssertNil(taskStore.activeTaskStartTime)
        
        // Verify the task's time was updated
        let updatedTask = taskStore.tasks.first { $0.name == "Active Task" }!
        XCTAssertEqual(updatedTask.elapsed, 930) // 15:30 = 930 seconds
        
        // Verify we have 3 tasks total
        XCTAssertEqual(taskStore.tasks.count, 3)
        
        // Verify new task was added
        let newTask = taskStore.tasks.first { $0.name == "New Task" }!
        XCTAssertEqual(newTask.elapsed, 300) // 5:00 = 300 seconds
    }
    
    func testAddTasksWithExistingNamesButNoTimes() {
        clearTasks()
        
        // Start with existing tasks
        taskStore.tasks = [
            Task(name: "Task A", elapsed: 500),
            Task(name: "Task B", elapsed: 1000)
        ]
        
        // Add tasks with same names but no times (should reset to 0)
        setupClipboard(with: "Task A\nTask C\nTask B")
        taskStore.addTasksFromClipboard()
        
        // Verify we have 3 tasks total
        XCTAssertEqual(taskStore.tasks.count, 3)
        
        // Verify existing tasks were reset to 0
        let taskA = taskStore.tasks.first { $0.name == "Task A" }!
        XCTAssertEqual(taskA.elapsed, 0)
        
        let taskB = taskStore.tasks.first { $0.name == "Task B" }!
        XCTAssertEqual(taskB.elapsed, 0)
        
        // Verify new task was added
        let taskC = taskStore.tasks.first { $0.name == "Task C" }!
        XCTAssertEqual(taskC.elapsed, 0)
    }
    
    func testAddTasksWithSymbolsUpdatesExistingTasks() {
        clearTasks()
        
        // Start with existing tasks with symbols
        setupClipboard(with: "• Task One: 1:00\n• Task Two: 2:00")
        taskStore.replaceTasksFromClipboard()
        
        // Verify initial state
        XCTAssertEqual(taskStore.tasks.count, 2)
        XCTAssertEqual(taskStore.itemSymbol, "• ")
        
        // Add tasks that update existing ones
        setupClipboard(with: "• Task One: 5:30\n• Task Three: 3:45")
        taskStore.addTasksFromClipboard()
        
        // Verify we have 3 tasks total
        XCTAssertEqual(taskStore.tasks.count, 3)
        
        // Verify existing task was updated
        let taskOne = taskStore.tasks.first { $0.name == "Task One" }!
        XCTAssertEqual(taskOne.elapsed, 330) // 5:30 = 330 seconds
        
        // Verify unchanged task remains the same
        let taskTwo = taskStore.tasks.first { $0.name == "Task Two" }!
        XCTAssertEqual(taskTwo.elapsed, 120) // 2:00 = 120 seconds
        
        // Verify new task was added
        let taskThree = taskStore.tasks.first { $0.name == "Task Three" }!
        XCTAssertEqual(taskThree.elapsed, 225) // 3:45 = 225 seconds
        
        // Verify symbol is preserved
        XCTAssertEqual(taskStore.itemSymbol, "• ")
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