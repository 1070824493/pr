//
//  PRDeleteFinishPage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI


// MARK: - Main View

public struct PRDeleteFinishPage: View {
    @EnvironmentObject var appRouterPath: PRAppRouterPath
    public var onDismiss: (() -> Void)?

    public var totalGB: Int64 = 0
    public var usedGB: Int64 = 0
    public var clutterGB: Int64 = 0
    public var savedGB: Int64 = 0

    public var removedFilesCount: Int64 = 0
    public let spaceSavedText: String

    public var bigIcon: Image = .init("PR_completion_center")
    public var closeImage: Image = .init("icon_white_back")

    mutating func checkPRDiskSpace() {
        let disk = assessStorageMetrics()
        totalGB = disk?.totalCapacity ?? 0
        usedGB = disk?.utilizedCapacity ?? 0
        clutterGB = PRAssetsCleanManager.shared.totalSize
    }

    public init(
        removedFiles: Int64,
        spaceSavedText: String,
        storageSize: Int64,
        onDismiss: (() -> Void)?
    ) {
        self.removedFilesCount = removedFiles
        self.spaceSavedText = spaceSavedText
        self.savedGB = storageSize
        self.onDismiss = onDismiss
        checkPRDiskSpace()
    }

    private var freeGB: Int64 { max(totalGB - usedGB, 0) }
    private var usedOtherGB: Int64 { max(usedGB - clutterGB - savedGB, 0) }

    public var body: some View {
        
        ZStack(alignment: .top) {
            bgView
                .frame(width: kScreenWidth,
                       height: kScreenHeight)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                    
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        HStack {
                            Button(action: {
                                onDismiss?()
                            }) {
                                closeImage
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(10)
                            }
                            .padding(.leading, 16)
                            .padding(.top, -10)
                            
                            Spacer()
                        }
                        .frame(height: 48)
                        .padding(.top, getStatusBarHeight())
                        
                        bigIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 139, height: 93)

                        Text("Cleanup Complete!")
                            .font(.system(size: 28.fit, weight: .bold, design: .default))
                            .foregroundColor(Color.white)
                            .padding(.top, 12)

                        Text("Space Saved：\(spaceSavedText)")
                            .font(.system(size: 14.fit, weight: .regular))
                            .foregroundColor(Color.white)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                Text("🎉")
                                    .font(.system(size: 24.fit, weight: .bold, design: .default))
                                    .padding(.leading, 16)
                                
                                VStack(alignment: .leading) {
                                    Text("\(removedFilesCount) Photo(\(spaceSavedText))")
                                        .font(.system(size: 18.fit, weight: .bold, design: .default))
                                        .foregroundColor(Color.white)
                                        .padding(.bottom, 6.5)

                                    Text("You have deleted")
                                        .font(.system(size: 12.fit, weight: .regular, design: .default))
                                        .foregroundColor(Color.white.opacity(0.65))
                                }
                                
                                Spacer()
                                
                            }
                            .frame(height: 72)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(content: {
                                LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                            })
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                                    
                            )
                            
                            HStack(spacing: 16) {
                                Text("⏳")
                                    .font(.system(size: 24.fit, weight: .bold, design: .default))
                                    .padding(.leading, 16)
                                
                                VStack(alignment: .leading) {
                                    Text("10 minutes")
                                        .font(.system(size: 18.fit, weight: .bold, design: .default))
                                        .foregroundColor(Color.white)
                                        .padding(.bottom, 6.5)

                                    Text("Save time with photos refresher")
                                        .font(.system(size: 12.fit, weight: .regular, design: .default))
                                        .foregroundColor(Color.white.opacity(0.65))
                                }
                                
                                Spacer()
                                
                            }
                            .frame(height: 72)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(content: {
                                LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                            })
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                        }
                        .frame(alignment: .leading)
                        .padding(.top, 54)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                        
   
                    }
                }
                .scrollDisabled(true)
                
                
                ZStack(alignment: .bottom) {
                    VStack {
                        
                        VStack(spacing: 0) {
                            let md = "The removed files (\(removedFilesCount)) remain in the [**Recently Deleted**](cu://recently-deleted) album for 30 days. Don't forget to empty it!"
                            if let attr = try? AttributedString(
                                markdown: md,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                            ) {
                                Text(attr)
                                    .font(.system(size: 12.fit, weight: .regular, design: .default))
                                    .foregroundColor(Color.white.opacity(0.35))
                                    .tint(Color.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .environment(\.openURL, OpenURLAction { _ in
                                        if let url = URL(string: "photos-redirect://"), UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                        }
                                        return .handled
                                    })
                            } else {}
                        }
                        .padding(.horizontal, 46)
                        
                        PRThemeButton(title: "Continue") {
                            onDismiss?()
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, getBottomSafeAreaHeight() + 8)
                        
                    }
                    
                }
                
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .background(Color.black.ignoresSafeArea())
    }
    
    var bgView: some View {
        Image("cleaning_home_bg")
            .resizable()
            .scaledToFill()
            .frame(width: kScreenWidth, height: kScreenHeight)
            .clipped()
            .ignoresSafeArea()
    }
}
