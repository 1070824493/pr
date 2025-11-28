//
//  Codable+Extension.swift
//  OverseasSwiftExtensions
//

//

public extension Encodable {
    
    func toDictionary() -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dictionary
        } catch {
            print("toDictionary：\(error)")
            return nil
        }
    }
    
}
