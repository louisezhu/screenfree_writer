import Foundation
import CoreData

class CoreDataMigrator {
    static let shared = CoreDataMigrator()
    
    private init() {}
    
    // 在应用启动时调用此方法
    func setupCheckedParagraphEntity() {
        let managedObjectModel = CoreDataManager.shared.persistentContainer.managedObjectModel
        
        // 检查是否已经存在CheckedParagraphEntity实体
        if managedObjectModel.entitiesByName["CheckedParagraphEntity"] == nil {
            // 创建实体描述
            let entity = NSEntityDescription()
            entity.name = "CheckedParagraphEntity"
            entity.managedObjectClassName = "CheckedParagraphEntity"
            
            // 创建属性
            let idAttribute = NSAttributeDescription()
            idAttribute.name = "id"
            idAttribute.attributeType = .UUIDAttributeType
            idAttribute.isOptional = false
            
            let paragraphTextAttribute = NSAttributeDescription()
            paragraphTextAttribute.name = "paragraphText"
            paragraphTextAttribute.attributeType = .stringAttributeType
            paragraphTextAttribute.isOptional = false
            
            let chapterIdAttribute = NSAttributeDescription()
            chapterIdAttribute.name = "chapterId"
            chapterIdAttribute.attributeType = .UUIDAttributeType
            chapterIdAttribute.isOptional = false
            
            let checkedDateAttribute = NSAttributeDescription()
            checkedDateAttribute.name = "checkedDate"
            checkedDateAttribute.attributeType = .dateAttributeType
            checkedDateAttribute.isOptional = false
            
            // 将属性添加到实体
            entity.properties = [idAttribute, paragraphTextAttribute, chapterIdAttribute, checkedDateAttribute]
            
            // 更新模型
            var entities = managedObjectModel.entities
            entities.append(entity)
            managedObjectModel.entities = entities
            
            print("成功创建CheckedParagraphEntity实体")
        } else {
            print("CheckedParagraphEntity实体已存在")
        }
    }
} 