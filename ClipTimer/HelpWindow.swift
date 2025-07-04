//  HelpWindow.swift
//  ClipTimer
//
//  Created by Domingo Gallardo 
//

import SwiftUI

struct HelpWindow: View {
    var body: some View {
        ZStack {
            Color("PanelBackground").ignoresSafeArea()
            
            ScrollView {
                HStack {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("ClipTimer • Quick Start")
                            .font(.largeTitle.bold())
                            .padding(.top, 8)
                        
                        Text("""
                             Follow the steps below to start timing your tasks in seconds. \
                             ClipTimer is designed around the clipboard, so you can move fast \
                             without manual typing.
                             """)
                        .fixedSize(horizontal: false, vertical: true)
                        
                         Group {
                             step(number: 1,
                                  title: "Copy your task list",
                                  details: """
                                           Select any plain-text list of tasks (it may include \
                                           existing times such as “Design 1:30:45”). \
                                           Copy it to the clipboard (⌘C).
                                           """)
                             
                             step(number: 2,
                                  title: "Paste into ClipTimer",
                                  details: """
                                           In ClipTimer, press ⌘V (or ⇧⌘V to append). \
                                           Each line becomes an individual task. \
                                           Any timecodes are parsed automatically.
                                           """)
                             
                             step(number: 3,
                                  title: "Start or pause a task",
                                  details: """
                                           Click the power icon next to a task to start \
                                           timing it. Only one task runs at a time. \
                                           Press ⌘P to pause, ⌘R to restart the last paused task.
                                           """)
                             
                             step(number: 4,
                                  title: "Edit or delete tasks",
                                  details: """
                                           Right-click a task and choose `Delete` \
                                           (or press ⌘Z / ⇧⌘Z to undo/redo). \
                                           You can always paste a fresh list to replace all tasks.
                                           """)
                             
                             step(number: 5,
                                  title: "Export your work",
                                  details: """
                                           Press ⌘C to copy a neatly formatted summary, \
                                           including the total working time, back to the clipboard. \
                                           Paste it anywhere you like—notes, email, timesheet…
                                           """)
                         }
                         
                         Divider()
                         
                         Text("Need more help?")
                             .font(.title2.bold())
                         VStack(alignment: .leading, spacing: 6) {
                             Text("• Project page: https://domingogallardo.com/cliptimer-support-en.html")
                             Text("• Email support: domingo.gallardo@gmail.com")
                         }
                    }
                    .padding(.leading, 40)
                    .padding([.top, .bottom, .trailing], 28)
                    .frame(maxWidth: 540, alignment: .leading)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 440, minHeight: 400)
        }
    }
    
    // Reusable component for help steps
    @ViewBuilder
    private func step(number: Int, title: LocalizedStringResource,
                      details: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.title2.weight(.bold))
                    .frame(width: 28, alignment: .leading)
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            Text(details)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 32)
        }
    }

}

#if DEBUG
#Preview {
    HelpWindow()
}
#endif
