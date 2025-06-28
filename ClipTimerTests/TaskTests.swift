//
//  TaskTests.swift
//  ClipTimerTests
//
//  Created by Tests
//

import XCTest
@testable import ClipTimer

final class TaskTests: XCTestCase {
    
    // MARK: - TimeInterval Extension Tests
    
    func testTimeIntervalHMSFormatting() {
        // Test basic formatting
        XCTAssertEqual(TimeInterval(0).hms, "0:00:00")
        XCTAssertEqual(TimeInterval(59).hms, "0:00:59")
        XCTAssertEqual(TimeInterval(60).hms, "0:01:00")
        XCTAssertEqual(TimeInterval(3661).hms, "1:01:01")
        XCTAssertEqual(TimeInterval(7323).hms, "2:02:03")
    }
    
    func testTimeIntervalHMSWithColonToggle() {
        let timeInterval = TimeInterval(3661) // 1:01:01
        
        // Test with colon shown
        XCTAssertEqual(timeInterval.hms(showSecondsColon: true), "1:01:01")
        
        // Test with colon hidden (space instead)
        XCTAssertEqual(timeInterval.hms(showSecondsColon: false), "1:01 01")
    }
    
    func testTimeIntervalEdgeCases() {
        // Test very large numbers
        let largeTime = TimeInterval(86400) // 24 hours
        XCTAssertEqual(largeTime.hms, "24:00:00")
        
        // Test fractional seconds (should be truncated)
        XCTAssertEqual(TimeInterval(59.9).hms, "0:00:59")
    }
    
    // MARK: - Task Model Tests
    
    func testTaskCreation() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 120)
        
        XCTAssertFalse(task.id.uuidString.isEmpty)
        XCTAssertEqual(task.rawName, "Test Task")
        XCTAssertEqual(task.name, "Test Task")
        XCTAssertEqual(task.elapsed, 120)
    }
    
    func testTaskIdentifiable() {
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 0)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 0)
        
        // Each task should have a unique ID
        XCTAssertNotEqual(task1.id, task2.id)
    }
    
    // MARK: - Current Elapsed Time Tests
    
    func testCurrentElapsedWithInactiveTask() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 120)
        
        // When task is not active, should return only stored elapsed time
        let currentElapsed = task.currentElapsed(activeTaskID: nil, startTime: nil)
        XCTAssertEqual(currentElapsed, 120)
        
        // When task is not active (different ID), should return only stored elapsed time
        let otherTaskID = UUID()
        let currentElapsedWithOtherID = task.currentElapsed(activeTaskID: otherTaskID, startTime: nil)
        XCTAssertEqual(currentElapsedWithOtherID, 120)
    }
    
    func testCurrentElapsedWithActiveTaskNoStartTime() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 100)
        
        // When task is marked as active but has no start time, should return stored elapsed time
        let currentElapsed = task.currentElapsed(activeTaskID: task.id, startTime: nil)
        XCTAssertEqual(currentElapsed, 100)
    }
    
    func testCurrentElapsedWithActiveTaskAndStartTime() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 100)
        
        // Set start time to 5 seconds ago
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        
        // When task is active and has start time, should add running time
        let currentElapsed = task.currentElapsed(activeTaskID: task.id, startTime: fiveSecondsAgo)
        
        // Should be approximately 100 + 5 = 105 seconds (allowing small tolerance for execution time)
        XCTAssertGreaterThanOrEqual(currentElapsed, 104.9)
        XCTAssertLessThanOrEqual(currentElapsed, 105.1)
    }
    
    func testCurrentElapsedWithActiveTaskButDifferentID() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 100)
        let fiveSecondsAgo = Date().addingTimeInterval(-5) // 5 seconds ago
        
        // When activeTaskID doesn't match task ID, should not add running time
        let otherTaskID = UUID()
        let currentElapsed = task.currentElapsed(activeTaskID: otherTaskID, startTime: fiveSecondsAgo)
        XCTAssertEqual(currentElapsed, 100)
    }
    
    func testCurrentElapsedConsistencyWithPreviousImplementation() {
        let task = Task(rawName: "Test Task", name: "Test Task", elapsed: 200)
        let tenSecondsAgo = Date().addingTimeInterval(-10) // 10 seconds ago
        
        // Test that our new method produces same result as old implementation would
        let activeTaskID = task.id
        let currentElapsed = task.currentElapsed(activeTaskID: activeTaskID, startTime: tenSecondsAgo)
        
        // Manually calculate what the old implementation would return
        var expectedElapsed = task.elapsed
        if activeTaskID == task.id {
            expectedElapsed += Date().timeIntervalSince(tenSecondsAgo)
        }
        
        // Should match within small tolerance
        XCTAssertEqual(currentElapsed, expectedElapsed, accuracy: 0.01)
    }
} 