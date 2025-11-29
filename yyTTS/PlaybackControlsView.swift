//
//  PlaybackControlsView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var fileManager: FileManagerViewModel
    @EnvironmentObject var ttsManager: TTSManager
    
    // Get the current context files from TTSManager
    private var currentContextFiles: [TextFile] {
        // Use allFiles from TTSManager which contains the context when playback started
        // This ensures we only navigate within the current context (folder or landing page)
        return ttsManager.getAllFiles()
    }
    
    var body: some View {
        HStack(spacing: 40) {
            // Previous button
            Button(action: {
                ttsManager.playPreviousFile(from: currentContextFiles)
            }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(AppTheme.secondaryGradient)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.secondaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(!ttsManager.canPlayPrevious(from: currentContextFiles))
            .opacity(ttsManager.canPlayPrevious(from: currentContextFiles) ? 1.0 : 0.5)
            
            // Play/Pause button
            Button(action: {
                if ttsManager.isPlaying {
                    ttsManager.pause()
                } else {
                    if let currentFile = ttsManager.currentFile {
                        ttsManager.resume()
                    } else if let firstFile = currentContextFiles.first {
                        ttsManager.playFile(firstFile, from: currentContextFiles)
                    }
                }
            }) {
                Image(systemName: ttsManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(AppTheme.secondaryGradient)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.secondaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Next button
            Button(action: {
                ttsManager.playNextFile(from: currentContextFiles)
            }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(AppTheme.secondaryGradient)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.secondaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(!ttsManager.canPlayNext(from: currentContextFiles))
            .opacity(ttsManager.canPlayNext(from: currentContextFiles) ? 1.0 : 0.5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardGradient)
    }
}

