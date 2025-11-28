//
//  SubscriptionPackageModel.swift

//
//



struct ProductInfoDTO: Decodable, DefaultInitializable {
    static var defaultValue: ProductInfoDTO {
        .init(skuId: 0)
    }
    let skuId: Int64
}

struct SubscriptionPackageResponse: Decodable, DefaultInitializable {
    static var defaultValue: SubscriptionPackageResponse {
        .init(
            packageList: [],
            activityList: [],
            isAudit: false,
            closeDelay: 0,
            retainTime: 0
        )
    }

    let packageList: [SubscriptionPackage]
    let activityList: [ActivityPackage]
    var isAudit: Bool = false

    var closeDelay: Int? = 0
    var retainTime: Int? = 0
}

struct ActivityPackage: Decodable, DefaultInitializable, Equatable {
    static var defaultValue: ActivityPackage {
        .init(type: 0, packageList: [])
    }

    let type: Int
    let packageList: [SubscriptionPackage]
}

struct SubscriptionPackage: Decodable, Identifiable, DefaultInitializable, Equatable {
    static var defaultValue: SubscriptionPackage {
        .init(
            skuId: 0,
            priceSale: 0,
            priceFirst: 0,
            price: 0,
            duration: 0,
            recommendSku: false,
            beOffered: 0,
            freeDays: 0
        )
    }

    let skuId: Int
    let priceSale: Float   // x1000
    let priceFirst: Float  // x1000
    let price: Float       // x1000（目前用不到）
    let duration: Int      // 7 / 30 / 365
    let recommendSku: Bool
    let beOffered: Int     // 1=首期优惠
    let freeDays: Int      // >0 免费试用天数

    var id: Int { skuId }
}

// 一些便捷属性（可选）
extension SubscriptionPackage {
    var priceSaleReal: Double  { Double(priceSale)  / 100.0 }
    var priceFirstReal: Double { Double(priceFirst) / 100.0 }
    var priceReal: Double      { Double(price)      / 100.0 }

    var unitString: String {
        switch duration { case 365: return "year"; case 30: return "month"; default: return "week" }
    }
    var isFreeTrial: Bool { freeDays > 0 }
    var isFirstOffer: Bool { beOffered == 0 }
}
