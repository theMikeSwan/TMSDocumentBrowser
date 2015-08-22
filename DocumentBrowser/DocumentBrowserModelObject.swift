/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Originally written by Apple Inc. 2015
    Modified by Mike Swan June 2015

    Abstract:
    This is the model object which represents one document on disk.
*/

import UIKit


/**
    This class is used as an immutable value object to represent an item in our
    document browser. Note the custom implementation of `hash` and `isEqual(_:)`, 
    which are required so we can later look up instances in our results set.
*/
class DocumentBrowserModelObject: NSObject, ModelObject {
    // MARK: Properties

    private(set) var displayName: String
    
    private(set) var subtitle = ""
    
    private(set) var lastAccessed = ""
    
    private(set) var URL: NSURL

    private(set) var metadataItem: NSMetadataItem

    // MARK: Initialization
    required init(item: NSMetadataItem) {
        // Changed where displayName comes from to allow Finder on OS X to show the same name. Apple's original assignment is commented out below. Finder pulls the name it shows from the URL so documents could end up with a different name on each platform confusing te user.
        // displayName = item.valueForAttribute(NSMetadataItemDisplayNameKey) as! String
        
        /*
            External documents are not located in the app's ubiquitous container.
            They could either be in another app's ubiquitous container or in the
            user's iCloud Drive folder, outside of the app's sandbox, but the user
            has granted the app access to the document by picking the document in
            the document picker or opening the document in the app on OS X.
            Throughout the system, the name of the document is decorated with the
            source container's name.
        */
        if let isExternal = item.valueForAttribute(NSMetadataUbiquitousItemIsExternalDocumentKey) as? Bool,
               containerName = item.valueForAttribute(NSMetadataUbiquitousItemContainerDisplayNameKey) as? String
               where isExternal {
            subtitle = "in \(containerName)"
        }
        
        /*
            The `NSMetadataQuery` will send updates on the `NSMetadataItem` item.
            If the item is renamed or moved, the value for `NSMetadataItemURLKey`
            might change.
        */
        URL = item.valueForAttribute(NSMetadataItemURLKey) as! NSURL
        
        // New way of deriving the display name to keep in sync with OS X
        displayName = ((URL.lastPathComponent! as NSString).stringByDeletingPathExtension)
        
        do {
            var holder: AnyObject?
            try URL.getResourceValue(&holder, forKey: NSURLContentAccessDateKey)
            if holder != nil {
                let formatter = NSDateFormatter()
                formatter.dateStyle = NSDateFormatterStyle.ShortStyle
                lastAccessed = formatter.stringFromDate(holder as! NSDate)
            }
        } catch {
            NSLog("Error getting access date for document named \(displayName): \(error)")
        }
        
        metadataItem = item
    }
    
    /// Convience init function to deal with the lack of any useful way to create NSMetadataItems.
    init(url: NSURL) {
        let filemanager = NSFileManager.defaultManager()
        ZAssert(!filemanager.isUbiquitousItemAtURL(url), message: "For ubiquitous documents use init(item: NSMetadataItem) not init(url: NSURL)!")
        URL = url
        displayName = ((URL.lastPathComponent! as NSString).stringByDeletingPathExtension)
        metadataItem = NSMetadataItem()
        do {
            var holder: AnyObject?
            try URL.getResourceValue(&holder, forKey: NSURLContentAccessDateKey)
            if holder != nil {
                let formatter = NSDateFormatter()
                formatter.dateStyle = NSDateFormatterStyle.ShortStyle
                lastAccessed = formatter.stringFromDate(holder as! NSDate)
            }
        } catch {
            NSLog("Error getting access date for document named \(displayName): \(error)")
        }
    }
    
    // MARK: Override
    
    /**
        Two `DocumentBrowserModelObject` are equal if their metadata items are equal.
        We use the metadata item instead of other properties like the URL to compare
        equality in order to track documents across renames.
    */
    override func isEqual(object: AnyObject?) -> Bool {
        guard let other = object as? DocumentBrowserModelObject else {
            return false
        }
        if NSFileManager.defaultManager().isUbiquitousItemAtURL(URL) {
            return other.metadataItem.isEqual(metadataItem)
        } else {
            return other.URL.isEqual(URL)
        }
    }

    /// Hash method implemented to match `isEqual(_:)`'s constraints.
    override var hash: Int {
        if NSFileManager.defaultManager().isUbiquitousItemAtURL(URL) {
            return metadataItem.hash
        } else {
            return URL.hash
        }
    }
   
    // MARK: CustomDebugStringConvertible
    
    override var debugDescription: String {
        return super.debugDescription + " " + displayName
    }
}