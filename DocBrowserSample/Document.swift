//
//  Document.swift
//  DocBrowserSample
//
//  Created by Mike Swan on 7/28/15.
//  Copyright © 2015 theMikeSwan. All rights reserved.
//

import UIKit

enum DocumentError: ErrorType {
    /// Thrown when contents passed into loadFromContents is not an NSData.
    case NotAnNSData
}

/// Super simple subclass of UIDocument that holds a single NSAttributedString.
class Document: UIDocument {
    var contentString = NSAttributedString(string: "")
    
    override func contentsForType(typeName: String) throws -> AnyObject {
        return NSKeyedArchiver.archivedDataWithRootObject(contentString)
    }
    
    override func loadFromContents(contents: AnyObject, ofType typeName: String?) throws {
        guard let data = contents as? NSData else {
            throw DocumentError.NotAnNSData
        }
        contentString = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! NSAttributedString
    }

}
