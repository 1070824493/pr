//
//  TransactionManager.swift
//

actor PRPaymentProcessManager {
    
    private var processedTransactions = Set<String>()
    private var processingTransactions = Set<String>()
    
    func isPaymentProcessed(_ transactionId: String) -> Bool {
        return processedTransactions.contains(transactionId)
    }
    
    func recordPaymentAsProcessed(_ transactionId: String) {
        processedTransactions.insert(transactionId)
    }
    
    func isPaymentBeingProcessed(_ transactionId: String) -> Bool {
        return processingTransactions.contains(transactionId)
    }
    
    func recordPaymentAsProcessing(_ transactionId: String) {
        processingTransactions.insert(transactionId)
    }
    
    func removePaymentFromProcessing(_ transactionId: String) {
        processingTransactions.remove(transactionId)
    }
    
    func isPurchased() -> Bool {
        return !processedTransactions.isEmpty || !processingTransactions.isEmpty
    }
    
}
