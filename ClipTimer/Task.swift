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
    var isActive: Bool = false
}

extension TimeInterval {
    // Format seconds as "H:MM:SS" string
    var hms: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return "\(h):" + String(format: "%02d:%02d", m, s)
    }
}
