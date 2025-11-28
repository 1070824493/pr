//
//  DismissingKeyboardOnSwipe.swift
//  OverseasSwiftExtensions
//

import SwiftUI
import UIKit
import Foundation

// See https://stackoverflow.com/questions/56491386/how-to-hide-keyboard-when-using-swiftui
struct DismissingKeyboardOnSwipe: ViewModifier {
    func body(content: Content) -> some View {
        return content.gesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged(endEditing)
    }

    private func endEditing(_ gesture: DragGesture.Value) {
        UIApplication.shared.endEditing()
    }
    
}
