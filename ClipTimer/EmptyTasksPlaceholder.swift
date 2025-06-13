//
//  EmptyTasksPlaceholder.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI

struct EmptyTasksPlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text("No tasks yet")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Copy the list of tasks (with/without times)\n to the clipboard and paste them here.")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#if DEBUG
#Preview {
    EmptyTasksPlaceholder()
        .frame(width: 360, height: 280)
}
#endif
