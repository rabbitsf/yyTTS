//
//  FileManagerViewModel.swift
//  yyReader
//
//  Created on 2024
//

import Foundation
import SwiftUI
import Combine

class FileManagerViewModel: ObservableObject {
    @Published var files: [TextFile] = []
    @Published var folders: [Folder] = []
    
    private let documentsDirectory: URL
    private let filesDirectory: URL
    private let foldersDirectory: URL
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        filesDirectory = documentsDirectory.appendingPathComponent("TextFiles")
        foldersDirectory = documentsDirectory.appendingPathComponent("Folders")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: foldersDirectory, withIntermediateDirectories: true)
        
        loadFolders()
        loadFiles()
    }
    
    func addFile(_ file: TextFile) {
        files.append(file)
        saveFile(file)
        sortFiles()
    }
    
    func updateFile(_ file: TextFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
            saveFile(file)
            sortFiles()
        }
    }
    
    func deleteFile(_ file: TextFile) {
        files.removeAll { $0.id == file.id }
        deleteFileFromDisk(file)
    }
    
    private func saveFile(_ file: TextFile) {
        let fileURL = filesDirectory.appendingPathComponent("\(file.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(file) {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadFiles() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: filesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        files = fileURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let file = try? decoder.decode(TextFile.self, from: data) else {
                    return nil
                }
                return file
            }
        
        sortFiles()
    }
    
    private func deleteFileFromDisk(_ file: TextFile) {
        let fileURL = filesDirectory.appendingPathComponent("\(file.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func sortFiles() {
        files.sort { $0.modifiedDate < $1.modifiedDate }
    }
    
    // Folder management
    func addFolder(_ folder: Folder) {
        folders.append(folder)
        saveFolder(folder)
        sortFolders()
    }
    
    func updateFolder(_ folder: Folder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
            saveFolder(folder)
            sortFolders()
        }
    }
    
    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        deleteFolderFromDisk(folder)
        // Move all files in this folder to landing page (folderId = nil)
        files.filter { $0.folderId == folder.id }.forEach { file in
            var updatedFile = file
            updatedFile.folderId = nil
            updateFile(updatedFile)
        }
    }
    
    func moveFile(_ file: TextFile, toFolder folderId: UUID?) {
        var updatedFile = file
        updatedFile.folderId = folderId
        updatedFile.modifiedDate = Date()
        updateFile(updatedFile)
    }
    
    func getFilesInFolder(_ folderId: UUID?) -> [TextFile] {
        return files.filter { $0.folderId == folderId }
    }
    
    func getFilesOnLandingPage() -> [TextFile] {
        return files.filter { $0.folderId == nil }
    }
    
    private func saveFolder(_ folder: Folder) {
        let folderURL = foldersDirectory.appendingPathComponent("\(folder.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(folder) {
            try? data.write(to: folderURL)
        }
    }
    
    private func loadFolders() {
        guard let folderURLs = try? FileManager.default.contentsOfDirectory(
            at: foldersDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        folders = folderURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let folder = try? decoder.decode(Folder.self, from: data) else {
                    return nil
                }
                return folder
            }
        
        sortFolders()
    }
    
    private func deleteFolderFromDisk(_ folder: Folder) {
        let folderURL = foldersDirectory.appendingPathComponent("\(folder.id.uuidString).json")
        try? FileManager.default.removeItem(at: folderURL)
    }
    
    private func sortFolders() {
        folders.sort { $0.modifiedDate < $1.modifiedDate }
    }
}

struct TextFile: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var modifiedDate: Date
    var folderId: UUID? // nil means file is on landing page
}

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdDate: Date
    var modifiedDate: Date
}

