//
//  TMSMobileAppDelegate.swift
//  TMSDocumentBrowser
//
//  Created by Mike Swan on 5/10/15.
//  Copyright (c) 2015 theMikeSwan. All rights reserved.
//

import UIKit

// TODO: Find a better home for this and get the Bool out of this code and moved to someplace more accessible.
/// Modified version of ZAssert from Marcus Zara to help catch silly mistakes during development.
let DEBUG = true

func ZAssert(test: Bool, message: String) {
    if (test) {
        return
    }
    
    print(message)
    
    if (!DEBUG) {
        return
    }
    
    let exception = NSException()
    exception.raise()
}

/// delay function from Matt on stackoverflow (http://stackoverflow.com/users/341994/matt). Used here to delay the posting of the alert view asking the user if they want to use iCloud.
func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

/// User default to track wether we have asked the user if they want to use iCloud yet.
let kAskedAboutiCloud = "com.theMikeSwan.AskedAboutiCloud"
/// The most recently seen iCloud token. Can be nil.
let kiCloudToken = "com.theMikeSwan.iCloudToken"
/// User default to track wether the user wants to use iCloud or not. The default is false.
let kUseiCloud = "com.theMikeSwan.UseiCloud"
/// User default to store the currently open document
let kCurrentDocument = "com.theMikeSwan.CurrentDocument"
/// Constant that points to the strings table containing the internationlized version of the strings used in the document browser
let kDocumentBrowserStringTable = "DocumentBrowser"

