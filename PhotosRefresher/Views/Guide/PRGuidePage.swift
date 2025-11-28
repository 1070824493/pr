//
//  GuideView.swift
//  SwiftUITestProject
//
//  Created by R on 2025/4/8.
//

import SwiftUI


struct PRGuidePage: View {
    
    @StateObject var viewModel = PRGuideViewModel()
    
    var doneHandler: (() -> Void)? = nil
    
    var body: some View {
        guideView
            .onReceiveChange(viewModel.$guideFinished, perform: handleGuideFinished)
    }
    
    private var guideView: some View {
        let isFirst = viewModel.currentStep == 0
        let isLast = viewModel.currentStep == viewModel.stepList.count - 1
        return viewModel.currentView
            .id(viewModel.currentStep)
            .background(.white)
            .environmentObject(viewModel)
            .transition(.asymmetric(
                insertion: isFirst
                ? .identity
                : .move(edge: .trailing),
                removal: isLast
                    ? .opacity
                    : .move(edge: .leading))
            )
            .animation(.easeInOut, value: viewModel.currentStep)
    }
    
    private func handleGuideFinished(oldValue: Bool?, newValue: Bool) {
        if newValue {
            doneHandler?()
        }
    }
    
}

#Preview {
    PRGuidePage()
}
