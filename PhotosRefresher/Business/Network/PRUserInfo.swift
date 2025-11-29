//
//  UserData.swift

//
//



struct PRUserData: CodableWithDefault, Equatable {
    static var defaultValue: PRUserData {
        return PRUserData(vipStatus: 0, vipSubStatus: 0, registerTime: 0)
    }
    
    let vipStatus: Int
//    let vipExpireAt: Int
    let vipSubStatus: Int
    let registerTime: Int
}
