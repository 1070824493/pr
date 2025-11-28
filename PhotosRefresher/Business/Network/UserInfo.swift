//
//  UserData.swift

//
//



struct UserData: CodableWithDefault, Equatable {
    static var defaultValue: UserData {
        return UserData(vipStatus: 0, vipSubStatus: 0, registerTime: 0)
    }
    
    let vipStatus: Int
//    let vipExpireAt: Int
    let vipSubStatus: Int
    let registerTime: Int
}
