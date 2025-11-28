//
//  SubscriptionProductView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionProductView: View {
    @ObservedObject var vm: SubscriptionViewModel
    var paySource: PaySource
    var onPrivacy: () -> Void
    var onTerms: () -> Void
    var onPurchase: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    private var isAudit: Bool { vm.isAuditBuild }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            let items = Array(vm.packageList.prefix(2))
            let showBubble = !items.isEmpty

            VStack(spacing: 12) {
                if items.isEmpty {
                    EmptyView()
                } else {
                    ForEach(items, id: \.skuId) { item in
                        ProductCellView(vm: vm, item: item) { onPurchase() }
                            .if(DeviceUtils.getDeviceType() == .pad) { v in
                                v.padding(.bottom, 12)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .padding(.top, 32)
            .overlay(alignment: .topTrailing) {
                if showBubble {
                    AnimatedBubble()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                }
            }

            SubscriptionContinueButton(
                title: vm.isFreeTrialDisplay ? "Try for $0.00" : "Continue",
                color: Color(hex: "186F6F"),
                pulseScale: $pulseScale,
                onTap: onPurchase
            )
            .padding(.horizontal, 0)
            .padding(.bottom, 8)

            Text(disclaimerAttributed())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, DeviceHelper.safeAreaInsets.bottom > 0 ? 22 : 4)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "dialogoApp" {
                        if url.host == "privacy" { onPrivacy(); return .handled }
                        if url.host == "terms" { onTerms(); return .handled }
                        return .discarded
                    }
                    return .systemAction(url)
                })
        }
    }

    private func disclaimerAttributed() -> AttributedString {
        let pkg = vm.selectedOrFirstPackage
        let priceText = currency(priceForDisclaimer(pkg))
        let unitText = unit(for: pkg?.duration ?? 7)
        let days = (pkg?.duration ?? 7)

        var s = AttributedString("Billed \(priceText)/\(unitText). Request a refund if you're not 100% satisfied.| Privacy | Terms | Secured by Apple")
        let isSale = pkg?.priceFirstReal ?? 0 < pkg?.priceSaleReal ?? 0
        if pkg?.freeDays ?? 0 > 0 || (isSale && pkg?.beOffered == 0) {
            s = AttributedString("Billed \(priceText)/\(unitText) auto-renewal after \(days) days. Request a refund if you're not 100% satisfied.| Privacy | Terms | Secured by Apple")
        }
        if isAudit {
            s = AttributedString("Privacy | Terms")
        }

        s.font = .regular10
        s.foregroundColor = Color(hex: "A3A3A3")

        if let r = s.range(of: "Privacy") {
            s[r].underlineStyle = .single
            s[r].foregroundColor = Color(hex: "A3A3A3")
            s[r].link = URL(string: "dialogoApp://privacy")!
        }
        if let r = s.range(of: "Terms") {
            s[r].underlineStyle = .single
            s[r].foregroundColor = Color(hex: "A3A3A3")
            s[r].link = URL(string: "dialogoApp://terms")!
        }
        if let appleSymbolRange = s.range(of: "") {
            s[appleSymbolRange].font = .regular12
        }
        return s
    }

    private func priceForDisclaimer(_ p: SubscriptionPackage?) -> Double {
        guard let p = p else { return 0 }
        return (p.freeDays > 0) ? 0 : p.priceSaleReal
    }

    private func unit(for duration: Int) -> String {
        switch duration {
        case 365: return "year"
        case 30: return "month"
        default: return "week"
        }
    }

    private func currency(_ v: Double) -> String { String(format: "$%.2f", v) }
}

struct AnimatedBubble: View {
    @State private var joinedDisplay = Int.random(in: 1500...2500)
    @State private var joinedTarget = 0

