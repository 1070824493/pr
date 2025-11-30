//
//  DialogRegistry.swift

//
//

import SwiftUI
import Combine

extension View {
    
    func withBottomSheet(_ bottomSheet: Binding<AppBottomSheetDestination?>) -> some View {
        self.overlay {
            bottomSheet.wrappedValue != nil
            ? PRBottomSheetView(destination: bottomSheet)
                .provideEnivironmentObject()
            : nil
        }
    }
    
    func withModal(_ modal: Binding<AppModalDestination?>) -> some View {
        self.overlay {
            modal.wrappedValue != nil
            ? PRModalView(destination: modal)
                .provideEnivironmentObject()
            : nil
        }
    }
    
}
