//
//  ViewDurationTrackerModifier.swift
//  Pods
//
//  统计View的曝光时长
//

//

import SwiftUI

struct ViewDurationTrackerModifier: ViewModifier {
    
    let onDurationRecorded: (TimeInterval) -> Void
    
    @Environment(\.scenePhase) private var scenePhase
    
    private class TrackerState {
        var startTime: Date?
    }
    
    @State private var state = TrackerState()
    
    func body(content: Content) -> some View {
        content
            .onAppear(perform: startTracking)
            .onDisappear(perform: endTracking)
            .onChange(of: scenePhase, perform: handleTrackerSceneChanged)
    }
    
    private func startTracking() {
        state.startTime = Date()
    }
    
    private func endTracking() {
        guard let start = state.startTime else { return }
        
        let totalDuration = calculateTotalDuration(start: start)
        onDurationRecorded(totalDuration)
        cleanup()
    }
    
    private func calculateTotalDuration(start: Date) -> TimeInterval {
        return Date().timeIntervalSince(start)
    }
    
    private func cleanup() {
        state.startTime = nil
    }
    
    private func handleTrackerSceneChanged(newPhase: ScenePhase) {
        if newPhase == .inactive {
            endTracking()
        } else if newPhase == .active {
            startTracking()
        }
    }
    
}

