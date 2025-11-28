//
//  PurchaseManager.swift
//

import StoreKit



public enum PurchaseType {
    case subscription
    case consumables
}

public struct BusinessPurchaseError: Error {
    public let code: BusinessPurchaseError.ErrorCode
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

public enum PurchaseResult {
    case success(Transaction)
    case failure(BusinessPurchaseError)
}

public class PurchaseManager {
    public static let shared = PurchaseManager()
    
    private let payHelper = PayHelper.shared
    private var initialized = false
    private var isPurchasing = false
    private let transactionManager = TransactionManager()
    private var transactionCallback: ((PurchaseResult) -> Void)?
    
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
    public func registerCallback(_ callback: @escaping (PurchaseResult) -> Void) {
        transactionCallback = callback
    }
    
    public func purchaseConsumables(
        skuId: Int,
        paySource: Int,
        traceId: String,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PurchaseResult {
        let result = await purchaseSubscriptionInternal(purchaseType: .consumables, skuId: skuId, paySource: paySource, traceId: traceId, ignorePurchased: true, extParams: extParams, onBeforePurchase: onBeforePurchase)
        tracePurchaseResult(traceId: traceId, result: result)
        return result
    }
    
    public func purchaseSubscription(
        skuId: Int,
        paySource: Int,
        traceId: String,
        ignorePurchased: Bool = false,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PurchaseResult {
        let result = await purchaseSubscriptionInternal(purchaseType: .subscription, skuId: skuId, paySource: paySource, traceId: traceId, ignorePurchased: ignorePurchased, extParams: extParams, onBeforePurchase: onBeforePurchase)
        tracePurchaseResult(traceId: traceId, result: result)
        return result
    }
    
    private func purchaseSubscriptionInternal(
        purchaseType: PurchaseType,
        skuId: Int,
        paySource: Int,
        traceId: String,
        ignorePurchased: Bool = false,
        extParams: [String: Any]? = nil,
        onBeforePurchase: ((Product) -> Void)? = nil
    ) async -> PurchaseResult {
        guard initialized else {
            return .failure(BusinessPurchaseError(code: .notInit, underlyingError: nil))
        }
        
        guard !isPurchasing else {
            return .failure(BusinessPurchaseError(code: .alreadyInProgress, underlyingError: nil))
        }
        
        guard payHelper.canMakePayments() else {
            return .failure(BusinessPurchaseError(code: .cannotMakePayments, underlyingError: nil))
        }
        
        if !ignorePurchased {
            let isPurchased = await transactionManager.isPurchased()
            guard !isPurchased else {
                return .failure(BusinessPurchaseError(code: .isPurchased, underlyingError: nil))
            }
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let orderResponse = try await fetchOrderId(purchaseType: purchaseType, skuId: skuId, paySource: paySource, traceId: traceId, extParams: extParams)
            let orderId = orderResponse.appAccountToken
            let productId = orderResponse.productId
            let purchaseResult = try await payHelper.purchaseProduct(with: productId, appAccountToken: UUID(uuidString: orderId)!) { product in
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
                    return await handleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
                case .unverified(_, let error):
                    return .failure(BusinessPurchaseError(code: .transactionNotVerified, underlyingError: error))
                }
            case .userCancelled:
                return .failure(BusinessPurchaseError(code: .userCancelled, underlyingError: nil))
            case .pending:
                return .failure(BusinessPurchaseError(code: .purchasePending, underlyingError: nil))
            @unknown default:
                return .failure(BusinessPurchaseError(code: .unknown, underlyingError: nil))
            }
        } catch {
            if error is BusinessPurchaseError {
                return .failure(error as! BusinessPurchaseError)
            } else if error is Product.PurchaseError {
                return .failure(BusinessPurchaseError(code: .purchaseFailed, underlyingError: error))
            } else if error is StoreKitError {
                return .failure(BusinessPurchaseError(code: .purchaseFailed, underlyingError: error))
            } else {
                return .failure(BusinessPurchaseError(code: .unknown, underlyingError: error))
            }
        }
    }
    
    private func fetchOrderId(purchaseType: PurchaseType, skuId: Int, paySource: Int, traceId: String, extParams: [String: Any]? = nil) async throws -> CreateSubscribeOrderResponse {
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
            inExtParams = convertToJson(extParams)
        }
        let parameters = CreateSubscribeOrderRequest(
            skuId: skuId, payChannel: payChannel, paySource: paySource, traceId: traceId, ext: inExtParams
        )
        do {
            let response: CommonResponse<CreateSubscribeOrderResponse> = try await NetworkManager.shared.request(url: inCreateOrderApi, method: .post, parameters: parameters)
            if response.errNo != 0 {
                let error = NSError(domain: "PurchaseManager", code: response.errNo, userInfo: [NSLocalizedDescriptionKey: response.errMsg])
                throw BusinessPurchaseError(code: .createOrderFailed, underlyingError: error)
            }
            
            return response.data
        } catch {
            throw BusinessPurchaseError(code: .createOrderFailed, underlyingError: error)
        }
    }
    
