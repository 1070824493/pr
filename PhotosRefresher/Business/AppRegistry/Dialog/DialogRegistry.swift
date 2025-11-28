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
            ? BottomSheetView(destination: bottomSheet)
                .withEnvironments()
            : nil
        }
    }
    
    func withModal(_ modal: Binding<AppModalDestination?>) -> some View {
        self.overlay {
            modal.wrappedValue != nil
            ? ModalView(destination: modal)
                .withEnvironments()
            : nil
        }
    }
    
}
