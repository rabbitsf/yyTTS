# yyTTS - Text-to-Speech Reader

A simple yet powerful Text-to-Speech iOS app that converts your text files into natural-sounding speech. Perfect for listening to documents, articles, notes, or any text content on the go.

## ✨ Features

### 📖 Text-to-Speech Playback
- Natural-sounding speech synthesis powered by iOS AVSpeechSynthesizer
- Support for English and Simplified Chinese languages
- Adjustable speech rate and voice selection
- Real-time highlighting of the current sentence being read
- Sentence-by-sentence navigation

### 📁 File Organization
- Create and manage multiple text files
- Organize files into folders for better structure
- Landing page for quick access to frequently used files
- Move files between folders with ease
- Quick search and navigation

### 🎵 Media Controls Integration
- Background playback support - continues reading even when the app is in the background
- Lock screen controls (Play/Pause, Next, Previous)
- Control Center integration
- Now Playing info display with file name and content preview
- Headphone and AirPods control support

### 📝 File Management
- Create, edit, and delete text files
- Swipe actions for quick operations:
  - **Swipe left on files**: Move, Play, or Delete
  - **Swipe left on folders**: Delete
- File modification dates tracking
- Content preview in file list

### 🌐 WiFi Upload Server (NEW!)
- **Create files from any computer** on your local network
- Built-in HTTP server accessible via web browser
- Upload text content from desktop/laptop computers
- Create folders and organize files remotely
- Persistent server - stays on even when navigating away or device is locked
- Simple web interface - no additional software needed
- Real-time status updates on uploads

### 🎨 Beautiful UI
- Modern gradient design with smooth animations
- Clean and intuitive interface
- Dark mode support
- Responsive layout optimized for all iPhone sizes

## 📱 Requirements

- iOS 15.0 or later
- iPhone or iPad
- Xcode 14.0+ (for development)

## 🚀 Installation

### For Users
1. Clone this repository:
```bash
git clone https://github.com/rabbitsf/yyTTS.git
```

2. Open `yyTTS.xcodeproj` in Xcode

3. Select your target device or simulator

4. Build and run the project (⌘ + R)

### For Developers
The project uses standard iOS frameworks and doesn't require any external dependencies or CocoaPods.

## 📖 Usage

### Getting Started
1. **Select Voice**: Tap the speaker icon (🔊) in the top-left to choose your preferred voice for English and Chinese
2. **Create Folders**: Tap the folder icon (📁+) to organize your files
3. **Add Files**: Tap the plus icon (+) to create a new text file
4. **Edit Content**: Enter or paste your text content

### WiFi Upload Server
1. **Start Server**: Tap the Upload button (⬆️) in the top-right corner
2. **Toggle Server On**: Switch the server toggle to enable it
3. **Note the URL**: Your device's IP address and port (e.g., http://192.168.1.100:8080) will be displayed
4. **Access from Computer**: 
   - Open a web browser on any computer connected to the same WiFi network
   - Navigate to the displayed URL
   - Create folders and text files directly from your computer
   - All changes appear instantly on your iOS device
5. **Server Management**:
   - Server stays on even when you navigate away or lock your device
   - Only stops when you manually toggle it off
   - Works in background and while device is locked

### Playing Files
1. **Tap a file** to open the editor and view its content
2. **Tap the Play button** to start Text-to-Speech
3. Use playback controls:
   - ▶️/⏸️ **Play/Pause**: Toggle playback
   - ⏭️ **Next**: Skip to next file
   - ⏮️ **Previous**: Go to previous file
   - ✓ **Done**: Close the player

### File Operations
- **Swipe left on a file** to reveal actions:
  - 🎵 **Play**: Start reading immediately
  - 📂 **Move**: Transfer to another folder
  - 🗑️ **Delete**: Remove the file

- **Swipe left on a folder** to delete it

### Background Listening
- Play any file and press the home button or lock your device
- Control playback from:
  - Lock screen
  - Control Center
  - AirPods/headphone controls

## 🛠️ Technical Details

### Architecture
- **SwiftUI** for the user interface
- **AVFoundation** for speech synthesis
- **MediaPlayer** framework for lock screen controls
- **Network** framework for HTTP server implementation
- **MVVM** pattern with `@StateObject` and `@EnvironmentObject`

### Key Components
- `TTSManager`: Handles speech synthesis and playback state
- `FileManagerViewModel`: Manages files and folders data
- `ThemeManager`: Centralized theming and color schemes
- `ContentView`: Main landing page with file/folder listing
- `FileEditorView`: Text editor with playback controls
- `FolderView`: Displays files within a specific folder
- `VoicePickerView`: Voice selection interface
- `WiFiUploadServer`: HTTP server for remote file creation
- `NetworkHelper`: Network utilities for IP address detection
- `UploadView`: Server management interface

### Data Persistence
- Files and folders are stored as JSON in the Documents directory
- Each file includes: name, content, creation/modification dates, folder association
- Voice preferences are saved and restored on app launch
- Upload server integrates seamlessly with existing file management system

## 🎨 Screenshots

<!-- Add your app screenshots here -->
*Screenshots coming soon*

## 📄 License

This project is open source. Feel free to use, modify, and distribute as needed.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 👤 Author

**rabbitsf**
- GitHub: [@rabbitsf](https://github.com/rabbitsf)

## ⭐ Show Your Support

Give a ⭐️ if this project helped you!

---

**Note**: This app is designed for personal use. For commercial applications, please ensure you comply with Apple's terms of service and any applicable licensing requirements.

