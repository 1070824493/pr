//
//  GuideViewModel.swift
//  SwiftUITestProject
//
//

import SwiftUI
import AppTrackingTransparency

struct GuideSceneModel {

    let index: Int
    let title: String
    let subTitle: String
    let imageName: String
    let btnTitle: String
    let backgroundColor: Color
}

enum GuideStepItem: Identifiable {
    var id: UUID {
        return UUID()
    }
    case guidePage     // 功能引导页
    case idfaPage
//    case subscriptionPage
    
    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .guidePage:
            PRGuideWelcomePage()
        case .idfaPage:
            PRIDFAPageView()
        }
    }
    
}

class PRGuideViewModel: ObservableObject {
    
    @Published var currentStep = 0
    
    @Published var guideFinished = false
    
    init() {
        var tempArr: [GuideStepItem] = []
        
        tempArr.append(.guidePage)
        
        let idfa = ATTrackingManager.trackingAuthorizationStatus
        if idfa == ATTrackingManager.AuthorizationStatus.notDetermined {
            tempArr.append(.idfaPage)
        }
        
//        if !UserManager.shared.isVip() {
//            tempArr.append(.subscriptionPage)
//        }
        stepList = tempArr
//        StatisticsManager.log(name: "JHO_001", params: ["subscription": 1])
    }
    
    var stepList: [GuideStepItem] = []
    
    var currentView: some View {
        return stepList[currentStep].makeContentView()
    }
    
    func next() {
        let addStep = currentStep + 1
        if addStep > stepList.count - 1 {
            finish()
        } else {
            currentStep = min(addStep, stepList.count - 1)
        }
//        StatisticsManager.log(name: "JHO_002", params: ["subscription": 1])
    }
    
    func finish() {
        guideFinished = true
    }
    
}
