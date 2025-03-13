import Foundation

class SyncStatusManager {
    static let shared = SyncStatusManager()
    
    private let userDefaults = UserDefaults.standard
    private let lastSyncTimeKey = "com.screenfree.writer.lastSyncTime."
    
    private init() {}
    
    func setLastSyncTime(for bookId: UUID, date: Date) {
        let key = lastSyncTimeKey + bookId.uuidString
        userDefaults.set(date.timeIntervalSince1970, forKey: key)
    }
    
    func getLastSyncTime(for bookId: UUID) -> Date? {
        let key = lastSyncTimeKey + bookId.uuidString
        
        // 使用 object(forKey:) 来获取 Optional 值
        if let timeInterval = userDefaults.object(forKey: key) as? Double, timeInterval > 0 {
            return Date(timeIntervalSince1970: timeInterval)
        }
        
        return nil
    }
    
    func clearSyncStatus(for bookId: UUID) {
        let key = lastSyncTimeKey + bookId.uuidString
        userDefaults.removeObject(forKey: key)
    }
} 