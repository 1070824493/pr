//
//  AppUserPreferences.swift
//
//

import SwiftUI
import Photos

public class AppUserPreferences: ObservableObject {

    public static let shared = AppUserPreferences()
    
    @AppStorage("hasShowSwipeUpDelete") var hasShowSwipeUpDelete: Bool = false
    
    @AppStorage("hasFinishGuide") var hasFinishGuide: Bool = false
    
    @AppStorage("hasFinishAlbumPermission") var hasFinishAlbumPermission: Bool = false
    
    @AppStorage("albumPermissionStatus") var albumPermissionStatus: PHAuthorizationStatus = .notDetermined
    
    @UserDefaultEnum("currentSlideCategory", defaultValue: PhotoCategory.backphoto)
    public var currentSlideCategory: PhotoCategory {
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

