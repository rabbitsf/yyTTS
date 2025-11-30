import Foundation
import Network
import Combine
import UIKit

class WiFiUploadServer: ObservableObject {
    static let shared = WiFiUploadServer()
    
    @Published var isServerRunning = false
    @Published var uploadStatus: [String: String] = [:]
    
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private var activeConnections: [NWConnection] = []
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Reference to FileManagerViewModel (will be set from UploadView)
    weak var fileManager: FileManagerViewModel?
    
    private init() {
        // Setup notification observers for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        // Request background execution time when server is running
        if isServerRunning {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
            print("📱 App entered background - Background task started")
        }
    }
    
    @objc private func appWillEnterForeground() {
        // End background task when returning to foreground
        endBackgroundTask()
        print("📱 App returned to foreground")
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("🏁 Background task ended")
        }
    }
    
    func startServer() {
        guard !isServerRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isServerRunning = true
                        print("✅ WiFi Upload Server started on port \(self?.port ?? 8080)")
                    case .failed(let error):
                        print("❌ Server failed: \(error)")
                        self?.isServerRunning = false
                    case .cancelled:
                        self?.isServerRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("❌ Failed to start server: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        activeConnections.forEach { $0.cancel() }
        activeConnections.removeAll()
        isServerRunning = false
        endBackgroundTask()
        print("🛑 Server stopped")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        activeConnections.append(connection)
        print("🔵 New connection from \(connection.endpoint)")
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveHTTPRequest(on: connection)
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                self?.activeConnections.removeAll { $0 === connection }
            case .cancelled:
                self?.activeConnections.removeAll { $0 === connection }
            default:
                break
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    private func receiveHTTPRequest(on connection: NWConnection) {
        var receivedData = Data()
        var expectedContentLength: Int?
        var headerEndIndex: Int?
        var hasProcessed = false
        
        func receiveChunk() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
                guard let self = self, !hasProcessed else {
                    return
                }
                
                if let error = error {
                    print("⚠️ Receive error: \(error.localizedDescription)")
                    connection.cancel()
                    return
                }
                
                if let data = data, !data.isEmpty {
                    receivedData.append(data)
                    
                    // Parse headers if we haven't yet
                    if headerEndIndex == nil {
                        if let headerEnd = receivedData.range(of: "\r\n\r\n".data(using: .utf8)!) {
                            headerEndIndex = headerEnd.upperBound
                            print("📋 Found header end at position \(headerEndIndex!)")
                            
                            // Extract Content-Length from headers
                            if let headerString = String(data: receivedData[..<headerEnd.lowerBound], encoding: .utf8) {
                                // Check if it's a GET request
                                let firstLine = headerString.components(separatedBy: "\r\n").first ?? ""
                                print("📝 Request line: \(firstLine)")
                                
                                for line in headerString.components(separatedBy: "\r\n") {
                                    if line.lowercased().hasPrefix("content-length:") {
                                        let parts = line.components(separatedBy: ":")
                                        if parts.count > 1, let length = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                                            expectedContentLength = length
                                            print("📊 Content-Length: \(length) bytes (total expected: \(headerEndIndex! + length))")
                                            break
                                        }
                                    }
                                }
                                
                                // If no Content-Length, check if it's a GET/OPTIONS request
                                if expectedContentLength == nil {
                                    if firstLine.hasPrefix("GET ") || firstLine.hasPrefix("OPTIONS ") {
                                        print("✅ GET/OPTIONS request complete (no body expected)")
                                        hasProcessed = true
                                        self.processHTTPRequest(receivedData, on: connection)
                                        return
                                    }
                                }
                            }
                        }
                    }
                    
                    // Check if we have all the data for POST requests with Content-Length
                    if let headerEnd = headerEndIndex, let contentLength = expectedContentLength {
                        let bodySize = receivedData.count - headerEnd
                        
                        if bodySize >= contentLength {
                            print("✅ Received complete request: \(receivedData.count) bytes")
                            hasProcessed = true
                            self.processHTTPRequest(receivedData, on: connection)
                            return
                        }
                    }
                }
                
                if isComplete {
                    if receivedData.isEmpty {
                        print("⚠️ Connection closed with no data")
                        connection.cancel()
                        return
                    }
                    print("✅ Connection complete, processing \(receivedData.count) bytes")
                    hasProcessed = true
                    self.processHTTPRequest(receivedData, on: connection)
                } else {
                    // Continue receiving
                    receiveChunk()
                }
            }
        }
        
        receiveChunk()
    }
    
    private func processHTTPRequest(_ data: Data, on connection: NWConnection) {
        // Find header end
        guard let headerEnd = data.range(of: "\r\n\r\n".data(using: .utf8)!),
              let headerString = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        print("📝 \(method) \(path)")
        
        switch (method, path) {
        case ("GET", "/"):
            sendHTMLResponse(connection: connection)
        case ("POST", "/api/createFolder"):
            handleCreateFolder(data: data, connection: connection)
        case ("POST", "/api/createFile"):
            handleCreateFile(data: data, connection: connection)
        case ("GET", "/api/folders"):
            sendFoldersListResponse(connection: connection)
        case ("OPTIONS", _):
            sendCORSResponse(connection: connection)
        default:
            sendResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    private func handleCreateFolder(data: Data, connection: NWConnection) {
        guard let headerEnd = data.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let bodyData = data[headerEnd.upperBound...]
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let folderName = json["folderName"] as? String, !folderName.isEmpty else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let fileManager = self.fileManager else {
                self?.sendResponse(connection: connection, statusCode: 500, body: "Server error")
                return
            }
            
            // Check if folder already exists
            if fileManager.folders.contains(where: { $0.name == folderName }) {
                self.sendResponse(connection: connection, statusCode: 400, body: "Folder already exists")
                return
            }
            
            let folder = Folder(id: UUID(), name: folderName, createdDate: Date(), modifiedDate: Date())
            fileManager.addFolder(folder)
            
            print("✅ Created folder: \(folderName)")
            self.sendResponse(connection: connection, statusCode: 200, body: "Folder created")
            
            self.uploadStatus[folderName] = "Folder created successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.uploadStatus.removeValue(forKey: folderName)
            }
        }
    }
    
    private func handleCreateFile(data: Data, connection: NWConnection) {
        guard let headerEnd = data.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let bodyData = data[headerEnd.upperBound...]
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let fileName = json["fileName"] as? String, !fileName.isEmpty,
              let content = json["content"] as? String else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let folderName = json["folderName"] as? String
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let fileManager = self.fileManager else {
                self?.sendResponse(connection: connection, statusCode: 500, body: "Server error")
                return
            }
            
            // Find folder ID if folder name is provided
            var folderId: UUID? = nil
            if let folderName = folderName, !folderName.isEmpty {
                if let folder = fileManager.folders.first(where: { $0.name == folderName }) {
                    folderId = folder.id
                } else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "Folder not found")
                    return
                }
            }
            
            let textFile = TextFile(id: UUID(), name: fileName, content: content, modifiedDate: Date(), folderId: folderId)
            fileManager.addFile(textFile)
            
            print("✅ Created file: \(fileName)")
            self.sendResponse(connection: connection, statusCode: 200, body: "File created")
            
            self.uploadStatus[fileName] = "File created successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.uploadStatus.removeValue(forKey: fileName)
            }
        }
    }
    
    private func sendHTMLResponse(connection: NWConnection) {
        let html = generateHTML()
        
        print("📄 Sending HTML response (\(html.utf8.count) bytes)")
        
        let response = "HTTP/1.1 200 OK\r\n" +
                      "Content-Type: text/html; charset=utf-8\r\n" +
                      "Content-Length: \(html.utf8.count)\r\n\r\n" +
                      html
        
        sendRaw(response, on: connection)
    }
    
    private func sendFoldersListResponse(connection: NWConnection) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let fileManager = self.fileManager else {
                self?.sendResponse(connection: connection, statusCode: 500, body: "[]")
                return
            }
            
            let folderNames = fileManager.folders.map { $0.name }
            if let jsonData = try? JSONSerialization.data(withJSONObject: folderNames),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self.sendJSONResponse(connection: connection, json: jsonString)
            } else {
                self.sendResponse(connection: connection, statusCode: 500, body: "[]")
            }
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : "Error"
        print("📤 Sending \(statusCode) response: \(body.prefix(50))...")
        
        let response = "HTTP/1.1 \(statusCode) \(statusText)\r\n" +
                      "Content-Type: text/plain; charset=utf-8\r\n" +
                      "Content-Length: \(body.utf8.count)\r\n\r\n" +
                      body
        
        sendRaw(response, on: connection)
    }
    
    private func sendJSONResponse(connection: NWConnection, json: String) {
        let response = "HTTP/1.1 200 OK\r\n" +
                      "Content-Type: application/json; charset=utf-8\r\n" +
                      "Content-Length: \(json.utf8.count)\r\n\r\n" +
                      json
        
        sendRaw(response, on: connection)
    }
    
    private func sendCORSResponse(connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\n" +
                      "Access-Control-Allow-Origin: *\r\n" +
                      "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                      "Access-Control-Allow-Headers: Content-Type\r\n" +
                      "Content-Length: 0\r\n\r\n"
        
        sendRaw(response, on: connection)
    }
    
    private func sendRaw(_ response: String, on connection: NWConnection) {
        guard let data = response.data(using: .utf8) else {
            print("⚠️ Failed to convert response to data")
            return
        }
        
        print("📡 Sending response (\(data.count) bytes)...")
        
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Response data processed by network stack")
            }
            
            // Remove from active connections
            self?.activeConnections.removeAll { $0 === connection }
            
            // Schedule cleanup after a timeout to allow client to read data
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                print("🧹 Closing connection after timeout")
                connection.cancel()
            }
        })
    }
    
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Text Upload</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    padding: 20px;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 16px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    overflow: hidden;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px;
                    text-align: center;
                }
                .header h1 { font-size: 28px; margin-bottom: 8px; }
                .header p { opacity: 0.9; font-size: 14px; }
                .content { padding: 30px; }
                .section {
                    margin-bottom: 30px;
                    padding: 20px;
                    background: #f8f9fa;
                    border-radius: 12px;
                }
                .section h2 {
                    font-size: 18px;
                    color: #333;
                    margin-bottom: 15px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                input, select, textarea, button {
                    width: 100%;
                    padding: 12px 16px;
                    border: 2px solid #e0e0e0;
                    border-radius: 8px;
                    font-size: 15px;
                    font-family: inherit;
                    margin-bottom: 12px;
                    transition: all 0.3s;
                }
                input:focus, select:focus, textarea:focus {
                    outline: none;
                    border-color: #667eea;
                }
                textarea {
                    min-height: 150px;
                    resize: vertical;
                }
                button {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border: none;
                    cursor: pointer;
                    font-weight: 600;
                    margin-bottom: 0;
                }
                button:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4); }
                button:active { transform: translateY(0); }
                .status {
                    padding: 12px;
                    margin: 10px 0;
                    border-radius: 8px;
                    text-align: center;
                    font-weight: 600;
                }
                .status-success { background: #d4edda; color: #155724; }
                .status-error { background: #f8d7da; color: #721c24; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📝 Text File Upload</h1>
                    <p>Create folders and text files for your Text-to-Speech library</p>
                </div>
                <div class="content">
                    <div class="section">
                        <h2>📁 Create New Folder</h2>
                        <input type="text" id="newFolder" placeholder="Enter folder name">
                        <button onclick="createFolder()">Create Folder</button>
                        <div id="folderStatus"></div>
                    </div>
                    
                    <div class="section">
                        <h2>📄 Create New File</h2>
                        <input type="text" id="fileName" placeholder="Enter file name">
                        <select id="folderSelect">
                            <option value="">-- Select folder (optional) --</option>
                        </select>
                        <textarea id="fileContent" placeholder="Enter text content here..."></textarea>
                        <button onclick="createFile()">Create File</button>
                        <div id="fileStatus"></div>
                    </div>
                </div>
            </div>
            
            <script>
                // Load folders on page load
                window.addEventListener('load', loadFolders);
                
                function loadFolders() {
                    fetch('/api/folders')
                        .then(r => r.json())
                        .then(folders => {
                            const select = document.getElementById('folderSelect');
                            // Keep the default option
                            select.innerHTML = '<option value="">-- Select folder (optional) --</option>';
                            folders.forEach(folder => {
                                const option = document.createElement('option');
                                option.value = folder;
                                option.textContent = folder;
                                select.appendChild(option);
                            });
                        })
                        .catch(e => console.error('Error loading folders:', e));
                }
                
                function createFolder() {
                    const name = document.getElementById('newFolder').value.trim();
                    if (!name) {
                        showStatus('folderStatus', 'Please enter a folder name', false);
                        return;
                    }
                    
                    fetch('/api/createFolder', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ folderName: name })
                    })
                    .then(r => {
                        if (r.ok) {
                            showStatus('folderStatus', 'Folder created successfully!', true);
                            document.getElementById('newFolder').value = '';
                            loadFolders();
                        } else {
                            return r.text().then(msg => {
                                showStatus('folderStatus', msg || 'Failed to create folder', false);
                            });
                        }
                    })
                    .catch(e => {
                        showStatus('folderStatus', 'Error: ' + e.message, false);
                    });
                }
                
                function createFile() {
                    const fileName = document.getElementById('fileName').value.trim();
                    const content = document.getElementById('fileContent').value;
                    const folderName = document.getElementById('folderSelect').value;
                    
                    if (!fileName) {
                        showStatus('fileStatus', 'Please enter a file name', false);
                        return;
                    }
                    
                    const payload = {
                        fileName: fileName,
                        content: content
                    };
                    
                    if (folderName) {
                        payload.folderName = folderName;
                    }
                    
                    fetch('/api/createFile', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(payload)
                    })
                    .then(r => {
                        if (r.ok) {
                            showStatus('fileStatus', 'File created successfully!', true);
                            document.getElementById('fileName').value = '';
                            document.getElementById('fileContent').value = '';
                            document.getElementById('folderSelect').selectedIndex = 0;
                        } else {
                            return r.text().then(msg => {
                                showStatus('fileStatus', msg || 'Failed to create file', false);
                            });
                        }
                    })
                    .catch(e => {
                        showStatus('fileStatus', 'Error: ' + e.message, false);
                    });
                }
                
                function showStatus(elementId, message, isSuccess) {
                    const statusDiv = document.getElementById(elementId);
                    statusDiv.textContent = message;
                    statusDiv.className = 'status ' + (isSuccess ? 'status-success' : 'status-error');
                    setTimeout(() => {
                        statusDiv.textContent = '';
                        statusDiv.className = 'status';
                    }, 3000);
                }
            </script>
        </body>
        </html>
        """
    }
}