    private let fiveSecTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let stepTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(joinedDisplay) people have joined this plan today!")
            .font(.regular12)
            .foregroundColor(Color.hexColor(0x141414))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .baselineOffset(3)
            .frame(height: 28, alignment: .center)
            .background(
                Image("subscription_product_bubble")
                    .resizable(
                        capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                        resizingMode: .stretch
                    )
            )
            .offset(y: 16)
            .fixedSize(horizontal: true, vertical: true)
            .onAppear { joinedTarget = joinedDisplay }
            .onReceive(fiveSecTimer) { _ in joinedTarget += Int.random(in: 5...20) }
            .onReceive(stepTimer) { _ in if joinedDisplay < joinedTarget { joinedDisplay += 1 } }
    }
}

struct ProductCellView: View {
    @ObservedObject var vm: SubscriptionViewModel
    let item: SubscriptionPackage
    var onPayAction: () -> Void

    private var isAudit: Bool { vm.isAuditBuild }
    private var isSelected: Bool { vm.selectedPackageId == item.skuId }

    var body: some View {
        Button {
            vm.selectedPackageId = item.skuId
            onPayAction()
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "186F6F") : Color(hex: "F0F0F0"), lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                HStack(spacing: 15) {
                    Image(isSelected ? "icon_product_selected" : "icon_product_normal")
                        .resizable().frame(width: 24, height: 24)
                        .padding(.leading, 15)
                    VStack(alignment: .leading, spacing: 4) {
                        let durationText = durationForDisplay(item)
                        Text(titleFor(item))
                            .font(.bold16)
                            .foregroundColor(Color(hex: "141414"))
                            .padding(.top, durationText.isEmpty ? 0 : 14)
                        
                        if !durationText.isEmpty {
                            Text(durationText)
                                .font(.regular12)
                                .foregroundColor(isSelected ? Color(hex: "35B923") : Color(hex: "A3A3A3"))
                                .padding(.bottom, 14)
                        }
                    }

                    Spacer()

                    let price = priceForDisplay(item)
                    if !price.isEmpty {
                        Text(price)
                            .font(.bold16)
                            .foregroundColor(Color(hex: "141414"))
                            .padding(.trailing, 15)
                    }
                }
            }
            .frame(height: 64)
        }
    }

    private func titleFor(_ p: SubscriptionPackage) -> String {
        if isAudit {
            var times: String = "day"
            switch p.duration {
                case 365: times = "year"
                case 30: times = "month"
                case 7: times = "week"
                default: times = "day"
            }
            
            let auditlast = "$\(p.priceSaleReal)/\(times)"
            let beOfferedAudit: String = (isFirstOfferDisplay(p) && p.priceFirstReal < p.priceSaleReal) ? "1 \(times) \(p.priceFirstReal), then " : ""
            let freeDaysAudit: String = isFreeTrialDisplay(p) ? "\(p.freeDays) day free, then " : ""
            return freeDaysAudit + beOfferedAudit + auditlast
        } else {
            switch p.duration {
                case 365: return "Monthly Access"
                case 30: return "Weekly Access"
                default: return "7-Day Full Access"
            }
        }
    }

    private func isFreeTrialDisplay(_ p: SubscriptionPackage) -> Bool {
        (p.freeDays > 0) ? true : false
    }

    private func isFirstOfferDisplay(_ p: SubscriptionPackage) -> Bool {
        p.beOffered == 0
    }

    private func durationForDisplay(_ p: SubscriptionPackage) -> String {
        if isAudit {
            return "auto-renew, cancel anytime."
        }
        if isFreeTrialDisplay(p) {
            return "Day Free Trial"
        }
        switch p.duration {
            case 365: return "SAVE 93%！"
            case 30: return "BEST VALUE"
            default: return "MOST POPULAR"
        }
    }

    private func priceForDisplay(_ p: SubscriptionPackage) -> String {
        if isAudit {
            return ""
        }
        if isFreeTrialDisplay(p) { return "$0.00" }
        var base = p.priceSaleReal
        if isFirstOfferDisplay(p) && (p.priceFirstReal < p.priceSaleReal) {
            base = p.priceFirstReal
        }
            switch p.duration {
            case 365: return currency(base / 12.0)
            case 30: return currency(base / 4.0)
            default: return currency(base)
        }
    }

    private func currency(_ v: Double) -> String { String(format: "$%.2f", v) }
}
