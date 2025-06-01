//
//  Photo+CoreDataProperties.swift
//  
//
//  Created by Christian Bram on 30.05.25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var filename: String?
    @NSManaged public var localURL: String?
    @NSManaged public var cloudURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var memory: Memory?

}

extension Photo : Identifiable {

}
