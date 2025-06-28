# ClipTimer ⏱️

A simple, elegant time tracking app for macOS that helps you monitor time spent on different tasks.

[![macOS](https://img.shields.io/badge/macOS-14.1+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-green.svg)](https://developer.apple.com/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## ✨ Features

### 🎯 Core Functionality
- **Task Management**: Create, start, pause, and delete tasks with ease
- **Time Tracking**: Accurate time measurement with live updates
- **Auto-Pause**: Automatically pauses active tasks when you quit the app
- **Data Persistence**: Your tasks and elapsed times are automatically saved

### 🔄 Smart Workflow
- **One-Click Operation**: Start/pause tasks with a single click
- **Visual Feedback**: Clear indicators for active tasks with blinking colons
- **Keyboard Shortcuts**: Efficient task management via keyboard
- **Copy to Clipboard**: Export task summaries with total time

### 💾 Reliability
- **Automatic Saving**: All changes are saved instantly to prevent data loss
- **App Lifecycle Management**: Proper handling of app termination
- **State Preservation**: Resume exactly where you left off

## 🚀 Getting Started

### Requirements
- macOS 14.1 or later
- Xcode 15.0+ (for development)

### Installation

#### From App Store (Recommended)
[![Download on the Mac App Store](https://developer.apple.com/assets/elements/badges/download-on-the-mac-app-store.svg)](https://apps.apple.com/es/app/cliptimer/id6746253223)

#### Build from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/domingogallardo/ClipTimer.git
   cd ClipTimer
   ```

2. Open the project in Xcode:
   ```bash
   open ClipTimer.xcodeproj
   ```

3. Build and run the project (⌘+R)

## 🎮 Usage

### Basic Operations
1. **Add Tasks**: Paste or type task names (supports time formats like "Task: 1:30:45")
2. **Start Tracking**: Click the play button next to any task
3. **Pause/Resume**: Click the pause button or start another task
4. **View Summary**: Copy all tasks with elapsed times to clipboard

### Supported Time Formats
ClipTimer automatically parses various time formats when adding tasks:
- `Task name: 1:30:45` (H:MM:SS)
- `Task name: 90:30` (MM:SS)
- `Task name` (starts at 0:00:00)

### Keyboard Shortcuts
- `⌘+V`: Paste tasks from clipboard
- `⌘+C`: Copy task summary
- `⌘+?`: Show help overlay

## 🏗️ Architecture

ClipTimer is built with modern Swift and SwiftUI, following best practices:

### Key Components
- **TaskStore**: Centralized state management with `@ObservableObject`
- **Task Model**: Codable data structure for persistence
- **AppDelegate**: Handles app lifecycle events
- **UserDefaults**: Local data persistence

### Design Patterns
- **Single Source of Truth**: Centralized `activeTaskID` management
- **Reactive UI**: SwiftUI with automatic updates
- **Separation of Concerns**: Clear separation between UI and business logic

## 🧪 Testing

ClipTimer includes a comprehensive test suite with 41+ tests covering:

- Task creation and management
- Time tracking accuracy
- Data persistence
- App lifecycle scenarios
- Edge cases and error handling

Run tests in Xcode with `⌘+U` or via command line:
```bash
xcodebuild test -scheme ClipTimer -destination 'platform=macOS'
```

## 🛠️ Development

### Project Structure
```
ClipTimer/
├── ClipTimer/              # Main app source
│   ├── ClipTimerApp.swift  # App entry point
│   ├── TaskStore.swift     # State management
│   ├── Task.swift          # Data model
│   ├── ContentView.swift   # Main UI
│   └── ...
├── ClipTimerTests/         # Test suite
└── ClipTimer.xcodeproj/    # Xcode project
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **UserDefaults**: Local data persistence
- **XCTest**: Unit and integration testing


### Recent Updates
- ✅ Auto-pause on app termination (v1.1.0)
- ✅ Enhanced data persistence (v1.1.0)
- ✅ Improved reliability and performance (v1.1.0)

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Include tests for new functionality
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ using Swift and SwiftUI
- Icons and design inspired by macOS Human Interface Guidelines
- Thanks to the Swift community for excellent tooling and resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/domingogallardo/ClipTimer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/domingogallardo/ClipTimer/discussions)
- **Email**: [Support](mailto:domingo.gallardo@gmail.com)

---

**Made with ❤️ for the macOS community** 