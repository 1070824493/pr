//
//  SubscriptionExitAlert.swift
//  Dialogo
//
//  
//

import SwiftUI

struct ExitAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let okTitle: String
    let cancelTitle: String
    let onOK: () -> Void
    let onCancel: () -> Void
}

