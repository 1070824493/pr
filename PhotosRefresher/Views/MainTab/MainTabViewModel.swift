//
//  HomeViewModel.swift

//
//

import Foundation

public class MainTabViewModel: ObservableObject {
    
    @Published var availableTabs: [UIState.Tab] = [
        .slide,
        .clean
    ]
    
    var hadShowSubscriptionView: Bool = false
    
}
