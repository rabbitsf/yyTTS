//
//  FolderView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI

struct FolderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fileManager: FileManagerViewModel
    @EnvironmentObject var ttsManager: TTSManager
    
    let folder: Folder
    @State private var showingFileEditor = false
    @State private var selectedFile: TextFile?
    @State private var fileToEdit: TextFile?
    @State private var fileToEditId: UUID? // Track file ID separately for reliability
    
    // Get files in this folder
    private var folderFiles: [TextFile] {
        fileManager.getFilesInFolder(folder.id)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if folderFiles.isEmpty {
                        VStack(spacing: 30) {
                            Image(systemName: "folder")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.folderColor)
                            Text("No files in this folder")
                                .font(.title2)
                                .foregroundColor(AppTheme.primaryText)
                            Text("Tap + to add a file")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(folderFiles) { file in
                                FileRowView(file: file)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .environmentObject(ttsManager)
                                    .contentShape(Rectangle())
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            fileManager.deleteFile(file)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            // Set the file in ContentView before dismissing, matching landing page behavior
                                            // We need to communicate with ContentView to set fileToEdit before opening
                                            // Use a notification or pass through environment
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("PlayFileFromFolder"),
                                                object: nil,
                                                userInfo: ["file": file, "folderId": folder.id as Any]
                                            )
                                            dismiss()
                                            // Play file after a short delay to ensure FolderView is dismissed
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                ttsManager.playFile(file, from: folderFiles)
                                            }
                                        } label: {
                                            Label("Play", systemImage: "play.fill")
                                        }
                                        .tint(AppTheme.accentColor)
                                        
                                        // Move to landing page or other folders
                                        Menu {
                                            Button("Move to Landing Page") {
                                                fileManager.moveFile(file, toFolder: nil)
                                            }
                                            ForEach(fileManager.folders.filter { $0.id != folder.id }) { otherFolder in
                                                Button("Move to \(otherFolder.name)") {
                                                    fileManager.moveFile(file, toFolder: otherFolder.id)
                                                }
                                            }
                                        } label: {
                                            Label("Move", systemImage: "folder")
                                        }
                                        .tint(AppTheme.folderColor)
                                    }
                                    .onTapGesture {
                                        selectedFile = file
                                        fileToEdit = file
                                        fileToEditId = file.id
                                        // Small delay to ensure state is set before sheet opens
                                        DispatchQueue.main.async {
                                            showingFileEditor = true
                                        }
                                    }
                            }
                            .onDelete(perform: deleteFiles)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(AppTheme.primaryGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedFile = nil
                        fileToEdit = nil
                        DispatchQueue.main.async {
                            showingFileEditor = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingFileEditor) {
                // Use fileToEdit if available, otherwise use selectedFile, otherwise new file
                // Use file ID so view updates correctly during prev/next navigation
                // This matches landing page behavior exactly
                // Use fullScreenCover instead of sheet because FolderView is already a sheet
                if let file = fileToEdit ?? selectedFile {
                    FileEditorView(file: file, folderId: file.folderId ?? folder.id)
                        .id(file.id) // Use file ID - same as landing page
                } else {
                    FileEditorView(file: nil, folderId: folder.id)
                }
            }
            .onChange(of: showingFileEditor) { isShowing in
                // Clear fileToEdit when sheet is dismissed, but only if not playing
                if !isShowing && !ttsManager.isPlaying {
                    fileToEdit = nil
                    fileToEditId = nil
                    selectedFile = nil
                }
            }
            .onChange(of: ttsManager.currentFile?.id) { newFileId in
                // When currentFile changes (e.g., prev/next navigation)
                // Only handle if editor is already open (for prev/next navigation)
                guard let newFileId = newFileId else { return }
                
                // Only update if editor is already open (for prev/next navigation)
                guard showingFileEditor, let currentFileToEdit = fileToEdit else {
                    // Editor not open - don't open it here
                    return
                }
                
                // Editor is open - update fileToEdit for prev/next navigation
                // Use the same mechanism as ContentView (landing page)
                if currentFileToEdit.id != newFileId {
                    // Different file - find and update (prev/next navigation)
                    // First check in current folder files
                    var newFile = folderFiles.first(where: { $0.id == newFileId })
                    
                    // If not found in current folder, search in all folders (like ContentView does)
                    if newFile == nil {
                        for folder in fileManager.folders {
                            let filesInFolder = fileManager.getFilesInFolder(folder.id)
                            if let foundFile = filesInFolder.first(where: { $0.id == newFileId }) {
                                newFile = foundFile
                                break
                            }
                        }
                    }
                    
                    // Also check landing page files
                    if newFile == nil {
                        let landingPageFiles = fileManager.getFilesOnLandingPage()
                        newFile = landingPageFiles.first(where: { $0.id == newFileId })
                    }
                    
                    if let file = newFile {
                        selectedFile = file
                        fileToEdit = file
                        fileToEditId = file.id
                    }
                }
                // If it's the same file, don't update - just stay on the current view
            }
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = folderFiles[index]
            fileManager.deleteFile(file)
        }
    }
}

