//
//  ContentView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var fileManager: FileManagerViewModel
    @EnvironmentObject var ttsManager: TTSManager
    @State private var showingVoicePicker = false
    @State private var showingFileEditor = false
    @State private var selectedFile: TextFile?
    @State private var fileToEdit: TextFile? // Track the file to edit in the sheet
    @State private var showingFolderEditor = false
    @State private var selectedFolder: Folder?
    @State private var showingFolderView = false
    @State private var folderToView: Folder?
    @State private var folderToDisplay: Folder? // Track the folder to display in the sheet
    
    // Get files on landing page (folderId == nil)
    private var landingPageFiles: [TextFile] {
        fileManager.getFilesOnLandingPage()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppTheme.accentGradient)
                            .padding(.top, 20)
                        
                        Text("Text to Speech")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                    
                    // Folders and Files List
                    if fileManager.folders.isEmpty && landingPageFiles.isEmpty {
                        VStack(spacing: 30) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.primaryGradient)
                            Text("No files yet")
                                .font(.title2)
                                .foregroundColor(AppTheme.primaryText)
                            Text("Tap + to create your first file")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Button(action: {
                                showingVoicePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "speaker.wave.2")
                                    Text("Select Voice")
                                }
                                .font(.headline)
                            }
                            .primaryButton()
                            .padding(.top, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Folders Section
                            if !fileManager.folders.isEmpty {
                                Section(header: Text("Folders")
                                    .foregroundColor(AppTheme.primaryText)
                                    .font(.headline)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                    .textCase(nil)) {
                                    ForEach(fileManager.folders) { folder in
                                        FolderRowView(folder: folder)
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                folderToView = folder
                                                folderToDisplay = folder
                                                // Small delay to ensure state is set before sheet opens
                                                DispatchQueue.main.async {
                                                    showingFolderView = true
                                                }
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    fileManager.deleteFolder(folder)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                            
                            // Files Section (only landing page files)
                            if !landingPageFiles.isEmpty {
                                Section(header: Text("Files")
                                    .foregroundColor(AppTheme.primaryText)
                                    .font(.headline)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                    .textCase(nil)) {
                                    ForEach(landingPageFiles) { file in
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
                                                    selectedFile = file
                                                    fileToEdit = file
                                                    showingFileEditor = true
                                                    // Small delay to ensure sheet opens before playing
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                        ttsManager.playFile(file, from: landingPageFiles)
                                                    }
                                                } label: {
                                                    Label("Play", systemImage: "play.fill")
                                                }
                                                .tint(AppTheme.accentColor)
                                                
                                                // Move to folder menu
                                                if !fileManager.folders.isEmpty {
                                                    Menu {
                                                        Button("Move to Landing Page") {
                                                            fileManager.moveFile(file, toFolder: nil)
                                                        }
                                                        ForEach(fileManager.folders) { folder in
                                                            Button("Move to \(folder.name)") {
                                                                fileManager.moveFile(file, toFolder: folder.id)
                                                            }
                                                        }
                                                    } label: {
                                                        Label("Move", systemImage: "folder")
                                                    }
                                                    .tint(AppTheme.folderColor)
                                                }
                                            }
                                            .onTapGesture {
                                                selectedFile = file
                                                fileToEdit = file
                                                // Small delay to ensure state is set before sheet opens
                                                DispatchQueue.main.async {
                                                    showingFileEditor = true
                                                }
                                            }
                                    }
                                    .onDelete(perform: deleteLandingPageFiles)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                    
                }
            }
            .navigationTitle("yyReader")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(AppTheme.primaryGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingVoicePicker = true
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Upload button
                    NavigationLink(destination: UploadView().environmentObject(fileManager)) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(AppTheme.primaryText)
                    }
                    
                    // Create folder button
                    Button(action: {
                        selectedFolder = nil
                        showingFolderEditor = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(AppTheme.primaryText)
                    }
                    
                    // Create file button
                    Button(action: {
                        // Explicitly set to nil to ensure new file creation
                        selectedFile = nil
                        fileToEdit = nil
                        // Small delay to ensure state is cleared
                        DispatchQueue.main.async {
                            showingFileEditor = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showingVoicePicker) {
                VoicePickerView()
            }
            .sheet(isPresented: $showingFileEditor) {
                // Use fileToEdit if available, otherwise use selectedFile, otherwise new file
                // Use file ID so view updates correctly during prev/next navigation
                // This matches landing page behavior exactly
                if let file = fileToEdit ?? selectedFile {
                    FileEditorView(file: file, folderId: file.folderId)
                        .id(file.id) // Use file ID - same as landing page
                } else {
                    FileEditorView(file: nil, folderId: nil)
                }
            }
            .onChange(of: showingFileEditor) { isShowing in
                // Clear fileToEdit when sheet is dismissed
                if !isShowing {
                    fileToEdit = nil
                }
            }
            .sheet(isPresented: $showingFolderEditor) {
                FolderEditorView(folder: selectedFolder)
            }
            .sheet(isPresented: $showingFolderView) {
                // Use folderToDisplay which is set synchronously before showingFolderView
                // Fallback to folderToView if folderToDisplay is somehow nil
                if let folder = folderToDisplay ?? folderToView {
                    FolderView(folder: folder)
                }
            }
            .onChange(of: showingFolderView) { isShowing in
                // Clear folderToDisplay when sheet is dismissed
                if !isShowing {
                    folderToDisplay = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayFileFromFolder"))) { notification in
                // Handle playing file from folder - set fileToEdit before opening, like landing page
                if let file = notification.userInfo?["file"] as? TextFile {
                    selectedFile = file
                    fileToEdit = file
                    showingFileEditor = true
                }
            }
            .onChange(of: ttsManager.currentFile?.id) { newFileId in
                // When currentFile changes (e.g., prev/next navigation)
                // Only handle if editor is already open (for prev/next navigation)
                // Don't open editor here for folder files - that's handled by notification
                guard let newFileId = newFileId else { return }
                
                // Only update if editor is already open (for prev/next navigation)
                guard showingFileEditor, let currentFileToEdit = fileToEdit else {
                    // Editor not open - don't open it here for folder files
                    // Landing page files are handled by tap/play actions directly
                    return
                }
                
                // Editor is open - update fileToEdit for prev/next navigation
                // EXACT same as landing page - update fileToEdit to the new file
                // This ensures the view updates correctly for both landing page and folder files
                if currentFileToEdit.id != newFileId {
                    // Different file - find and update (prev/next navigation)
                    var newFile = landingPageFiles.first(where: { $0.id == newFileId })
                    
                    // If not found in landing page, search in all folders
                    if newFile == nil {
                        for folder in fileManager.folders {
                            let folderFiles = fileManager.getFilesInFolder(folder.id)
                            if let foundFile = folderFiles.first(where: { $0.id == newFileId }) {
                                newFile = foundFile
                                break
                            }
                        }
                    }
                    
                    if let file = newFile {
                        selectedFile = file
                        fileToEdit = file
                    }
                }
                // If it's the same file, don't update - just stay on the current view
            }
        }
    }
    
    private func deleteLandingPageFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = landingPageFiles[index]
            fileManager.deleteFile(file)
        }
    }
}

struct FolderRowView: View {
    let folder: Folder
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(AppTheme.folderColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Text(folder.modifiedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Divider()
                .background(AppTheme.secondaryText.opacity(0.3))
                .padding(.leading, 16)
        }
    }
}

struct FileRowView: View {
    @EnvironmentObject var ttsManager: TTSManager
    let file: TextFile
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(file.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                    
                    if !file.content.isEmpty {
                        Text(file.content)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(2)
                    } else {
                        Text("Empty file")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .italic()
                    }
                    
                    Text(file.modifiedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
                
                if ttsManager.currentFile?.id == file.id && ttsManager.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(AppTheme.accentGradient)
                        .font(.title3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Divider()
                .background(AppTheme.secondaryText.opacity(0.3))
                .padding(.leading, 16)
        }
    }
}