/**
    #TMSMobileAppDelegate#
    TMSMobileAppDelegate is designed to be the superclass of your app's delegate. It will handle looking for an iCloud container and asking the user if they want to use iCloud if a container is present.
*/
class TMSMobileAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    /// Subclasses must call super at some point in overrides of this function!
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if userDefaults.objectForKey(kAskedAboutiCloud) == nil{
            userDefaults.setBool(false, forKey: kAskedAboutiCloud)
        }
        if userDefaults.objectForKey(kUseiCloud) == nil {
            userDefaults.setBool(false, forKey: kUseiCloud)
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("storeDidChange:"), name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: NSUbiquitousKeyValueStore.defaultStore())
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
        
        if NSFileManager.defaultManager().ubiquityIdentityToken != nil {
            if userDefaults.boolForKey(kAskedAboutiCloud) == false {
                delay(0.1, closure:{
                    self.determineiCloudPreference()
                    userDefaults.setBool(true, forKey: kAskedAboutiCloud)
                })
            } else {
                configureiCloud()
                continueLaunch()
            }
        } else {
            continueLaunch()
        }
        return true
    }
    
    func continueLaunch() {
        if let currentURL = NSUserDefaults.standardUserDefaults().valueForKey(kCurrentDocument) as? NSURL {
            if NSFileManager.defaultManager().isReadableFileAtPath(currentURL.path!) {
                restoreDocument(currentURL)
            }
        } else {
            openDocBrowser()
        }
    }
    
    func configureiCloud() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if userDefaults.boolForKey(kUseiCloud) == true {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                let result = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(self.iCloudContainerID())
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.containerConfigComplete(result)
                })
            })
            let currentiCloudToken = NSFileManager.defaultManager().ubiquityIdentityToken!
            if let storedTokenData = userDefaults.objectForKey(kiCloudToken) as? NSData {
                let storedToken = NSKeyedUnarchiver.unarchiveObjectWithData(storedTokenData) as! protocol<NSCoding, NSCopying, NSObjectProtocol>
                if !currentiCloudToken.isEqual(storedToken) {
                    self.containerMismatch()
                    self.storeToken(currentiCloudToken)
                }
            } else {
                self.storeToken(currentiCloudToken)
            }
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "containerChanged:", name: NSUbiquityIdentityDidChangeNotification, object: nil)
    }
    
    /// Asks the user if they want to use iCloud or not and stores the answer in a user default.
    /// There will typically be no reason for subclasses to override this function.
    func determineiCloudPreference() {
        let title = NSLocalizedString("Use iCloud to Store Documents?", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Use iCloud to Store Documents?", comment: "Title for the alert asking the user if they wanto to use iCloud or not")
        let message = NSLocalizedString("Would you like to store your documents in iCloud for access from all your devices?", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Would you like to store your documents in iCloud for access from all your devices?", comment: "Body text of alert asking the user if they want to use iCloud to store all documents.")
        let defaultTitle = NSLocalizedString("Yes, Use iCloud", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Yes, Use iCloud", comment: "Affermative answer to the question of wehter to use iCloud or not for document storage.")
        let alternateTitle = NSLocalizedString("No, Store Locally", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "No, Store Locally", comment: "Negative answer to the question of wether to use iCloud storage or not.")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: defaultTitle, style: .Default, handler: { (action) -> Void in
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: kUseiCloud)
            self.continueLaunch()
            self.configureiCloud()
        }))
        alert.addAction(UIAlertAction(title: alternateTitle, style: .Default, handler: { (action) -> Void in
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: kUseiCloud)
            self.continueLaunch()
        }))
        self.window!.rootViewController?.presentViewController(alert, animated: true, completion: { })
    }
    
    /// Called when the notification is recieved that the ubiquity token changed. Default implementation just stores the new token.
    /// Overrides should call super to take care of storing the new token and then perform any additional tasks before or after the new token is stored as needed.
    func containerChanged(aNote: NSNotification) {
        let currentiCloudToken = NSFileManager.defaultManager().ubiquityIdentityToken
        storeToken(currentiCloudToken)
    }
    
    /// Called when the current container doesn't match the one stored in the user defaults. We don't do anything with it but subclasses might want to know.
    /// There is no need to call super in overrides as the default implementation of this function is a stub.
    func containerMismatch() {
        
    }
    
    /// Called when NSFilemanager returns from URLForUbiquityContainer(). Default implementation does nothing but subclasses can use it if needed.
    /// There is no need to call super in overrides as the default implementation of this function is a stub.
    func containerConfigComplete(result: NSURL?) {
//        print("containerConfigComplete: \(result)")
    }
    
    /// Stores the passed in iCloud token to the user defaults.
    /// There will typically be no reason for subclasses to override this function.
    func storeToken(token: protocol<NSCoding, NSCopying, NSObjectProtocol>?) {
        if token != nil {
            let newTokenData = NSKeyedArchiver.archivedDataWithRootObject(token!)
            NSUserDefaults.standardUserDefaults().setObject(newTokenData, forKey: kiCloudToken)
        } else {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(kiCloudToken)
        }
    }
    
    /// Used to respond to changes in user defaults from iCloud.
    /// Overrides should either use this default implementation or completely replace it functionality. Calling super will likely lead to redundant work that may have unexpected side effects.
    func storeDidChange(aNote: NSNotification) {
        if let userInfo = aNote.userInfo {
            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]{
                let store = aNote.object as! NSUbiquitousKeyValueStore
                for key in changedKeys {
                    NSUserDefaults.standardUserDefaults().setObject(
                        store.objectForKey(key), forKey: key)
                }
            }
        }
    }
    
    /// Supplies the iCloud container ID, default implementation is nil but subclasses can override to supply a specific ID.
    /// There is no need to call super when overriding this function.
    func iCloudContainerID() -> String? {
        return nil
    }
    
    /// Called when there is a value for the currently open document. Subclasses should override to facilicate re-opening the document
    func restoreDocument(URL: NSURL) {
        print("Subclasses of TMSMobileAppDelegate should override restoreDocument(URL:) so that the document, \(URL.lastPathComponent), can be restored!")
    }
    
    /// Called when there is no value for the current document at app launch, default implementation opens the document browser. Override to prevent opening of document browser at launch. The default implementation expects the root view to have a segure called "showDocumentBrowser" that shows the document browser. If the root view controller is something such as a tab view or navigation controller you will need to override this 
    func openDocBrowser() {
        delay(0.1) { () -> () in
            self.window!.rootViewController?.performSegueWithIdentifier("showDocumentBrowser", sender: nil)
        }
    }
   
}
