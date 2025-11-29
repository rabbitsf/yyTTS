//
//  FileEditorView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI
import UIKit

struct FileEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fileManager: FileManagerViewModel
    @EnvironmentObject var ttsManager: TTSManager
    
    let file: TextFile?
    let folderId: UUID? // nil means landing page, otherwise folder ID
    @State private var fileName: String
    @State private var fileContent: String
    @State private var displayedFileId: UUID?
    @FocusState private var isContentFocused: Bool
    
    // State variable to force toolbar updates when ttsManager changes
    // This ensures toolbar reactivity even when view is recreated
    @State private var toolbarUpdateTrigger: Bool = false
    
    // Computed property to ensure toolbar is always reactive to playing state
    private var isCurrentlyPlaying: Bool {
        // Access ttsManager properties directly to ensure reactivity
        // The toolbarUpdateTrigger is toggled in onChange handlers to force updates
        let _ = toolbarUpdateTrigger // Reference to force observation
        return ttsManager.isPlaying || ttsManager.currentFile != nil
    }
    
    init(file: TextFile?, folderId: UUID? = nil) {
        self.file = file
        self.folderId = folderId
        _fileName = State(initialValue: file?.name ?? "")
        _fileContent = State(initialValue: file?.content ?? "")
        _displayedFileId = State(initialValue: file?.id)
    }
    
    // Get the file to display - use the file parameter, not currentFile
    // Only use currentFile when navigating with prev/next during playback of the same file
    private var displayedFile: TextFile? {
        return file
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // File name field
                    TextField("File name", text: $fileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Content text editor - use GeometryReader to get available height
                    GeometryReader { geometry in
                        let playbackControlsHeight: CGFloat = (ttsManager.isPlaying || ttsManager.currentFile != nil) ? 96 : 0
                        let availableHeight = geometry.size.height - playbackControlsHeight
                        
                        ZStack(alignment: .topLeading) {
                            // Background - adaptive for light/dark mode
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .padding(.horizontal, 16)
                            
                            // Show highlighted text when playing, TextEditor when not
                            if ttsManager.isPlaying || ttsManager.currentFile != nil {
                                // Highlighted text view for playback
                                HighlightedTextView(
                                    text: fileContent,
                                    highlightedRange: ttsManager.currentSpeakingRange
                                )
                                .frame(width: geometry.size.width - 48, height: max(availableHeight, 200))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            } else {
                                // Regular TextEditor for editing
                                TextEditor(text: $fileContent)
                                    .focused($isContentFocused)
                                    .scrollContentBackground(.hidden)
                                    .frame(width: geometry.size.width - 48, height: max(availableHeight, 200))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Group {
                                            if fileContent.isEmpty {
                                                VStack {
                                                    HStack {
                                                        Text("Paste your text here...")
                                                            .foregroundColor(AppTheme.secondaryText)
                                                            .padding(.leading, 28)
                                                            .padding(.top, 16)
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                .allowsHitTesting(false)
                                            }
                                        }
                                    )
                                    .onChange(of: fileContent) { newValue in
                                        if displayedFile == nil && fileName.isEmpty && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            let trimmedContent = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            let first30Chars = String(trimmedContent.prefix(30))
                                            fileName = first30Chars
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        if !isContentFocused {
                                            isContentFocused = true
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Playback Controls (shown when playing)
                    if ttsManager.isPlaying || ttsManager.currentFile != nil {
                        Divider()
                            .padding(.vertical, 8)
                        PlaybackControlsView()
                            .frame(height: 80)
                            .background(AppTheme.cardGradient)
                    }
                }
            }
            .navigationTitle(displayedFile == nil ? "New File" : "Edit File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(AppTheme.primaryGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Done button - shown when a file is playing
                    // Reference toolbarUpdateTrigger to force observation updates
                    // Directly access ttsManager to ensure reactivity
                    let _ = toolbarUpdateTrigger
                    if ttsManager.isPlaying || ttsManager.currentFile != nil {
                        Button("Done") {
                            // Stop all playback completely
                            ttsManager.stop()
                            dismiss()
                        }
                        .foregroundColor(AppTheme.primaryText)
                    } else {
                        // Regular toolbar items when not playing
                        if !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                playCurrentContent()
                            }) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(AppTheme.primaryText)
                            }
                        }
                        
                        Button("Save") {
                            saveFile()
                        }
                        .disabled(fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundColor(AppTheme.primaryText)
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isContentFocused = false
                        // Stop all playback when Done is tapped
                        ttsManager.stop()
                        dismiss()
                    }
                }
                
            }
            .onAppear {
                // Initialize the displayed file
                // ALWAYS prioritize currentFile if it exists (during playback)
                // This ensures toolbar shows correctly even when view is recreated
                if let currentFile = ttsManager.currentFile {
                    // We're playing - use currentFile to ensure toolbar shows Done button
                    fileName = currentFile.name
                    fileContent = currentFile.content
                    displayedFileId = currentFile.id
                } else {
                    // Not playing - use file parameter
                    updateFileContent()
                }
                // Force toolbar update to ensure it's computed correctly
                toolbarUpdateTrigger.toggle()
            }
            .onChange(of: file?.id) { newFileId in
                // When the file parameter changes (prev/next navigation), update the content
                // But only if not currently playing (to avoid conflicts)
                if ttsManager.currentFile == nil {
                    updateFileContent()
                }
            }
            .onChange(of: ttsManager.currentFile?.id) { newFileId in
                // When currentFile changes (e.g., prev/next navigation)
                // Always update to show the currently playing file
                // This works for both landing page and folder files
                // The view stays stable (file parameter doesn't change), toolbar stays reactive
                if let currentFile = ttsManager.currentFile {
                    // Update to show the currently playing file
                    fileName = currentFile.name
                    fileContent = currentFile.content
                    displayedFileId = currentFile.id
                }
                // Force toolbar update by toggling trigger
                toolbarUpdateTrigger.toggle()
            }
            .onChange(of: ttsManager.isPlaying) { _ in
                // Force toolbar update when playing state changes
                toolbarUpdateTrigger.toggle()
            }
        }
    }
    
    private func updateFileContent() {
        // Initialize or update the displayed file content
        if let file = file {
            // We're viewing/editing an existing file
            fileName = file.name
            fileContent = file.content
            displayedFileId = file.id
        } else {
            // We're creating a new file - ensure it's completely empty
            // Reset everything to prevent any prefilling
            fileName = ""
            fileContent = ""
            displayedFileId = nil
            // Make sure we're not showing currentFile content
            if ttsManager.currentFile != nil {
                // Force clear any potential currentFile influence
                isContentFocused = false
            }
        }
    }
    
    private func updateDisplayedFile() {
        // Don't update if we're creating a new file (file == nil)
        if file == nil {
            // Creating a new file - keep it empty, don't update from currentFile
            return
        }
        
        // Only update if the file we're viewing is the same as the current playing file
        // This allows prev/next navigation to update the view when playing the same file
        if let currentFile = ttsManager.currentFile,
           let file = file,
           file.id == currentFile.id,
           displayedFileId != currentFile.id {
            // We're viewing the file that's currently playing, and it changed
            fileName = currentFile.name
            fileContent = currentFile.content
            displayedFileId = currentFile.id
        } else if let file = file, displayedFileId != file.id {
            // We're viewing a different file (not the one playing) - show that file
            fileName = file.name
            fileContent = file.content
            displayedFileId = file.id
        }
    }
    
    private func saveFile() {
        let trimmedContent = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        // Auto-generate name from content if empty (first 30 characters)
        let finalName: String
        if fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalName = String(trimmedContent.prefix(30))
        } else {
            finalName = fileName
        }
        
        // Use displayedFile (which could be currentFile) or the original file parameter
        let fileToSave = displayedFile ?? file
        
        if let existingFile = fileToSave {
            // Update existing file
            var updatedFile = TextFile(
                id: existingFile.id,
                name: finalName,
                content: fileContent,
                modifiedDate: Date(),
                folderId: existingFile.folderId
            )
            // If creating in a folder context, update folderId
            if folderId != existingFile.folderId {
                updatedFile.folderId = folderId
            }
            fileManager.updateFile(updatedFile)
        } else {
            // Create new file
            let newFile = TextFile(
                id: UUID(),
                name: finalName,
                content: fileContent,
                modifiedDate: Date(),
                folderId: folderId // Set folderId for new files
            )
            fileManager.addFile(newFile)
        }
        dismiss()
    }
    
    private func playCurrentContent() {
        // Get appropriate file list based on folderId
        let filesToPlay: [TextFile]
        if let folderId = folderId {
            filesToPlay = fileManager.getFilesInFolder(folderId)
        } else {
            filesToPlay = fileManager.getFilesOnLandingPage()
        }
        
        let tempFile = TextFile(
            id: file?.id ?? UUID(),
            name: fileName.isEmpty ? "Untitled" : fileName,
            content: fileContent,
            modifiedDate: Date(),
            folderId: folderId
        )
        ttsManager.playFile(tempFile, from: filesToPlay)
    }
}

