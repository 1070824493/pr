//
//  AlbumPermissionView.swift

//

//

import SwiftUI

struct PRAlbumPermissionView: View {

    let actionHandler: ((_ ok: Bool) -> Void)?

    @State private var showingLoading = false
    @State private var dismissTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if showingLoading {
                loadingPageView
                    .onAppear {
                        dismissTask?.cancel()
                        dismissTask = Task {
                            try? await Task.sleep(nanoseconds: 8_000_000_000)
                            await MainActor.run {
                                PRGlobalOverlay.shared.dismiss()
                            }
                        }
                    }
                    .onDisappear {
                        dismissTask?.cancel()
                        dismissTask = nil
                    }
            } else {
                permissionAskView
            }
        }
    }

    // 请求授权页（纯白、无安全区）
    private var permissionAskView: some View {
        VStack(spacing: 0) {
            Image("AppLaunch")
                .resizable()
                .frame(width: 61, height: 61)
                .padding(.top, 236.fit)

            Text("""
            Allow to Access
            """)
                .font(.bold28)
                .foregroundColor(Color.hexColor(0x141414))
                .multilineTextAlignment(.center)
                .padding(.top, 22)
            
            photosPermissionCard
                .padding(.top, 16)


            storedOnlyYourView
                .padding(.top, 16)
            
            Spacer()

            PRThemeButton(title: "Continue", type: .guide) {
                checkPermission()
            }
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 16)
        .ignoresSafeArea()
        .background(Color.white)
    }

    private var loadingPageView: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            ZStack {
                PRLottieView(
                    animationName: "AlbumPermissionLoading/data",
                    loopMode: .loop,
                    speed: 1.0,
                    bundle: .lottie
                )
            }
            .frame(width: 100, height: 100)
            
            Text("Analyzing your storage…")
                .font(.bold24)
                .foregroundColor(Color(hex: "#141414"))
                .multilineTextAlignment(.center)
    
            Spacer(minLength: 0)
        }
        .frame(width: kScreenWidth, height: kScreenHeight)
        .ignoresSafeArea()
        .background(Color.white)
    }
    
    private var storedOnlyYourView: some View {
        HStack(alignment: .top, spacing: 0) {
            Image("albumper_page_bottom")
                .resizable()
                .frame(width: 16, height: 16)

            Text("Your media stays private and stored only on your iPhone")
                .font(.regular12)
                .foregroundColor(Color(hex: "#141414", alpha: 0.48))
                .padding(.leading, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }

    }
    
    private var photosPermissionCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("albumper_page_left")
                .resizable()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text("Photos")
                    .font(.bold14)
                    .foregroundColor(Color.hexColor(0x141414))

                Text("Allow access to clean up duplicates and free space.")
                    .font(.regular14)
                    .foregroundColor(Color(hex: "#141414").opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(width: kScreenWidth - 32, height: 84)
        .background(
            Color.hexColor(0xF5F5F5),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    // 触发权限检查
    private func checkPermission() {
        PRPhotoMapManager.shared.requestPhotoLibraryAccess { ok in
            showingLoading = true
            actionHandler?(ok)
        }
    }
}
