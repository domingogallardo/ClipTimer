//
//  TaskStoreBasicTests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
@testable import ClipTimer

@MainActor
final class TaskStoreBasicTests: XCTestCase {
    
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
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        let newTaskStore = TaskStore()
        newTaskStore.clearPersistedData()
        
        XCTAssertTrue(newTaskStore.tasks.isEmpty)
        XCTAssertEqual(newTaskStore.itemSymbol, "")
        XCTAssertEqual(newTaskStore.totalElapsed, 0)
        XCTAssertFalse(newTaskStore.hasActiveTasks)
    }
    
    // MARK: - Task Management Tests
    
    func testDeleteTask() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        taskStore.delete(task1)
        
        XCTAssertEqual(taskStore.tasks.count, 1)
        XCTAssertEqual(taskStore.tasks[0].name, "Task 2")
    }
    
    func testTotalElapsedCalculation() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        XCTAssertEqual(taskStore.totalElapsed, 300)
    }
    
    func testHasActiveTasks() {
        let task = Task(name: "Task", elapsed: 100)
        taskStore.tasks = [task]
        
        XCTAssertFalse(taskStore.hasActiveTasks)
        
        taskStore.toggle(task)
        XCTAssertTrue(taskStore.hasActiveTasks)
    }
    
    func testActiveTask() {
        let task1 = Task(name: "Task 1", elapsed: 100)
        let task2 = Task(name: "Task 2", elapsed: 200)
        taskStore.tasks = [task1, task2]
        
        XCTAssertNil(taskStore.activeTask)
        
        taskStore.toggle(task1)
        XCTAssertEqual(taskStore.activeTask?.name, "Task 1")
        
        taskStore.toggle(task2)
        XCTAssertEqual(taskStore.activeTask?.name, "Task 2")
    }
    
    // MARK: - Task Codable Tests
    
    func testTaskCodable() {
        let task = Task(name: "Test Task", elapsed: 123.45)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(task)
            let decodedTask = try decoder.decode(Task.self, from: data)
            
            XCTAssertEqual(decodedTask.name, task.name)
            XCTAssertEqual(decodedTask.elapsed, task.elapsed, accuracy: 0.01)
            XCTAssertEqual(decodedTask.id, task.id)
        } catch {
            XCTFail("Task encoding/decoding failed: \(error)")
        }
    }
    
    func testTaskArrayCodable() {
        let tasks = [
            Task(name: "Task 1", elapsed: 100.5),
            Task(name: "Task 2", elapsed: 200.75),
            Task(name: "Task 3", elapsed: 300.25)
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(tasks)
            let decodedTasks = try decoder.decode([Task].self, from: data)
            
            XCTAssertEqual(decodedTasks.count, tasks.count)
            for (original, decoded) in zip(tasks, decodedTasks) {
                XCTAssertEqual(decoded.name, original.name)
                XCTAssertEqual(decoded.elapsed, original.elapsed, accuracy: 0.01)
                XCTAssertEqual(decoded.id, original.id)
            }
        } catch {
            XCTFail("Task array encoding/decoding failed: \(error)")
        }
    }
    
    // MARK: - Test Helpers
    
    /// Helper method to clear tasks and verify empty state
    private func clearTasks() {
        taskStore.tasks = []
        XCTAssertTrue(taskStore.tasks.isEmpty, "Tasks should be empty")
    }
} 