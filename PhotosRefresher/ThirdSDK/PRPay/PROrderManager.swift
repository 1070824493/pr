//
//  PROrderManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import StoreKit

public enum PRSubscriptionType {
    case subscription
    case consumables
}

public struct PRSubscriptionError: Error {
    public let code: PRSubscriptionError.ErrorCode
    public let underlyingError: Error?
    
    public enum ErrorCode: Int {
        case notInit = 1
        case alreadyInProgress
        case cannotMakePayments
        case createOrderFailed
        case userCancelled
        case purchasePending
        case transactionNotVerified
        case transactionAlreadyProcessed
        case reportOrderFailed
        case reportOrderFailedAfterRetry
        case networkError
        case unknown
        case purchaseFailed
        case isPurchased
    }
    
    public var errorCode: Int {
        code.rawValue
    }
    
    public var errorMsg: String {
        guard let underlyingError = underlyingError else {
            return ""
        }
        
        var msg = "underlyingCode=\(underlyingError)&underlyingMsg="
        switch underlyingError {
        case let purchaseError as Product.PurchaseError:
            msg += "failureReason=\(purchaseError.failureReason ?? "");errorDescription=\(purchaseError.errorDescription ?? "")"
        case let purchaseError as StoreKitError:
            msg += "failureReason=\(purchaseError.failureReason ?? "");errorDescription=\(purchaseError.errorDescription ?? "")"
            switch purchaseError {
            case .networkError(let urlError):
                msg += ";urlErrorCode=\(urlError.code);urlErrorCode2=\(urlError.errorCode);urlErrorMsg=\(urlError.localizedDescription)"
            case .systemError(let error):
                msg += ";systemErrorMsg=\(error.localizedDescription)"
            default:
                print("")
            }
        default:
            msg += underlyingError.localizedDescription
        }
        
        return msg
    }
    
}

public enum PaymentResult {
    case success(Transaction)
    case failure(PRSubscriptionError)
}

public class PROrderManager {
    public static let shared = PROrderManager()
    
    private let payHelper = PRSubscriptionHelper.shared
    private var initialized = false
    private var isPurchasing = false
    private let transactionManager = PRPaymentProcessManager()
    private var transactionCallback: ((PaymentResult) -> Void)?
    
    private var createSubscriptionOrderApi: String = ""     // 订阅下单
    private var createConsumablesOrderApi: String = ""      // 单包下单
    private var reportOrderApi: String = ""
    private var traceOrderApi: String = ""
    private var createOrderBusinessParams: [String: Any]? = nil
    private var reportOrderBusinessParams: [String: Any]? = nil
    
    private init() {}
    
    // 初始化方法，注入业务逻辑
    public func initialize(
        createSubscriptionOrderApi: String,
        createConsumablesOrderApi: String = "",
        reportOrderApi: String,
        traceOrderApi: String,
        createOrderBusinessParams: [String: Any]? = nil,
        reportOrderBusinessParams: [String: Any]? = nil
    ) {
        self.createSubscriptionOrderApi = createSubscriptionOrderApi
        self.createConsumablesOrderApi = createConsumablesOrderApi
        self.reportOrderApi = reportOrderApi
        self.traceOrderApi = traceOrderApi
        self.createOrderBusinessParams = createOrderBusinessParams
        self.reportOrderBusinessParams = reportOrderBusinessParams
        
        initialized = true
    }
    
    // 注册全局回调
    public func registerCallback(_ callback: @escaping (PaymentResult) -> Void) {
        transactionCallback = callback
    }
    
