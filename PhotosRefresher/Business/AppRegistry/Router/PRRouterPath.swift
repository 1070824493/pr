//
//  AppRouterPath.swift

//
//

import Foundation
import SwiftUI

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

@MainActor
public class PRAppRouterPath: ObservableObject {
    
    @Published public var path: [NavigationEntry] = []
    
    private var callbacks: [UUID: (Any) -> Void] = [:]
    
    public init() {}
    
    public struct NavigationEntry: Identifiable, Hashable {
        public let id: UUID
        public let destination: AppRouterDestination
        
        public init(destination: AppRouterDestination) {
            self.id = UUID()
            self.destination = destination
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    public func navigate(_ to: AppRouterDestination) {
        let entry = NavigationEntry(destination: to)
        path.append(entry)
    }
    
    public func navigate<Result>(_ to: AppRouterDestination, callback: ((Result) -> Void)? = nil) {
        let entry = NavigationEntry(destination: to)
        path.append(entry)
        
        if let callback = callback {
            let key = entry.id
            callbacks[key] = { value in
                if let result = value as? Result {
                    callback(result)
                }
            }
        }
    }
    
    public func sendResult<Result>(_ result: Result, to entry: NavigationEntry) {
        let key = entry.id
        if let callback = callbacks[key] {
            callback(result)
            callbacks.removeValue(forKey: key)
        }
    }
    
    public func replace(_ to: AppRouterDestination) {
        back()
        navigate(to)
    }
    
    public func replace<Result>(_ to: AppRouterDestination, callback: ((Result) -> Void)? = nil) {
        back()
        navigate(to, callback: callback)
    }
    
    public func back(_ count: Int = 1) {
        guard !path.isEmpty else {
            return
        }
        
        for _ in 0..<count {
            let entry = path.removeLast()
            callbacks.removeValue(forKey: entry.id)
        }
    }
    
    public func back<Result>(_ result: Result) {
        guard !path.isEmpty else {
            return
        }
        
        let entry = path.removeLast()
        sendResult(result, to: entry)
    }
    
    public func backToRoot() {
        path.removeAll()
        callbacks.removeAll()
    }
    
    public func backToRoot<Result>(_ result: Result) {
        if let firstEntry = path.first {
            sendResult(result, to: firstEntry)
        }
        
        path.removeAll()
        callbacks.removeAll()
    }
    
    public func popupTo<Result>(_ to: AppRouterDestination, result: Result? = nil) {
        let targetName = String(describing: to)
        guard let targetIndex = path.firstIndex(where: { String(describing: $0.destination) == targetName }) else {
            return
        }
        
        for index in stride(from: path.count - 1, through: targetIndex + 1, by: -1) {
            let removedEntry = path.remove(at: index)
            let callback = callbacks.removeValue(forKey: removedEntry.id)
            
            if index == targetIndex, let result = result, let callback = callback {
                callback(result)
            }
        }
    }
    
}
