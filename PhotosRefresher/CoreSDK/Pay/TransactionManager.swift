//
//  TransactionManager.swift
//

actor TransactionManager {
    
    private var processedTransactions = Set<String>()
    private var processingTransactions = Set<String>()
    
    func isTransactionProcessed(_ transactionId: String) -> Bool {
        return processedTransactions.contains(transactionId)
    }
    
    func recordTransactionAsProcessed(_ transactionId: String) {
        processedTransactions.insert(transactionId)
    }
    
    func isTransactionBeingProcessed(_ transactionId: String) -> Bool {
        return processingTransactions.contains(transactionId)
    }
    
    func recordTransactionAsProcessing(_ transactionId: String) {
        processingTransactions.insert(transactionId)
    }
    
    func removeTransactionFromProcessing(_ transactionId: String) {
        processingTransactions.remove(transactionId)
    }
    
    func isPurchased() -> Bool {
        return !processedTransactions.isEmpty || !processingTransactions.isEmpty
    }
    
}
