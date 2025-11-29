//
//  PRSubscriptionHelper.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import StoreKit

class PRSubscriptionHelper {
    
    static let shared = PRSubscriptionHelper()
    
    private var productCache: [String: Product] = [:]
    
    private init() {}
    
    func PRFetchProduct(with productID: String) async throws -> Product? {
        if let cachedProduct = productCache[productID] {
            return cachedProduct
        }
        
        let products = try await Product.products(for: [productID])
        if let product = products.first {
            productCache[productID] = product
            return product
        }
        return nil
    }
    
    func PRTransactionProduct(
        with productID: String,
        appAccountToken: UUID,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async throws -> Product.PurchaseResult {
        guard let product = try await PRFetchProduct(with: productID) else {
            throw NSError(domain: "PayManager", code: -2000, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
        }
        
        if let onBeforePurchase = onBeforePurchase {
            DispatchQueue.main.async {
                onBeforePurchase(product)
            }
        }
        
        let purchaseOptions: Set<Product.PurchaseOption> = [.appAccountToken(appAccountToken)]
        let purchaseResult = try await product.purchase(options: purchaseOptions)
        return purchaseResult
    }
    
    func PRSyncTransaction() async {
        do {
            try await AppStore.sync()
        } catch {
            print("syncPurchases error = \(error)")
        }
    }
    
    func PRQueryUnfinishedTransaction() async -> [(transaction: Transaction, jwsRepresentation: String)] {
        var list = [(transaction: Transaction, jwsRepresentation: String)]()
        do {
            for await result in Transaction.unfinished {
                switch result {
                case .verified(let transaction):
                    list.append((transaction: transaction, jwsRepresentation: result.jwsRepresentation))
                case .unverified(_, let error):
                    print("queryUnfinishedPurchase error = \(error)")
                }
            }
        }
        return list
    }
    
    func canMakePayments() -> Bool {
        return AppStore.canMakePayments
    }
    
}

public struct PRTransactionIntentCallback {
    private var storage: Any?
    
    @available(iOS 16.4, *)
    var value: ((PurchaseIntent) -> Void)? {
        get { storage as? ((PurchaseIntent) -> Void) }
        set { storage = newValue }
    }
}

