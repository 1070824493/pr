//
//  PRSettingSection.swift

//
//  Created by ty on 2025/11/19.
//
import Foundation

/// 一个分组
struct PRSettingSection {
    let id: SectionID
    var items: [SettingItem]
}

/// 行样式
enum SettingItemStyle {
    case toggle(isOn: Bool)
    case navigation
}

/// Section 标题样式
enum SectionHeaderStyle {
    case title(String)
    case titleWithSubtitle(title: String, subtitle: String)
}

/// 一个配置项
struct SettingItem {
    let id: SettingID
    let style: SettingItemStyle
}



enum SettingAction {
    case toggle(SettingID, isOn: Bool)
    case navigation(SettingID)
}

/// 每个配置项
enum SettingID: String, CaseIterable {
    case photosAndVideos
    case addressBook
    case usePassword
    case changePassword
    case contactUs
    case rateApp
    case shareApp
    case termsOfUse
    case privacyPolicy
    case clearSlideHistory
}

extension SettingID {
    var title: String {
        switch self {
        case .photosAndVideos: return "Photos and videos"
        case .addressBook: return "Address book"
        case .usePassword: return "Use password"
        case .changePassword: return "Change password"
        case .contactUs: return "Contact us"
        case .rateApp: return "Rate app"
        case .shareApp: return "Share app"
        case .termsOfUse: return "Terms of use"
        case .privacyPolicy: return "Privacy policy"
        case .clearSlideHistory:
            return "Clean Slide History"
        }
    }
}

/// 每个 Section
enum SectionID: String, CaseIterable {
    case deleteAfterImport
    case secretSpace
    case helpAndFeedback
    case legal
    case slide
}

extension SectionID {
    var header: SectionHeaderStyle {
        switch self {
        case .deleteAfterImport:
            return .titleWithSubtitle(
                title: "Delete after importing",
                subtitle: "After importing to a private space, automatically delete photos and videos in the album"
            )
        case .secretSpace:
            return .titleWithSubtitle(
                title: "Secret Space",
                subtitle: "Protecting personal data stored in Secret spaces"
            )
        case .helpAndFeedback:
            return .title("Help & Feedback")
        case .legal:
            return .title("Legal")
        case .slide:
            return .title("Slide")
        }
    }
}
