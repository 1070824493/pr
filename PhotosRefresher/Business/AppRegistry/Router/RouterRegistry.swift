//
//  RouterRegistry.swift

//
//


import Foundation
import SwiftUI


@MainActor
extension View {
    
    func withAppRouter() -> some View {
        navigationDestination(for: AppRouterPath.NavigationEntry.self) { navigationEntry in
            switch navigationEntry.destination {
            
            case .exploreDoubleFeed(let cardID, let isVideo):
                PRDoubleFeedPage(cardID, isVideo: isVideo)
            case .exploreSecondRepeat(let cardID):
                PRDuplicatePage(cardID)
            case .slideDetail(let category):
                PRSlideDetailPage(category: category)
            case .settingPage:
                PRSettingPage()
            }
        }
    }
    
    func withFullScreenCoverRouter(_ modal: Binding<AppFullScreenCoverDestination?>) -> some View {
        self.fullScreenCover(item: modal) { item in
            switch item {
            case .exploreDeleteFinish(let count, let deletedText, let storageSize, let onDismiss):
                PRDeleteFinishPage(removedFiles: count, spaceSavedText: deletedText, storageSize: storageSize, onDismiss: onDismiss)
            case .systemShare(let images, let files):
                ShareImageActivityView(images: images, files: files, completion: nil)
            case .subscription(let paySource, let onDimiss):
                SubscribeEntryView(
                    paySource: paySource,
                    onDismiss: onDimiss
                ).environmentObject(UIState.shared)
            }
        }
    }
    
    func withEnvironments() -> some View {
        self.environmentObject(UIState.shared)
            .environmentObject(NetworkObserver.shared)
            .environmentObject(AppUserPreferences.shared)
            .environmentObject(ConfigManager.shared)
    }
    
}
