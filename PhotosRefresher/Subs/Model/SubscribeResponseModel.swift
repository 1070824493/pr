//
//  SubscribeResponseModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

struct SubscribeResponseModel: Decodable, DefaultInitializable {
    static var defaultValue: SubscribeResponseModel {
        .init(
            packageList: [],
            activityList: [],
            isAudit: false,
            closeDelay: 0,
            retainTime: 0
        )
    }
    
    let packageList: [SubscriptionPackageModel]
    let activityList: [ActivityPackage]
    var isAudit: Bool = false
    
    var closeDelay: Int? = 0
    var retainTime: Int? = 0
}

struct ProductInfoModel: Decodable, DefaultInitializable {
    static var defaultValue: ProductInfoModel {
        .init(skuId: 0)
    }
    let skuId: Int64
}



struct ActivityPackage: Decodable, DefaultInitializable, Equatable {
    static var defaultValue: ActivityPackage {
        .init(type: 0, packageList: [])
    }
    
    let type: Int
    let packageList: [SubscriptionPackageModel]
}

struct SubscriptionPackageModel: Decodable, Identifiable, DefaultInitializable, Equatable {
    static var defaultValue: SubscriptionPackageModel {
        .init(
            skuId: 0,
            priceSale: 0,
            priceFirst: 0,
            duration: 0,
            recommendSku: false,
            beOffered: 0,
            freeDays: 0
        )
    }
    
    let skuId: Int
    let priceSale: Float   // x1000
    let priceFirst: Float  // x1000
    let duration: Int      // 7 / 30 / 365
    let recommendSku: Bool
    let beOffered: Int     // 1=首期优惠
    let freeDays: Int      // >0 免费试用天数
    
    var id: Int { skuId }
}

// 一些便捷属性（可选）
extension SubscriptionPackageModel {
    var priceSaleReal: Double  { Double(priceSale)  / 100.0 }
    var priceFirstShow: Double {
        if isFirstOffer {
            return priceFirstReal
        }else{
            return priceSaleReal
        }
    }
    var priceFirstReal: Double { Double(priceFirst) / 100.0 }
    
    
    var unitString: String {
        switch duration { case 365: return "year"; case 30: return "month"; default: return "week" }
    }
    var isFreeTrial: Bool { freeDays > 0 }
    var isFirstOffer: Bool { beOffered == 0 }
    
    var expireComponents: DateComponents {
        var components = DateComponents(day: 7)
        if duration == 30 {
            components = DateComponents(month: 1)
        }
        if duration == 365 { components = DateComponents(year: 1) }
        return components
    }
}

