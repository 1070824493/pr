//
//  DeviceUtils.swift

//
//

import UIKit

class DeviceUtils {
    
    private static var osName: String = ""
    
    private static var deviceType: UIUserInterfaceIdiom? = nil
    
    private static var systemVersion = ""
    
    public static func getOSName() -> String {
        if !osName.isEmpty {
            return osName
        }
        osName = UIDevice.current.systemName.lowercased()
        return osName
    }
    
    public static func getDeviceType() -> UIUserInterfaceIdiom {
        guard deviceType == nil else {
            return deviceType!
        }
        
        deviceType = UIDevice.current.userInterfaceIdiom
        return deviceType!
    }
    
    public static func getSystemVersion() -> String {
        if !systemVersion.isEmpty {
            return systemVersion
        }
        systemVersion = UIDevice.current.systemVersion
        return systemVersion
    }
    
    public static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return identifier
    }
    
    let deviceMapping: [String: String] = [
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        
        // iPad 型号映射...
        "iPad6,11": "iPad (5th generation)",
        "iPad7,5": "iPad (6th generation)",
        // 可以继续添加更多设备映射
    ]
    
}
