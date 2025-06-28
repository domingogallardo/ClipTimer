//
//  Task.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import Foundation

struct Task: Identifiable, Codable {
    let id: UUID
    let rawName: String
    var name: String
    var elapsed: TimeInterval
    
    // Custom initializer to generate UUID
    init(rawName: String, name: String, elapsed: TimeInterval) {
        self.id = UUID()
        self.rawName = rawName
        self.name = name
        self.elapsed = elapsed
    }
    
    // Calculate current elapsed time including active time if running
    func currentElapsed(activeTaskID: UUID?, startTime: Date?) -> TimeInterval {
        var elapsed = self.elapsed
        
        // If this task is currently active, add the time since it started
        if activeTaskID == self.id, let startTime = startTime {
            elapsed += Date().timeIntervalSince(startTime)
        }
        
        return elapsed
    }
}

extension TimeInterval {
    // Private helper to extract time components
    private var timeComponents: (hours: Int, minutes: Int, seconds: Int) {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return (h, m, s)
    }
    
    // Format seconds as "H:MM:SS" string
    var hms: String {
        let (h, m, s) = timeComponents
        return "\(h):" + String(format: "%02d:%02d", m, s)
    }
    
    // Format with blinking seconds colon only
    func hms(showSecondsColon: Bool) -> String {
        let (h, m, s) = timeComponents
        let secondsColon = showSecondsColon ? ":" : " "
        return "\(h):" + String(format: "%02d\(secondsColon)%02d", m, s)
    }
}
