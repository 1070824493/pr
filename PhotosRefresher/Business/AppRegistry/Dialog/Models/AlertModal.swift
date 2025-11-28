//
//  CommonAlert.swift

//
//

public struct AlertModalModel {
    enum ActionType: Int {
        case first = 0
        case second
    }
    
    let imgName: String
    let title: String
    let desc: String
    let firstBtnTitle: String
    let secondBtnTitle: String
    
    let actionHandler: ((ActionType) -> Void)?
    var onDismiss: (() -> Void)? = nil
}
