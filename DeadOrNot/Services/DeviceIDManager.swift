import Foundation
import UIKit

final class DeviceIDManager {
    static let shared = DeviceIDManager()
    private let userDefaultsKey = "DeadOrNot.deviceID"
    
    private init() {}
    
    var deviceID: String {
        if let storedID = UserDefaults.standard.string(forKey: userDefaultsKey), !storedID.isEmpty {
            return storedID
        }
        
        // 生成新的设备ID
        let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newID, forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
        return newID
    }
}
