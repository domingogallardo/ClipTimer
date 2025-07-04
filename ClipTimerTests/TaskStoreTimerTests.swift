//
//  TaskStoreTimerTests.swift
//  ClipTimerTests
//
//  Created by Domingo Gallardo
//

import XCTest
import Combine
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
} 