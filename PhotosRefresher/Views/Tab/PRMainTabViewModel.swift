//
//  HomeViewModel.swift

//
//

import Foundation

public class PRMainTabViewModel: ObservableObject {
    
    @Published var availableTabs: [PRUIState.Tab] = [
        .slide,
        .clean
    ]
    
    var hadShowSubscriptionView: Bool = false
    
}
