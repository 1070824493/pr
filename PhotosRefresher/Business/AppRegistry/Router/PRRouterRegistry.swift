//
//  RouterRegistry.swift

//
//


import Foundation
import SwiftUI


@MainActor
extension View {
    
    func withAppRouter() -> some View {
        navigationDestination(for: PRAppRouterPath.NavigationEntry.self) { navigationEntry in
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
                PRShareImageActivityView(images: images, files: files, completion: nil)
            case .subscription(let paySource, let onDimiss):
                PRSubscribeEntryView(
                    paySource: paySource,
                    onDismiss: onDimiss
                ).environmentObject(PRUIState.shared)
            }
        }
    }
    
    func withEnvironments() -> some View {
        self.environmentObject(PRUIState.shared)
            .environmentObject(PRRequestHandlerObserver.shared)
            .environmentObject(PRAppUserPreferences.shared)
            .environmentObject(PRConfigManager.shared)
    }
    
}
