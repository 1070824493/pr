//
//  PRHomeHeaderView.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI

struct PRHomeHeaderView: View {
    let totalCleanable: Int64
    let disk: PRDiskSpace?
    let isIPad = PRDeviceUtils.getDeviceType() == .pad
    var onTapPay: () -> Void = {}

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {
            Text("Space to clean")
                .font(.system(size: 16.fit, weight: .bold))
                .foregroundColor(Color.white)
                .padding(.top, 6)
            
            HStack {
                Text(totalCleanable.prettyBytesTuple.0)
                    .font(.system(size: 36.fit, weight: .bold))
                    .foregroundColor(Color.hexColor(0xFF5329))
                Text(totalCleanable.prettyBytesTuple.1)
                    .font(.system(size: 36.fit, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.65))
            }
            .padding(.top, 6)
            
            
            HStack(spacing: 10) {
                
                HStack(spacing: 0) {
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.hexColor(0x5A63FF))
                        .frame(width: 3, height: 10)
                        .padding(.trailing, 2)
                    Text("Clutter: \(totalCleanable.prettyBytes)")
                        .font(.regular12)
                        .foregroundColor(Color.hexColor(0x666666))
                }
                if let d = disk {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.hexColor(0x50D97D))
                            .frame(width: 3, height: 10)
                            .padding(.trailing, 2)
                        Text("App & data: \(d.used.prettyBytes)")
                            .font(.regular12)
                            .foregroundColor(Color.hexColor(0x666666))

                    }
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.hexColor(0xFF5A5A))
                            .frame(width: 3, height: 10)
                            .padding(.trailing, 2)
                        Text("Total: \(d.total.prettyBytes)")
                            .font(.regular12)
                            .foregroundColor(Color.hexColor(0x666666))
                    }
                    
                }
                
            }
            .padding(.top, 8)
            
            if let d = disk, d.total > 0 {
                let total = max(1.0, Double(d.total))
                let used = max(0.0, min(Double(d.used), total))
                let clutter = max(0.0, min(Double(totalCleanable), total))
                let usedProgress = used / total
                let clutterProgress = clutter / total
                
                PRMultiProgressBarView(progressList: [clutterProgress, usedProgress], progressColor: [Color.hexColor(0x5A63FF), Color.hexColor(0x50D97D)])
                    .frame(height: 16)
                    .padding(.top, 12)
            }
            
        }
        
        
        
    }
}
