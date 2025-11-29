//
//  VoicePickerView.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ttsManager: TTSManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                List {
                    Section(header: Text("English Voices")
                        .foregroundColor(AppTheme.primaryText)
                        .font(.headline)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))) {
                        ForEach(ttsManager.englishVoices, id: \.identifier) { voice in
                            VoiceRowView(voice: voice, isSelected: ttsManager.selectedEnglishVoice?.identifier == voice.identifier)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .onTapGesture {
                                    ttsManager.selectEnglishVoice(voice)
                                }
                        }
                    }
                    
                    Section(header: Text("Simplified Chinese Voices")
                        .foregroundColor(AppTheme.primaryText)
                        .font(.headline)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))) {
                        ForEach(ttsManager.simplifiedChineseVoices, id: \.identifier) { voice in
                            VoiceRowView(voice: voice, isSelected: ttsManager.selectedSimplifiedChineseVoice?.identifier == voice.identifier)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .onTapGesture {
                                    ttsManager.selectSimplifiedChineseVoice(voice)
                                }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(AppTheme.primaryGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryText)
                }
            }
        }
    }
}

struct VoiceRowView: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                    Text(voice.language)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentGradient)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Divider()
                .background(AppTheme.secondaryText.opacity(0.3))
                .padding(.leading, 16)
        }
    }
}

