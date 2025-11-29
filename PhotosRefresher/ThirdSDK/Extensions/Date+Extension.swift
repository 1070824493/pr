//
//  Date+Extension.swift
//  OverseasSwiftExtensions
//

public enum TimeFormat: String {
    case day = "YYYY-MM-dd"
    case house = "YYYY-MM-dd HH"
    case minute = "YYYY-MM-dd HH:mm"
    case second = "YYYY-MM-dd HH:mm:ss"
    case millSecond = "yyyy-MM-dd HH:mm:ss.SSS"
    case normalDay = "YYYY.MM.dd"
}

public extension Date {
    
    //MARK: - 是否为今天
    func isToday() -> Bool {
        let calendar = Calendar.current
        let unit: Set<Calendar.Component> = [.day,.month,.year]
        let nowComps = calendar.dateComponents(unit, from: Date())
        let selfCmps = calendar.dateComponents(unit, from: self)
        
        return (selfCmps.year == nowComps.year) &&
        (selfCmps.month == nowComps.month) &&
        (selfCmps.day == nowComps.day)
    }
    
    /// 获取当前时间某个日期之后的时间字符串
    /// - Parameter components: eg, 7天之后: DateComponents(day: 7)
    static func getDateStringAfter(components: DateComponents) -> String {
        
        let date = Calendar.current.date(byAdding: components, to: Date())
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, YYYY"
        return formatter.string(from: date ?? Date())
    }
    
    //MARK: - 获取当前时间
    static func getCurrentTime(timeFormat: TimeFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = timeFormat.rawValue
        let timezone = TimeZone.init(identifier: "Asia/Beijing")
        formatter.timeZone = timezone
        let dataTime = formatter.string(from: Date())
        return dataTime
    }
    
    //MARK: - 字符串转NSDate
    static func dateFromString(timeFormat: TimeFormat, date: String) -> NSDate {
        let formatter = DateFormatter()
        formatter.locale = NSLocale.init(localeIdentifier: "en_US") as Locale
        formatter.dateFormat = timeFormat.rawValue
        let inputDate = formatter.date(from: date)
        let zone = NSTimeZone.system
        let interval = zone.secondsFromGMT(for: inputDate!)
        let localeDate = inputDate?.addingTimeInterval(TimeInterval(interval))
        return localeDate! as NSDate
    }
    
    //MARK: - 时间戳转时间
    static func getTimeFromTimestamp(timeformat: TimeFormat, time: String) -> String {
        let newTime = Int(time) ?? 0/1000
        let myDate = NSDate.init(timeIntervalSince1970: TimeInterval(newTime))
        let formatter = DateFormatter()
        formatter.dateFormat = timeformat.rawValue
        let timeString = formatter.string(from: myDate as Date)
        return timeString
    }
    
    /// 时间戳转字符串
    /// - Parameters:
    ///   - timeformat: format
    ///   - timestamp: in seconds
    static func timestampToString(timeformat: String, timestamp: TimeInterval) -> String {
        let myDate = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = timeformat
        let timeString = formatter.string(from: myDate)
        return timeString
    }
    
    //MARK: - 获取当前时区时间
    static func getCurrentZoneTime(timeFormat: TimeFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = timeFormat.rawValue
        let dataTime = formatter.string(from: Date())
        return dataTime
    }
    
    
    /// 获取时间戳
    static func convertStringToTimestamp(dateString: String, timeFormat: TimeFormat) -> TimeInterval? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = timeFormat.rawValue
        
        if let date = dateFormatter.date(from: dateString) {
            return date.timeIntervalSince1970
        } else {
            return nil
        }
    }
    
    static func currentTimestamp() -> Int {
        return Int(NSDate().timeIntervalSince1970 * 1000)
    }

}
