//
//  FolderEditorView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI

struct FolderEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fileManager: FileManagerViewModel
    
    let folder: Folder?
    @State private var folderName: String
    @FocusState private var isNameFocused: Bool
    
    init(folder: Folder?) {
        self.folder = folder
        _folderName = State(initialValue: folder?.name ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack {
                    TextField("Folder name", text: $folderName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isNameFocused)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle(folder == nil ? "New Folder" : "Edit Folder")
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(AppTheme.primaryText)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFocused = true
                }
            }
        }
    }
    
    private func saveFolder() {
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let existingFolder = folder {
            // Update existing folder
            let updatedFolder = Folder(
                id: existingFolder.id,
                name: trimmedName,
                createdDate: existingFolder.createdDate,
                modifiedDate: Date()
            )
            fileManager.updateFolder(updatedFolder)
        } else {
            // Create new folder
            let newFolder = Folder(
                id: UUID(),
                name: trimmedName,
                createdDate: Date(),
                modifiedDate: Date()
            )
            fileManager.addFolder(newFolder)
        }
        dismiss()
    }
}

