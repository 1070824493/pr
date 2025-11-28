//
//  LocalizableManager.swift
//  LangLearn
//
//
//  Locale.current.languageCode / Locale.current.language.languageCode?.identifier ：获取系统设置的语言码，如 en
//  Locale.current.regionCode：获取系统设置的国家或区域代码，例如 "US"
//  Locale.current.identifier：获取系统设置的完整标识符，例如 "en_US"
//  Locale.preferredLanguages.first：类似于 Locale.current.identifier ，但是用 - 分割，如 en-US
//
//

import SwiftUI



class AppLocalizationManager: ObservableObject {
    
    public static let shared = AppLocalizationManager()
    
    private init() {
        #if DEBUG
        let languageCodeIdentifier = Locale.current.language.languageCode?.identifier
        let languageCode = Locale.current.languageCode
        let regionCode = Locale.current.regionCode
        let identifier = Locale.current.identifier
        let preferredLanguages = Locale.preferredLanguages.first
        print("languageCodeIdentifier = \(languageCodeIdentifier). languageCode = \(languageCode). regionCode = \(regionCode). identifier = \(identifier). preferredLanguages = \(preferredLanguages)")
        #endif
    }
    
    func getSystemLanguage() -> String {
        var preferredLanguage = Locale.preferredLanguages.first ?? "en"
        preferredLanguage = getFormateLanguageCode(preferredLanguage)
        return preferredLanguage
    }
    
    private func getFormateLanguageCode(_ localeIdentifier: String) -> String {
        let components = localeIdentifier.split(separator: "-")
        let count = components.count
        if count > 2 {
            return components[0...1].joined(separator: "-")
        } else {
            return components.first.map(String.init) ?? localeIdentifier
        }
    }
    
}
