//
//  WindowManager.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI
import AppKit

@MainActor
class WindowManager: ObservableObject {
    private var taskEditorWindow: NSWindow?
    private var taskEditorWindowDelegate: TaskEditorWindowDelegate?
    
    func openTaskEditor(store: TaskStore) {
        // If window already exists, just bring it to front
        if let window = taskEditorWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new window
        let contentView = TaskEditorWindow()
            .environmentObject(store)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Task Editor"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        taskEditorWindow = window
        
        // Create and store delegate to prevent immediate deallocation
        let delegate = TaskEditorWindowDelegate { [weak self] in
            self?.taskEditorWindow = nil
            self?.taskEditorWindowDelegate = nil
        }
        taskEditorWindowDelegate = delegate
        window.delegate = delegate
    }
    
    func closeTaskEditor() {
        taskEditorWindow?.close()
        taskEditorWindow = nil
        taskEditorWindowDelegate = nil
    }
}

// Window delegate to handle cleanup
private class TaskEditorWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
} 