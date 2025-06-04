//
//  EmptyTasksPlaceholder.swift
//  ClipTimer
//
//  Created by Domingo Gallardo on 4/6/25.
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
                Text("Copy the list of tasks to the clipboard\nand paste them here.")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#if DEBUG
#Preview {
    EmptyTasksPlaceholder()
        .frame(width: 360, height: 280)
}
#endif
