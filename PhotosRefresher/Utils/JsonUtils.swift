//
//  JsonUtils.swift

//
//

import Foundation


public class JsonUtils {
    
    /// json 序列化
    /// - Parameter object: 待序列化对象
    /// - Returns: json串
    public static func convertToJson(_ object: Any, opts: JSONSerialization.WritingOptions = []) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: opts)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return ""
            }
        } catch _ {
            return ""
        }
    }
    
    /// json 反序列化
    /// - Parameter jsonString: json串
    /// - Returns: 对应的数据接口，字典、数组等
    public static func convertFromJson(_ jsonString: String) -> Any? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return convertFromJson(jsonData)
    }
    
    public static func convertFromJson(_ jsonData: Data) -> Any? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            return jsonObject as? [String: Any]
        } catch {
            return nil
        }
    }
    
    public static func encodeData<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        do {
            let encodedData = try encoder.encode(value)
            let jsonString = String(data: encodedData, encoding: .utf8)
            return jsonString
        } catch {
            print("Failed to encode data: \(error)")
            return nil
        }
    }
    
    public static func decodeData<T: Decodable>(_ data: Data, to type: T.Type) -> T? {
        do {
            let decoder = JSONDecoder()
            let decodedInstance = try decoder.decode(T.self, from: data)
            return decodedInstance
        } catch {
            print("Failed to decode with error: \(error)")
            return nil
        }
    }
    
    public static func decodeDataWithDefaultValue<T: DecodableWithDefault>(_ data: Data, to type: T.Type) -> T {
        do {
            let decoder = JSONDecoder()
            let decodedInstance = try decoder.decode(T.self, from: data)
            return decodedInstance
        } catch {
            print("Failed to decode with error: \(error)")
            return T.defaultValue
        }
    }
    
}
