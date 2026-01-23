//
//  ContentView.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var beaconPresence: BeaconPresenceManager
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow
    @State private var showHelp = false
    @State private var showAwayAlert = false
    @State private var awayAlertTitle = ""
    @State private var awayAlertMessage = ""

    var body: some View {
        VStack(spacing: 0) {

            header

            if beaconPresence.needsBluetoothPermission {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Bluetooth permission required. Enable it in System Settings > Privacy & Security > Bluetooth.")
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            // Animated transition between empty state and task list
            ZStack {
                if store.tasks.isEmpty {
                    EmptyTasksPlaceholder()
                        .transition(.opacity)
                } else {
                    TaskListView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: store.tasks.isEmpty)

            Divider()

            footer
        }
        .onAppear { store.undoManager = undoManager }
        .onChange(of: beaconPresence.state) { _, newState in
            if newState == .away {
                let hadActiveTask = store.activeTaskID != nil
                if hadActiveTask {
                    store.pauseActiveTask()
                }

                if hadActiveTask {
                    awayAlertTitle = NSLocalizedString(
                        "Task paused due to absence",
                        comment: "Alert title when task paused due to beacon absence"
                    )
                    awayAlertMessage = NSLocalizedString(
                        "The active task was paused because the beacon was not detected.",
                        comment: "Alert message when task paused due to beacon absence"
                    )
                } else {
                    awayAlertTitle = NSLocalizedString(
                        "Beacon not detected",
                        comment: "Alert title when beacon presence is lost"
                    )
                    awayAlertMessage = NSLocalizedString(
                        "The beacon was not detected. Detection is paused until you confirm you are back.",
                        comment: "Alert message when beacon presence is lost without active task"
                    )
                }

                if let details = beaconPresence.lastAbsenceDetails?.formattedDescription {
                    awayAlertMessage += "\n\n" + details
                }

                showAwayAlert = true
            }
        }
        .alert(Text(awayAlertTitle), isPresented: $showAwayAlert) {
            Button("OK", role: .cancel) {
                beaconPresence.restartDetection()
            }
        } message: {
            Text(awayAlertMessage)
        }
        .overlay(helpOverlay)
    }
}


private extension ContentView {
    @ViewBuilder
    var header: some View {
        HStack {
            Text("Tasks")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Circle()
                .fill(beaconPresence.isPresent ? Color.green : Color.red)
                .frame(width: 12, height: 12)
                .shadow(color: (beaconPresence.isPresent ? Color.green : Color.red).opacity(0.5),
                        radius: 3, x: 0, y: 0)
                .help(presenceIndicatorHelp)
                .padding(.horizontal, 8)

            Button {
                openWindow(id: "task-editor")
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Open Task Editor")
            .padding(.horizontal, 8)

            Button {
                withAnimation { showHelp.toggle() }
            } label: {
                Image(systemName: "keyboard")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Show keyboard shortcuts")
            .padding(.horizontal, 8)
        }
    }

    var footer: some View {
        HStack {
            Text("Working time")
                .font(.headline)
            Spacer()
            Text(store.totalElapsed.hms)
                .font(.headline)
                .monospacedDigit()
        }
        .padding()
    }

    // Sliding help overlay with tap-to-dismiss functionality
    @ViewBuilder
    var helpOverlay: some View {
        ZStack(alignment: .trailing) {
            if showHelp {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                HelpOverlay()
                    .background(Color(NSColor.windowBackgroundColor))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.3),
                            radius: 14, x: -8, y: 0)
                    .transition(.move(edge: .trailing))
            }
        }
        .onTapGesture {
            withAnimation { showHelp = false }
        }
        .animation(.easeInOut(duration: 0.5), value: showHelp)
    }

    var presenceIndicatorHelp: Text {
        if beaconPresence.awaitingConfirmation {
            return Text("Beacon detection paused.")
        }

        if beaconPresence.isPresent {
            return Text("Beacon present")
        }

        return Text("Beacon not detected")
    }
}

#if DEBUG

@MainActor
private func makePreviewStore() -> TaskStore {
    let store = TaskStore()
    store.tasks = [
        Task(name: "Write Report", elapsed: 432),
        Task(name: "Email Review", elapsed: 1230)
    ]
    store.activeTaskID = store.tasks[0].id
    return store
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .environmentObject(BeaconPresenceManager(initialState: .present, startScanning: false))
        .frame(width: 380, height: 600)
}

#Preview {
    ContentView()
        .environmentObject(makePreviewStore())
        .environmentObject(BeaconPresenceManager(initialState: .searching, startScanning: false))
        .frame(width: 380, height: 600)
}

#endif
