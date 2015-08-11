//
//  AppDelegate.swift
//  DocBrowserSample
//
//  Created by Mike Swan on 7/28/15.
//  Copyright © 2015 theMikeSwan. All rights reserved.
//

import UIKit

// NOTE: Change AppDelegate to be a subclass of TMSMobleAppDelegate to get the document browser working
@UIApplicationMain
class AppDelegate: TMSMobileAppDelegate {

//    var window: UIWindow?

// NOTE: Add override to the start of this function
    override func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        // NOTE: Add a call to super at some point during this function. It's done before other setup here but could be after if needed (the earlier the iCloud container starts getting setup the better which is why the normal order would be super then subclass).
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // NOTE: Do any additional setup here. if result needs to be altered change from let to var.
        
        return result
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        // TODO: save document
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // TODO: save document
    }
    
    // MARK: - TMSMobileAppDelegate overrides
    override func iCloudContainerID() -> String? {
        // NOTE: return the specific container ID
        // TODO: return the correct ID
        return nil
    }

}

