//
//  yyReaderApp.swift
//  yyReader
//
//  Created on 2024
//

import SwiftUI

@main
struct yyReaderApp: App {
    @StateObject private var fileManager = FileManagerViewModel()
    @StateObject private var ttsManager = TTSManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileManager)
                .environmentObject(ttsManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Clear now playing info when app is terminated
                    ttsManager.cleanup()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Update now playing info when going to background
                    ttsManager.updateNowPlayingInfoForBackground()
                }
        }
    }
}

