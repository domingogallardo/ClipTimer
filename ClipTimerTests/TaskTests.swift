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
        XCTAssertNil(task.startTime)
    }
    
    func testTaskIdentifiable() {
        let task1 = Task(rawName: "Task 1", name: "Task 1", elapsed: 0)
        let task2 = Task(rawName: "Task 2", name: "Task 2", elapsed: 0)
        
        // Each task should have a unique ID
        XCTAssertNotEqual(task1.id, task2.id)
    }
} 