    private func handleSuccessfulPayment(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async -> PurchaseResult {
        let transactionId = String(transaction.id)
        let isProcessed = await transactionManager.isTransactionProcessed(transactionId)
        let isBeingProcessed = await transactionManager.isTransactionBeingProcessed(transactionId)
        if isProcessed || isBeingProcessed {
            return .failure(BusinessPurchaseError(code: .transactionAlreadyProcessed, underlyingError: nil))
        }
        
        await transactionManager.recordTransactionAsProcessing(transactionId)
        
        var underlyingError: Error? = nil
        var reportSucceed = false
        
        let maxRetries = 2
        var retryCount = 0
        while retryCount <= maxRetries {
            do {
                reportSucceed = try await sendOrderToServer(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            } catch {
                underlyingError = error
            }
            
            if reportSucceed {
                await transaction.finish()
                await transactionManager.recordTransactionAsProcessed(transactionId)
                await transactionManager.removeTransactionFromProcessing(transactionId)
                return .success(transaction)
            } else {
                retryCount += 1
                if (retryCount <= maxRetries) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        await transactionManager.removeTransactionFromProcessing(transactionId)
        Task {
            await startScheduledRetry(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
        }
        return .failure(BusinessPurchaseError(code: .reportOrderFailed, underlyingError: underlyingError))
    }
    
    private func sendOrderToServer(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async throws -> Bool {
        let parameters = ReportSubscribeOrderRequest(
            receipt: "",
            payload: jwsRepresentation,
            transId: String(transaction.id),
            traceId: traceId,
            orderId: orderId,
            originalTransId: String(transaction.originalID),
            ext: "{}"
        )
        let response: CommonResponse<ReportSubscribeOrderResponse> = try await NetworkManager.shared.request(url: reportOrderApi, method: .post, parameters: parameters)
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
    
    private func startScheduledRetry(transaction: Transaction, jwsRepresentation: String, orderId: String, traceId: String) async {
        var underlyingError: Error? = nil
        var reportSucceed = false
        
        var attempt = 0
        let maxAttempts = 5
        let transactionId = String(transaction.id)
        while attempt < maxAttempts {
            let delay = pow(2.0, Double(attempt))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                reportSucceed = try await sendOrderToServer(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            } catch {
                underlyingError = error
            }
            
            if reportSucceed {
                await transaction.finish()
                await self.transactionManager.recordTransactionAsProcessed(transactionId)
                await self.transactionManager.removeTransactionFromProcessing(transactionId)
                self.transactionCallback?(.success(transaction))
                return
            }
            attempt += 1
        }
        
        // 处理在最大重试次数后仍未成功的场景，可以选择执行一些报警或其他业务逻辑
        self.transactionCallback?(.failure(BusinessPurchaseError(code: .reportOrderFailedAfterRetry, underlyingError: underlyingError)))
    }
    
    // 监听交易状态更新
    public func listenForTransactionUpdates() {
        Task.detached {
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    let transactionId = String(transaction.id)
                    let isProcessed = await self.transactionManager.isTransactionProcessed(transactionId)
                    let isBeingProcessed = await self.transactionManager.isTransactionBeingProcessed(transactionId)
                    if isProcessed || isBeingProcessed {
                        continue
                    }
//                    transaction.revocationReason
                    let orderId = transaction.appAccountToken?.uuidString ?? ""
                    let jwsRepresentation = update.jwsRepresentation
                    let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"
                    let result = await self.handleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
                    self.transactionCallback?(result)
                case .unverified(_, let verificationError):
                    self.transactionCallback?(.failure(BusinessPurchaseError(code: .transactionNotVerified, underlyingError: verificationError)))
                }
            }
        }
    }
    
    // 监听商店推广购买
    @available(iOS 16.4, *)
    public func listenForPurchaseIntent(_ callback: @escaping (PurchaseIntent) -> Void) {
        Task.detached {
            for await purchaseIntent in PurchaseIntent.intents {
                callback(purchaseIntent)
            }
        }
    }
    
    public func restore() async -> Bool {
        var succeed = false
        await payHelper.syncPurchases()
        let unfinishedTransactionList = await payHelper.queryUnfinishedTransaction()
        for item in unfinishedTransactionList {
            let (transaction, jwsRepresentation) = item
            let orderId = transaction.appAccountToken?.uuidString ?? ""
            let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"
            let result = await self.handleSuccessfulPayment(transaction: transaction, jwsRepresentation: jwsRepresentation, orderId: orderId, traceId: traceId)
            switch result {
            case .success(_):
                succeed = true
            case .failure(let error):
                print("restore error = \(error)")
            }
        }
        return succeed
    }
    
    private func tracePurchaseResult(traceId: String, result: PurchaseResult) {
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
            let traceSubscribeOrderModel = TraceSubscribeOrderModel(
                traceId: traceId, status: status, failReason: failReason
            )
            try? await NetworkManager.shared.request(url: traceOrderApi, method: .post, parameters: traceSubscribeOrderModel)
        }
    }
    
    private func convertToJson(_ object: Any, opts: JSONSerialization.WritingOptions = []) -> String {
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
