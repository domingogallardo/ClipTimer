//
//  Task.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import Foundation

struct Task: Identifiable {
    let id = UUID()
    let rawName: String
    var name: String
    var elapsed: TimeInterval
    var startTime: Date? = nil  // Track when task started for continuous timing
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
