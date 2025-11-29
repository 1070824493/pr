//
//  UIState.swift

//
//

import SwiftUI

class PRUIState: ObservableObject {
    public static let shared = PRUIState()
    
    @Published var selectedTab = Tab.clean
    @Published var hideStatusBar: Bool = false
    
    @Published var bottomSheetDestination: AppBottomSheetDestination?
    @Published var modalDestination: AppModalDestination?
    @Published var fullScreenCoverDestination: AppFullScreenCoverDestination?
    
    var homefooterHeight: CGFloat = 60.0.fit
    
    enum Tab: Int, Hashable, Identifiable {
        
        case clean
        case slide
        
        var id: Int {
            rawValue
        }
        
        var title: String {
            switch self {
            case .clean:
                "Clean"
            case .slide:
                "Slide"
            }
        }
        
        var unselectedIcon: String {
            switch self {
            case .clean:
                "icon_unselect_home"
            case .slide:
                "icon_unselect_setting"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .clean:
                "icon_selected_home"
            case .slide:
                "icon_selected_setting"
            }
        }
        
        @ViewBuilder
        func makeContentView(selectedTab: Binding<Tab>) -> some View {
            switch self {
            case .clean:
                PRCategoryHomePage()
            case .slide:
                PRSlidePage()
            }
        }
        
    }
    
}
