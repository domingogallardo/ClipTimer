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
        
        // Clean up reference when window closes
        window.delegate = TaskEditorWindowDelegate { [weak self] in
            self?.taskEditorWindow = nil
        }
    }
    
    func closeTaskEditor() {
        taskEditorWindow?.close()
        taskEditorWindow = nil
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