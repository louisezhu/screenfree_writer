import Foundation
import CoreData

@objc(CheckedParagraphEntity)
public class CheckedParagraphEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var paragraphText: String
    @NSManaged public var chapterId: UUID
    @NSManaged public var checkedDate: Date
}

extension CheckedParagraphEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CheckedParagraphEntity> {
        return NSFetchRequest<CheckedParagraphEntity>(entityName: "CheckedParagraphEntity")
    }
} 