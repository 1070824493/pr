//
//  HomeViewModel.swift

//
//

import Foundation

public class PRTabViewModel: ObservableObject {
    
    @Published var tabs: [PRUIState.Tab] = [
        .slide,
        .clean
    ]
    
}