// Custom view to display text with word highlighting during TTS playback
struct HighlightedTextView: View {
    let text: String
    let highlightedRange: NSRange?
    @State private var lastScrollMarkerIndex: Int = -1
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Build text with markers embedded for scrolling
                    // Text is split into chunks, each with an ID for reliable scrolling
                    if highlightedRange != nil {
                        createTextWithMarkers()
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let attributedText = createAttributedString() {
                        Text(attributedText)
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(Color(UIColor.label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            }
            .onChange(of: highlightedRange) { newRange in
                // Scroll continuously as highlight moves
                if let range = newRange,
                   range.location != NSNotFound,
                   range.location < text.count {
                    // Calculate which marker segment we're in (markers every 50 chars)
                    let markerIndex = range.location / 50
                    
                    // Scroll whenever we move to a different segment
                    // Also force scroll if we've moved significantly even within the same segment
                    let shouldScroll = lastScrollMarkerIndex != markerIndex || 
                                      (lastScrollMarkerIndex >= 0 && abs(range.location - (lastScrollMarkerIndex * 50)) > 100)
                    
                    if shouldScroll {
                        lastScrollMarkerIndex = markerIndex
                        let scrollID = "marker_\(markerIndex)"
                        
                        // Try scrolling - if marker doesn't exist, it will fail silently
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(scrollID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func createTextWithMarkers() -> some View {
        // Split text into chunks with markers for scrolling
        // Each chunk is a separate Text view with an ID for reliable scrolling
        let chunkSize = 50
        let numChunks = (text.count / chunkSize) + 1
        
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<numChunks, id: \.self) { chunkIndex in
                let startChar = chunkIndex * chunkSize
                let endChar = min(startChar + chunkSize, text.count)
                
                if startChar < text.count {
                    let startIndex = text.index(text.startIndex, offsetBy: startChar)
                    let endIndex = text.index(text.startIndex, offsetBy: endChar)
                    let chunkText = String(text[startIndex..<endIndex])
                    
                    // Create attributed string for this chunk with highlighting
                    if let chunkAttributed = createAttributedStringForChunk(chunkText, startChar: startChar) {
                        Text(chunkAttributed)
                            .id("marker_\(chunkIndex)")
                    } else {
                        Text(chunkText)
                            .foregroundColor(AppTheme.primaryText)
                            .id("marker_\(chunkIndex)")
                    }
                }
            }
        }
    }
    
    private func createAttributedStringForChunk(_ chunk: String, startChar: Int) -> AttributedString? {
        guard let highlightedRange = highlightedRange,
              highlightedRange.location != NSNotFound else {
            return nil
        }
        
        var attributedString = AttributedString(chunk)
        
        // Set default text color for the entire chunk (adapts to light/dark mode)
        // Use UIColor.label which properly adapts to light/dark mode
        attributedString.foregroundColor = Color(UIColor.label)
        
        let chunkStart = startChar
        let chunkEnd = startChar + chunk.count
        
        // Check if highlight overlaps with this chunk
        let highlightStart = highlightedRange.location
        let highlightEnd = highlightedRange.location + highlightedRange.length
        
        if highlightEnd > chunkStart && highlightStart < chunkEnd {
            // Calculate the overlap range within this chunk
            let overlapStart = max(0, highlightStart - chunkStart)
            let overlapEnd = min(chunk.count, highlightEnd - chunkStart)
            
            if overlapStart < overlapEnd && overlapStart < chunk.count {
                let startIndex = chunk.index(chunk.startIndex, offsetBy: overlapStart)
                let endIndex = chunk.index(chunk.startIndex, offsetBy: min(overlapEnd, chunk.count))
                
                if startIndex < endIndex && endIndex <= chunk.endIndex {
                    let range = startIndex..<endIndex
                    if let attributedRange = Range(range, in: attributedString) {
                        attributedString[attributedRange].backgroundColor = AppTheme.accentColor.opacity(0.5)
                        // Keep the same foreground color for highlighted text (adapts to light/dark mode)
                        attributedString[attributedRange].foregroundColor = Color(UIColor.label)
                    }
                }
            }
        }
        
        return attributedString
    }
    
    private func createAttributedString() -> AttributedString? {
        guard let highlightedRange = highlightedRange,
              highlightedRange.location != NSNotFound,
              highlightedRange.location < text.count else {
            return nil
        }
        
        // Create AttributedString from the FULL text - structure never changes
        var attributedString = AttributedString(text)
        
        // Set default text color for the entire string (adapts to light/dark mode)
        // Use UIColor.label which properly adapts to light/dark mode
        attributedString.foregroundColor = Color(UIColor.label)
        
        // Ensure the range is valid
        let startIndex = text.index(text.startIndex, offsetBy: min(highlightedRange.location, text.count))
        let endLocation = min(highlightedRange.location + highlightedRange.length, text.count)
        let endIndex = text.index(text.startIndex, offsetBy: endLocation)
        
        if startIndex < endIndex && endIndex <= text.endIndex {
            let range = startIndex..<endIndex
            if let attributedRange = Range(range, in: attributedString) {
                // ONLY change the highlight color - text structure stays the same
                attributedString[attributedRange].backgroundColor = AppTheme.accentColor.opacity(0.5)
                // Keep the same foreground color for highlighted text (adapts to light/dark mode)
                attributedString[attributedRange].foregroundColor = Color(UIColor.label)
            }
        }
        
        return attributedString
    }
}


