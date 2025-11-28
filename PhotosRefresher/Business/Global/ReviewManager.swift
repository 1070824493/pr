//
//  AppReviewManager.swift

//

//

class AppReviewManager {
    
    public static let shared = AppReviewManager()
    
    public var hadReview: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    private init() {
        
    }
    
    public func reviewIfNeeded() {
        Task {
//            if UserManager.shared.isVip() {
//                return
//            }
            
            if hadReview == 1 {
                return
            }
            
//            let msgCount = await PersistenceController.shared.fetchRecordCount(entityName: "LLMessage")
//            if msgCount < 1 {
//                return
//            }
            
            await MainActor.run {
                let called = requestAppReview()
                if called {
                    hadReview = 1
                }
            }
        }
    }
}
