//
//  TTSManager.swift
//  yyReader
//
//  Created on 2024
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import MediaPlayer

class TTSManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentFile: TextFile?
    @Published var currentSentenceIndex = 0
    @Published var currentSpeakingRange: NSRange? // Range of characters currently being spoken
    
    @Published var selectedEnglishVoice: AVSpeechSynthesisVoice?
    @Published var selectedSimplifiedChineseVoice: AVSpeechSynthesisVoice?
    
    var englishVoices: [AVSpeechSynthesisVoice] = []
    var simplifiedChineseVoices: [AVSpeechSynthesisVoice] = []
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var allFiles: [TextFile] = []
    private var currentFileIndex: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private var fullText: String = "" // Store the full text for range tracking
    private var sentenceOffsets: [Int] = [] // Track character offsets for each sentence
    
    // Public method to get the current context files
    func getAllFiles() -> [TextFile] {
        return allFiles
    }
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommandCenter()
        loadAvailableVoices()
        loadSavedVoicePreferences()
        
        // Observe currentFile changes to update now playing info
        $currentFile
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
                self?.updateRemoteCommandCenter()
            }
            .store(in: &cancellables)
        
        // Observe isPlaying changes to update now playing info
        $isPlaying
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
                self?.updateRemoteCommandCenter()
            }
            .store(in: &cancellables)
    }
    
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove existing targets first
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if !self.isPlaying, self.currentFile != nil {
                    self.resume()
                }
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.isPlaying {
                    self.pause()
                }
            }
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.isPlaying {
                    self.pause()
                } else if self.currentFile != nil {
                    self.resume()
                }
            }
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.canPlayNext(from: self.allFiles) {
                    self.playNextFile(from: self.allFiles)
                }
            }
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.canPlayPrevious(from: self.allFiles) {
                    self.playPreviousFile(from: self.allFiles)
                }
            }
            return .success
        }
    }
    
    private func updateRemoteCommandCenter() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.nextTrackCommand.isEnabled = self.canPlayNext(from: self.allFiles)
            commandCenter.previousTrackCommand.isEnabled = self.canPlayPrevious(from: self.allFiles)
            commandCenter.playCommand.isEnabled = self.currentFile != nil
            commandCenter.pauseCommand.isEnabled = self.isPlaying
            commandCenter.togglePlayPauseCommand.isEnabled = self.currentFile != nil
        }
    }
    
    private func updateNowPlayingInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var nowPlayingInfo = [String: Any]()
            
            // Update now playing info whenever there's a current file (playing or paused)
            if let file = self.currentFile {
                nowPlayingInfo[MPMediaItemPropertyTitle] = file.name
                nowPlayingInfo[MPMediaItemPropertyArtist] = "yyReader"
                
                // Show a preview of the content
                let preview = String(file.content.prefix(100))
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = preview.isEmpty ? "Text File" : preview
                
                // Set playback state
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                // Don't set elapsed playback time - let iOS handle it naturally
                // Setting it to 0.0 causes it to keep counting
            }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo.isEmpty ? nil : nowPlayingInfo
        }
    }
    
    func updateNowPlayingInfoForBackground() {
        // Update now playing info when going to background
        updateNowPlayingInfo()
    }
    
    func cleanup() {
        // Clear now playing info and stop playback when app terminates
        stop()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func loadAvailableVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        englishVoices = allVoices.filter { voice in
            voice.language.hasPrefix("en")
        }.sorted { $0.name < $1.name }
        
        simplifiedChineseVoices = allVoices.filter { voice in
            voice.language == "zh-CN" || voice.language.hasPrefix("zh-Hans") || voice.language == "zh-TW" || voice.language == "zh-HK" || voice.language.hasPrefix("zh-Hant")
        }.sorted { $0.name < $1.name }
        
        // Set defaults if none selected
        if selectedEnglishVoice == nil {
            selectedEnglishVoice = englishVoices.first ?? AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en") })
        }
        if selectedSimplifiedChineseVoice == nil {
            selectedSimplifiedChineseVoice = simplifiedChineseVoices.first ?? AVSpeechSynthesisVoice(language: "zh-CN") ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "zh-CN" || $0.language.hasPrefix("zh-Hans") || $0.language == "zh-TW" || $0.language == "zh-HK" || $0.language.hasPrefix("zh-Hant") })
        }
    }
    
    private func loadSavedVoicePreferences() {
        let defaults = UserDefaults.standard
        
        if let englishVoiceId = defaults.string(forKey: "selectedEnglishVoice"),
           let voice = AVSpeechSynthesisVoice(identifier: englishVoiceId) {
            selectedEnglishVoice = voice
        }
        
        if let simplifiedChineseVoiceId = defaults.string(forKey: "selectedSimplifiedChineseVoice"),
           let voice = AVSpeechSynthesisVoice(identifier: simplifiedChineseVoiceId) {
            selectedSimplifiedChineseVoice = voice
        }
    }
    
    func selectEnglishVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedEnglishVoice = voice
        UserDefaults.standard.set(voice.identifier, forKey: "selectedEnglishVoice")
    }
    
    func selectSimplifiedChineseVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedSimplifiedChineseVoice = voice
        UserDefaults.standard.set(voice.identifier, forKey: "selectedSimplifiedChineseVoice")
    }
    
    func playFile(_ file: TextFile, from files: [TextFile]) {
        allFiles = files
        currentFile = file
        currentFileIndex = files.firstIndex(where: { $0.id == file.id }) ?? 0
        currentSentenceIndex = 0
        
        updateNowPlayingInfo()
        updateRemoteCommandCenter()
        speakText(file.content)
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
        updateNowPlayingInfo()
        updateRemoteCommandCenter()
    }
    
    func resume() {
        synthesizer.continueSpeaking()
        isPlaying = true
        updateNowPlayingInfo()
        updateRemoteCommandCenter()
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentFile = nil
        currentUtterance = nil
        currentSpeakingRange = nil
        fullText = ""
        sentenceOffsets = []
        // Clear now playing info when stopping
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // Disable remote commands
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
    }
    
    func playNextFile(from files: [TextFile]) {
        guard !files.isEmpty else { return }
        
        let currentIndex = files.firstIndex(where: { $0.id == currentFile?.id }) ?? -1
        let nextIndex = currentIndex + 1
        
        if nextIndex < files.count {
            let nextFile = files[nextIndex]
            // Stop current playback but keep currentFile temporarily to avoid clearing now playing info
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
            // Update to new file immediately
            allFiles = files
            currentFile = nextFile
            currentFileIndex = nextIndex
            currentSentenceIndex = 0
            currentUtterance = nil
            
            // Update now playing info and commands immediately
            updateNowPlayingInfo()
            updateRemoteCommandCenter()
            // Start playing new file
            speakText(nextFile.content)
        }
    }
    
    func playPreviousFile(from files: [TextFile]) {
        guard !files.isEmpty else { return }
        
        let currentIndex = files.firstIndex(where: { $0.id == currentFile?.id }) ?? 0
        let previousIndex = currentIndex - 1
        
        if previousIndex >= 0 {
            let previousFile = files[previousIndex]
            // Stop current playback but keep currentFile temporarily to avoid clearing now playing info
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
            // Update to new file immediately
            allFiles = files
            currentFile = previousFile
            currentFileIndex = previousIndex
            currentSentenceIndex = 0
            currentUtterance = nil
            
            // Update now playing info and commands immediately
            updateNowPlayingInfo()
            updateRemoteCommandCenter()
            // Start playing new file
            speakText(previousFile.content)
        }
    }
    
    func canPlayNext(from files: [TextFile]) -> Bool {
        guard let currentFile = currentFile else { return false }
        let currentIndex = files.firstIndex(where: { $0.id == currentFile.id }) ?? -1
        return currentIndex + 1 < files.count
    }
    
    func canPlayPrevious(from files: [TextFile]) -> Bool {
        guard let currentFile = currentFile else { return false }
        let currentIndex = files.firstIndex(where: { $0.id == currentFile.id }) ?? 0
        return currentIndex - 1 >= 0
    }
    
    private func speakText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Store full text for range tracking
        fullText = text
        currentSpeakingRange = nil
        
        // Detect language and select appropriate voice
        let detectedLanguage = detectLanguage(text)
        let voice = getVoiceForLanguage(detectedLanguage)
        
        // Split text into sentences for better control
        let sentences = splitIntoSentences(text)
        
        guard !sentences.isEmpty else { return }
        
        // Calculate sentence offsets in the full text
        sentenceOffsets = calculateSentenceOffsets(text: text, sentences: sentences)
        
        // Speak the first sentence
        speakSentence(sentences[0], voice: voice, sentenceIndex: 0)
        currentSentenceIndex = 0
        
        // Store remaining sentences for continuation
        if sentences.count > 1 {
            // Continue with remaining sentences after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.speakRemainingSentences(Array(sentences[1...]), voice: voice, startIndex: 1)
            }
        }
    }
    
    private func calculateSentenceOffsets(text: String, sentences: [String]) -> [Int] {
        var offsets: [Int] = [0]
        var currentOffset = 0
        
        for sentence in sentences {
            // Find the sentence in the text starting from currentOffset
            if let range = text.range(of: sentence.trimmingCharacters(in: .whitespacesAndNewlines), range: text.index(text.startIndex, offsetBy: currentOffset)..<text.endIndex) {
                currentOffset = text.distance(from: text.startIndex, to: range.lowerBound)
                offsets.append(currentOffset)
            } else {
                // Fallback: approximate offset
                offsets.append(currentOffset)
                currentOffset += sentence.count
            }
        }
        
        return offsets
    }
    
    private func speakSentence(_ sentence: String, voice: AVSpeechSynthesisVoice, sentenceIndex: Int) {
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let utterance = AVSpeechUtterance(string: trimmedSentence)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Store sentence index in utterance's speechString for tracking
        // We'll use a custom approach to track which sentence this is
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    private func speakRemainingSentences(_ sentences: [String], voice: AVSpeechSynthesisVoice, startIndex: Int) {
        for (index, sentence) in sentences.enumerated() {
            let utterance = AVSpeechUtterance(string: sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            utterance.voice = voice
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            
            synthesizer.speak(utterance)
        }
    }
    
    private func detectLanguage(_ text: String) -> String {
        // Simple language detection based on character patterns
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "en" }
        
        // Check for Chinese characters
        let chinesePattern = "[\\u4e00-\\u9fff]"
        let chineseRegex = try? NSRegularExpression(pattern: chinesePattern, options: [])
        let chineseMatches = chineseRegex?.numberOfMatches(in: trimmedText, options: [], range: NSRange(location: 0, length: trimmedText.utf16.count)) ?? 0
        
        if chineseMatches > 0 {
            // Use Simplified Chinese for all Chinese text
            return "zh-CN"
        }
        
        // Default to English
        return "en"
    }
    
    private func getVoiceForLanguage(_ language: String) -> AVSpeechSynthesisVoice {
        switch language {
        case "zh-CN", "zh-TW", "zh-HK":
            // Use Simplified Chinese voice for all Chinese variants
            return selectedSimplifiedChineseVoice ?? simplifiedChineseVoices.first ?? AVSpeechSynthesisVoice(language: "zh-CN") ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "zh-CN" || $0.language.hasPrefix("zh-Hans") || $0.language == "zh-TW" || $0.language == "zh-HK" || $0.language.hasPrefix("zh-Hant") }) ?? AVSpeechSynthesisVoice.speechVoices().first!
        default:
            return selectedEnglishVoice ?? englishVoices.first ?? AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en") }) ?? AVSpeechSynthesisVoice.speechVoices().first!
        }
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        // Split by common sentence delimiters
        let delimiters = CharacterSet(charactersIn: ".!?。！？\n")
        let sentences = text.components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return sentences.isEmpty ? [text] : sentences
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Calculate the actual range in the full text
        // The characterRange is relative to the utterance's string
        let utteranceString = utterance.speechString
        let utteranceRange = (fullText as NSString).range(of: utteranceString)
        
        if utteranceRange.location != NSNotFound {
            // Calculate the actual range in the full text
            let actualLocation = utteranceRange.location + characterRange.location
            let actualLength = min(characterRange.length, (fullText as NSString).length - actualLocation)
            let actualRange = NSRange(location: actualLocation, length: max(0, actualLength))
            
            DispatchQueue.main.async {
                self.currentSpeakingRange = actualRange
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Clear speaking range when utterance finishes
        DispatchQueue.main.async {
            self.currentSpeakingRange = nil
        }
        
        // Check if this was the last utterance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !synthesizer.isSpeaking {
                self.isPlaying = false
                self.currentSpeakingRange = nil
                
                // Auto-play next file
                if let currentFile = self.currentFile {
                    let currentIndex = self.allFiles.firstIndex(where: { $0.id == currentFile.id }) ?? -1
                    let nextIndex = currentIndex + 1
                    
                    if nextIndex < self.allFiles.count {
                        let nextFile = self.allFiles[nextIndex]
                        self.playFile(nextFile, from: self.allFiles)
                    } else {
                        // Reached the end - clear now playing info
                        self.currentFile = nil
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                        self.updateRemoteCommandCenter()
                    }
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        currentSpeakingRange = nil
        // Clear now playing info when cancelled
        if currentFile == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
}

