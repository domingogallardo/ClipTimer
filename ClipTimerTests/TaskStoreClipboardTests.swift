//
//  TaskStoreClipboardTests.swift
//  ClipTimerTests
//
//  Created by OpenAI ChatGPT
//

import XCTest
import AppKit
@testable import ClipTimer

@MainActor
final class TaskStoreClipboardTests: XCTestCase {
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

    func testCopySummaryUsesWorkingTimeLabel() {
        let task = Task(name: "Task", elapsed: 60)
        taskStore.tasks = [task]

        taskStore.copySummaryToClipboard()
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""

        XCTAssertTrue(
            clipboard.contains(NSLocalizedString("Working time", comment: "Label for working time")),
            "Clipboard summary should include the 'Working time' label"
        )
    }
}

