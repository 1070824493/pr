//
//  AppUserPreferences.swift
//
//

import SwiftUI
import Photos

public class PRAppUserPreferences: ObservableObject {

    public static let shared = PRAppUserPreferences()
    
    @AppStorage("hasShowSwipeUpDelete") var hasShowSwipeUpDelete: Bool = false
    
    @AppStorage("guided") var guided: Bool = false
    
    @AppStorage("accessGalleryPermission") var accessGalleryPermission: Bool = false
    
    @AppStorage("galleryPermissionState") var galleryPermissionState: PHAuthorizationStatus = .notDetermined
    
    @UserDefaultEnum("currentSlideCategory", defaultValue: PRAssetType.backphoto)
    public var currentSlideCategory: PRAssetType {
        willSet {
            objectWillChange.send()
        }
        didSet {

        }
    }
    
}

@propertyWrapper
public struct UserDefaultEnum<T: RawRepresentable> where T.RawValue == String {
    
    let key: String
    let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    public var wrappedValue: T {
        get {
            if let string = UserDefaults.standard.string(forKey: key) {
                return T(rawValue: string) ?? defaultValue
            }
            return defaultValue
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
    
}

