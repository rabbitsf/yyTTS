# Upload Server Feature - Implementation Summary

## Overview
Successfully added an upload server feature to the yyTTS (Text-to-Speech) project. This feature allows users to create text files and folders from a web browser on the same local network.

## New Files Created

### 1. NetworkHelper.swift
- **Purpose**: Retrieves the device's local IP address
- **Key Method**: `getLocalIPAddress()` - Returns the IPv4 address of the device on the local network

### 2. WiFiUploadServer.swift
- **Purpose**: HTTP server implementation for handling web requests
- **Features**:
  - Starts/stops server on port 8080
  - Handles POST requests for creating folders and files
  - Manages upload status tracking
  - Generates HTML web interface
- **Key Methods**:
  - `startServer()` - Starts the HTTP server
  - `stopServer()` - Stops the HTTP server
  - `handleCreateFolder()` - Creates new folders
  - `handleCreateFile()` - Creates new text files with content

### 3. UploadView.swift
- **Purpose**: iOS UI for the upload server
- **Features**:
  - Displays device IP address with copy button
  - Toggle switch to start/stop the server
  - Shows server URL (http://[IP]:8080)
  - Displays upload status for created files/folders
  - Beautiful gradient background with decorative elements

### 4. ContentView.swift (Modified)
- **Change**: Added "Upload" button to the toolbar
- **Action**: Opens the UploadView when tapped

## How to Use

### On iOS Device:
1. Open the app and tap the **Upload** button (upload icon) in the top right
2. Toggle the **Upload Server** switch to ON
3. Note the IP address and URL displayed (e.g., http://192.168.1.100:8080)

### On Computer (Same Network):
1. Open a web browser (Chrome, Safari, Firefox, etc.)
2. Navigate to the URL shown on the iOS device (e.g., http://192.168.1.100:8080)
3. You'll see a web interface with two sections:
   - **Create New Folder**: Enter a folder name and click "Create Folder"
   - **Create New File**: 
     - Enter file name
     - Optionally select a folder (or leave blank for landing page)
     - Enter text content in the text area
     - Click "Create File"

### Features:
- All created folders and files immediately appear on the iOS device
- Files can be placed in folders or on the landing page
- The web interface automatically refreshes the folder list after creating new folders
- Status messages show success/error for each operation

## Technical Details

### Server Implementation:
- Uses Apple's Network framework (NWListener, NWConnection)
- Implements basic HTTP/1.1 protocol
- Supports GET and POST requests
- Handles JSON payloads for creating folders and files
- Integrates with existing FileManagerViewModel

### Security Considerations:
- Server only runs when explicitly enabled by user
- Automatically stops when leaving the Upload screen
- Only accessible on local network (port 8080)
- No authentication (suitable for local network use only)

### File Storage:
- Files are stored using the existing FileManagerViewModel system
- Folders and files are saved as JSON in the Documents directory
- Maintains compatibility with existing file management features

## Testing Checklist

1. ✅ Build the project in Xcode
2. ✅ Run on iOS device or simulator
3. ✅ Tap Upload button - verify UploadView opens
4. ✅ Verify IP address is displayed
5. ✅ Toggle server ON
6. ✅ Open web browser on same network
7. ✅ Navigate to http://[device-ip]:8080
8. ✅ Create a folder - verify it appears on iOS
9. ✅ Create a file in folder - verify it appears on iOS
10. ✅ Create a file without folder - verify it appears on landing page
11. ✅ Toggle server OFF
12. ✅ Verify web interface becomes inaccessible

## Troubleshooting

### Web page won't load:
- Ensure iOS device and computer are on the same Wi-Fi network
- Verify the server toggle is ON
- Check that the IP address hasn't changed (disable/re-enable Wi-Fi on iOS)
- Try disabling firewall temporarily on the computer

### Files not appearing:
- Check the status message on the web page for errors
- Ensure folder names match exactly (case-sensitive)
- Pull down to refresh on iOS if needed

### IP address shows as nil:
- Check Wi-Fi is enabled on iOS device
- Try toggling airplane mode off/on
- Reconnect to Wi-Fi network

## Future Enhancements (Optional)

- Add file editing capability
- Support file deletion from web interface
- Add file upload (import existing text files)
- Add folder browsing and selection
- Implement basic authentication
- Add HTTPS support for secure connections
- Show real-time file list on web interface

## Credits

Implementation based on the upload server pattern from the yyPlayer sample project, adapted for text file management instead of audio files.