    public func PRpayConsumables(
        skuId: Int,
        paySource: Int,
        traceId: String,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PaymentResult {
        let result = await PRpaySubscriptionInternal(purchaseType: .consumables, skuId: skuId, paySource: paySource, traceId: traceId, ignorePurchased: true, extParams: extParams, onBeforePurchase: onBeforePurchase)
        PRTracePayResult(traceId: traceId, result: result)
        return result
    }
    
    public func PRpaySubscription(
        skuId: Int,
        paySource: Int,
        traceId: String,
        ignorePurchased: Bool = false,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PaymentResult {
        let result = await PRpaySubscriptionInternal(purchaseType: .subscription, skuId: skuId, paySource: paySource, traceId: traceId, ignorePurchased: ignorePurchased, extParams: extParams, onBeforePurchase: onBeforePurchase)
        PRTracePayResult(traceId: traceId, result: result)
        return result
    }
    
    private func PRpaySubscriptionInternal(
        purchaseType: PRSubscriptionType,
        skuId: Int,
        paySource: Int,
        traceId: String,
        ignorePurchased: Bool = false,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PaymentResult {
        guard initialized else {
            return .failure(PRSubscriptionError(code: .notInit, underlyingError: nil))
        }
        
        guard !isPurchasing else {
            return .failure(PRSubscriptionError(code: .alreadyInProgress, underlyingError: nil))
        }
        
        guard payHelper.canMakePayments() else {
            return .failure(PRSubscriptionError(code: .cannotMakePayments, underlyingError: nil))
        }
        
        if !ignorePurchased {
            let isPurchased = await transactionManager.isPurchased()
            guard !isPurchased else {
                return .failure(PRSubscriptionError(code: .isPurchased, underlyingError: nil))
            }
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let orderResponse = try await PRFetchOrderId(purchaseType: purchaseType, skuId: skuId, paySource: paySource, traceId: traceId, extParams: extParams)
            let orderId = orderResponse.appAccountToken
            let productId = orderResponse.productId
            let purchaseResult = try await payHelper.PRTransactionProduct(with: productId, appAccountToken: UUID(uuidString: orderId)!) { product in
                let currencyCode = product.priceFormatStyle.currencyCode
                
                var logInfo = [String: Any]()
                if let logExt = extParams?["logParams"] as? [String: Any] {
                    logInfo.merge(logExt) { $1 }
                }
                logInfo["currencyCode"] = currencyCode
                logInfo["skuid"] = skuId
                logInfo["paySource"] = paySource
                
//                StatisticsManager.log(name: "J25_004", params: logInfo)
                
                onBeforePurchase?(product)
            }
            
            switch purchaseResult {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    let jwsRepresentation = verificationResult.jwsRepresentation
                    return await PRHandleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
                case .unverified(_, let error):
                    return .failure(PRSubscriptionError(code: .transactionNotVerified, underlyingError: error))
                }
            case .userCancelled:
                return .failure(PRSubscriptionError(code: .userCancelled, underlyingError: nil))
            case .pending:
                return .failure(PRSubscriptionError(code: .purchasePending, underlyingError: nil))
            @unknown default:
                return .failure(PRSubscriptionError(code: .unknown, underlyingError: nil))
            }
        } catch {
            if error is PRSubscriptionError {
                return .failure(error as! PRSubscriptionError)
            } else if error is Product.PurchaseError {
                return .failure(PRSubscriptionError(code: .purchaseFailed, underlyingError: error))
            } else if error is StoreKitError {
                return .failure(PRSubscriptionError(code: .purchaseFailed, underlyingError: error))
            } else {
                return .failure(PRSubscriptionError(code: .unknown, underlyingError: error))
            }
        }
    }
    
    private func PRFetchOrderId(purchaseType: PRSubscriptionType, skuId: Int, paySource: Int, traceId: String, extParams: [String: Any]? = nil) async throws -> PRSubmitSubscriptionOrderResponse {
        let inCreateOrderApi: String
        let payChannel: Int
        switch purchaseType {
        case .subscription:
            inCreateOrderApi = createSubscriptionOrderApi
            payChannel = 8
        case .consumables:
            inCreateOrderApi = createConsumablesOrderApi
            payChannel = 8
        }
        var inExtParams = "{}"
        if let extParams = extParams {
            inExtParams = PRConvertToJson(extParams)
        }
        let parameters = PRSubmitSubscriptionOrderRequest(
            skuId: skuId, payChannel: payChannel, paySource: paySource, traceId: traceId, ext: inExtParams
        )
        do {
            let response: PRCommonResponse<PRSubmitSubscriptionOrderResponse> = try await PRRequestHandlerManager.shared.PRrequest(url: inCreateOrderApi, method: .post, parameters: parameters)
            if response.errNo != 0 {
                let error = NSError(domain: "PurchaseManager", code: response.errNo, userInfo: [NSLocalizedDescriptionKey: response.errMsg])
                throw PRSubscriptionError(code: .createOrderFailed, underlyingError: error)
            }
            
            return response.data
        } catch {
            throw PRSubscriptionError(code: .createOrderFailed, underlyingError: error)
        }
    }
    
    private func PRHandleSuccessfulPayment(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async -> PaymentResult {
        let transactionId = String(transaction.id)
        let isProcessed = await transactionManager.isPaymentProcessed(transactionId)
        let isBeingProcessed = await transactionManager.isPaymentBeingProcessed(transactionId)
        if isProcessed || isBeingProcessed {
            return .failure(PRSubscriptionError(code: .transactionAlreadyProcessed, underlyingError: nil))
        }
        
        await transactionManager.recordPaymentAsProcessing(transactionId)
        
        var underlyingError: Error? = nil
        var reportSucceed = false
        
        let maxRetries = 2
        var retryCount = 0
        while retryCount <= maxRetries {
            do {
                reportSucceed = try await PRSendOrderToServer(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            } catch {
                underlyingError = error
            }
            
            if reportSucceed {
                await transaction.finish()
                await transactionManager.recordPaymentAsProcessed(transactionId)
                await transactionManager.removePaymentFromProcessing(transactionId)
                return .success(transaction)
            } else {
                retryCount += 1
                if (retryCount <= maxRetries) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        await transactionManager.removePaymentFromProcessing(transactionId)
        Task {
            await PRStartScheduledRetry(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
        }
        return .failure(PRSubscriptionError(code: .reportOrderFailed, underlyingError: underlyingError))
    }
    
    private func PRSendOrderToServer(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async throws -> Bool {
        let parameters = PRNotifySubscriptionOrderRequest(
            receipt: "",
            payload: jwsRepresentation,
            transId: String(transaction.id),
            traceId: traceId,
            orderId: orderId,
            originalTransId: String(transaction.originalID),
            ext: "{}"
        )
        let response: PRCommonResponse<PRNotifySubscriptionOrderResponse> = try await PRRequestHandlerManager.shared.PRrequest(url: reportOrderApi, method: .post, parameters: parameters)
        if response.errNo != 0 {
            let error = NSError(domain: "PurchaseManager", code: response.errNo, userInfo: [NSLocalizedDescriptionKey: "errNo=\(response.errNo)&errMsg=\(response.errMsg)"])
            throw error
        }
        
        let payStatus = response.data.payStatus
        if payStatus != 1 {
            let error = NSError(domain: "PurchaseManager", code: response.errNo, userInfo: [NSLocalizedDescriptionKey: "errMsg=\(response.errMsg)&payStatus=\(payStatus)"])
            throw error
        }
        
        return true
    }
    
    private func PRStartScheduledRetry(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async {
        var underlyingError: Error? = nil
        var reportSucceed = false
        
        var attempt = 0
        let maxAttempts = 5
        let transactionId = String(transaction.id)
        while attempt < maxAttempts {
            let delay = pow(2.0, Double(attempt))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                reportSucceed = try await PRSendOrderToServer(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            } catch {
                underlyingError = error
            }
            
            if reportSucceed {
                await transaction.finish()
                await self.transactionManager.recordPaymentAsProcessed(transactionId)
                await self.transactionManager.removePaymentFromProcessing(transactionId)
                self.transactionCallback?(.success(transaction))
                return
            }
            attempt += 1
        }
        
        // 处理在最大重试次数后仍未成功的场景，可以选择执行一些报警或其他业务逻辑
        self.transactionCallback?(.failure(PRSubscriptionError(code: .reportOrderFailedAfterRetry, underlyingError: underlyingError)))
    }
    
    // 监听交易状态更新
    public func PRListenForTransactionUpdates() {
        Task.detached {
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    let transactionId = String(transaction.id)
                    let isProcessed = await self.transactionManager.isPaymentProcessed(transactionId)
                    let isBeingProcessed = await self.transactionManager.isPaymentBeingProcessed(transactionId)
                    if isProcessed || isBeingProcessed {
                        continue
                    }
//                    transaction.revocationReason
                    let orderId = transaction.appAccountToken?.uuidString ?? ""
                    let jwsRepresentation = update.jwsRepresentation
                    let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"
                    let result = await self.PRHandleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
                    self.transactionCallback?(result)
                case .unverified(_, let verificationError):
                    self.transactionCallback?(.failure(PRSubscriptionError(code: .transactionNotVerified, underlyingError: verificationError)))
                }
            }
        }
    }
    
    // 监听商店推广购买
    @available(iOS 16.4, *)
    public func PRListenForPurchaseIntent(_ callback: @escaping (PurchaseIntent) -> Void) {
        Task.detached {
            for await purchaseIntent in PurchaseIntent.intents {
                callback(purchaseIntent)
            }
        }
    }
    
    public func restore() async -> Bool {
        var succeed = false
        await payHelper.PRSyncTransaction()
        let unfinishedTransactionList = await payHelper.PRQueryUnfinishedTransaction()
        for item in unfinishedTransactionList {
            let (transaction, jwsRepresentation) = item
            let orderId = transaction.appAccountToken?.uuidString ?? ""
            let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"
            let result = await self.PRHandleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            switch result {
            case .success(_):
                succeed = true
            case .failure(let error):
                print("restore error = \(error)")
            }
        }
        return succeed
    }
    
    private func PRTracePayResult(traceId: String, result: PaymentResult) {
        Task {
            var status = 0
            var failReason = ""
            switch result {
            case .success(let transaction):
                status = 3
                failReason = ""
            case .failure(let error):
                status = 2
                failReason = "code=\(error.errorCode)#msg=\(error.errorMsg)"
            }
            let traceSubscribeOrderModel = PRQuerySubscriptionOrderModel(
                traceId: traceId, status: status, failReason: failReason
            )
            try? await PRRequestHandlerManager.shared.PRrequest(url: traceOrderApi, method: .post, parameters: traceSubscribeOrderModel)
        }
    }
    
    private func PRConvertToJson(_ object: Any, opts: JSONSerialization.WritingOptions = []) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: opts)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return ""
            }
        } catch _ {
            return ""
        }
    }
    
}

