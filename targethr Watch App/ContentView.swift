//
//  ContentView.swift
//  TacHR Watch App
//
//  Created by Eric Mentele on 3/9/25.
//

import SwiftUI
import WatchKit


struct ContentView: View {
    @StateObject private var heartRateManager = HeartRateManager()
    @State private var lastHapticTime = Date()
    private let hapticCooldown: TimeInterval = 0.5 // Adjusted for breathing exercise
    
    var body: some View {
        VStack {
            if heartRateManager.isAuthorized {
                Text("\(Int(heartRateManager.currentHeartRate))")
                    .font(.system(size: 54))
                    .fontWeight(.bold)
                    .onChange(of: heartRateManager.currentHeartRate) { newValue in
                        checkHeartRateAndProvideHaptic()
                    }
                
                Text("BPM")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                if heartRateManager.isBreathingExerciseActive {
                    Text(heartRateManager.breathingState.message)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .animation(.easeInOut, value: heartRateManager.breathingState)
                        .transition(.opacity)
                }
                
                Button(action: {
                    heartRateManager.toggleMonitoring()
                }) {
                    Text(heartRateManager.isMonitoring ? "Stop" : "Start")
                        .foregroundColor(heartRateManager.isMonitoring ? .red : .green)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Please authorize\nHealth access")
                    .multilineTextAlignment(.center)
                    .font(.headline)
            }
        }
    }
    
    private func checkHeartRateAndProvideHaptic() {
        let now = Date()
        if heartRateManager.isBreathingExerciseActive &&
            now.timeIntervalSince(lastHapticTime) >= hapticCooldown {
            // Calculate how many taps we should have played since the last tap
            let tapsPerSecond = heartRateManager.breathingState.tapsPerSecond
            if tapsPerSecond > 0 {
                WKInterfaceDevice.current().play(.notification)
                lastHapticTime = now
            }
        }
    }
}

#Preview {
    ContentView()
}
