//
//  Task.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 4/6/25.
//

import Foundation

struct Task: Identifiable {
    let id = UUID()
    let rawName: String
    var name: String
    var elapsed: TimeInterval    // segundos
    var isActive: Bool = false
}

extension TimeInterval {
    var hms: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return "\(h):" + String(format: "%02d:%02d", m, s)
    }
}
