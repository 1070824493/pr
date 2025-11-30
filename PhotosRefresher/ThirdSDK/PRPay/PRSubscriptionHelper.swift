//
//  PRSubscriptionHelper.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import StoreKit

class PRSubscriptionHelper {
    
    static let instance = PRSubscriptionHelper()
    
    private var cachedProducts: [String: Product] = [:]
    
    private init() {}
    
    /// 获取指定的订阅产品
    func fetchProduct(by productID: String) async throws -> Product? {
        if let product = cachedProducts[productID] {
            return product
        }
        
        let products = try await Product.products(for: [productID])
        if let firstProduct = products.first {
            cachedProducts[productID] = firstProduct
            return firstProduct
        }
        return nil
    }
    
    /// 购买指定的订阅产品
    func purchaseProduct(
        productID: String,
        accountToken: UUID,
        beforePurchase: ((Product) -> Void)? = nil
    ) async throws -> Product.PurchaseResult {
        guard let product = try await fetchProduct(by: productID) else {
            throw NSError(domain: "SubscriptionManager", code: -2000, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
        }
        
        if let beforePurchase = beforePurchase {
            DispatchQueue.main.async {
                beforePurchase(product)
            }
        }
        
        let purchaseOptions: Set<Product.PurchaseOption> = [.appAccountToken(accountToken)]
        let result = try await product.purchase(options: purchaseOptions)
        return result
    }
    
    /// 同步交易记录
    func syncTransactions() async {
        do {
            try await AppStore.sync()
        } catch {
            print("Error syncing transactions: \(error)")
        }
    }
    
    /// 查询未完成的交易
    func fetchPendingTransactions() async -> [(transaction: Transaction, jws: String)] {
        var pendingTransactions = [(transaction: Transaction, jws: String)]()
        do {
            for await transactionResult in Transaction.unfinished {
                switch transactionResult {
                case .verified(let transaction):
                    pendingTransactions.append((transaction: transaction, jws: transactionResult.jwsRepresentation))
                case .unverified(_, let error):
                    print("Error fetching pending transaction: \(error)")
                }
            }
        }
        return pendingTransactions
    }
    
    /// 检查是否允许支付
    func isPaymentAllowed() -> Bool {
        return AppStore.canMakePayments
    }
    
}