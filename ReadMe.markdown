#TMSDocumentBrowser#
Basic file browsing for iOS.

On OS X document based apps get `NSSavePanel` and `NSOpenPanel` to handle picking which file should be opened and where files should get saved. Nothing comparable exists on iOS. While there is less of a need for a save panel as documents will either all be in the local sandbox or all in iCloud there is still a need to create new documents, delete them, rename them, and pick them for opening, that's where `TMSDocumentBorwser` comes in.

`TMSDocumentBrowser` is adapted from Apple's sample project ShapeEdit and is designed to work on iOS 9 and higher. The original project was designed to only browse documents in iCloud and the browser and document viewing portions were rather coupled. I've removed that coupling, added a delegate protocol, a custom app delegate superclass, and made the browser so that it can be used for either iCloud or local documents (though it doesn't switch back and forth between them).


##Using TMSDocumentBrowser##
Start by adding all of the files in the `TMSDocumentBrowser` folder to your project. once the files are all added change the superclass of your project's `AppDelegate` to `TMSMobileAppDelegate`. Within your subclass's version of `application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool` add a call to `super`, preferably at the beginning. This will get things moving for you. That is the only function that has to be implemented in the app delegate to get the default functionality. There are several fucntions that can be overridden to customize behavior.
Once the app delegate is taken care of there are a few delegate functions in the `DocumentBrowserDelegate` protocol that need to be implemented:

* `documentBrowser(documentBrowser: DocumentBrowserController, didPickURL url: NSURL)` is called whenever the user selects a document in the browser. Most often the user will be expecting the document to be opened at that point and the document browser to disappear, there may be times when alternate behavior is desired.
* `allowedFileExtensionsForDocumentBrowser(documentBrowser: DocumentBrowserController) -> [String]` should provide an array of strings listing the file extensions that should be displayed. Currently the first extension returned will be used as the extension for all new documents (this will eventually change to a system that allows an extension to be supplied on a per creation process for greater flexibility)
* `createDocumentAtURL(url: NSURL)` is called when the user taps on the new document cell in the browser at which point the delegate should create a document at the supplied URL. if the document is to become an iCloud document the URL will be to a temporary location. After creation is complete the document will be moved into iCloud.

There are other optional delegate functions that can be implemented as well. for more information see the customizations sections below.
the last step is to add storyboard references in the correct locations within your main storyboards to link to the browser as desired.

Check out the included sample app for help in incorperating `TMSDocumentBrowser` into your own app. If you search for "// Note:" you will find places where I have added comments next to an example of the code needed for various tasks.

##What `TMSDocumentBrowser` Does##
When your app launches it will look for an iCloud token, if one is found it will then check to see if it has already asked the user if they want to use iCloud or not. If the user hasn't been asked if they want to use iCloud yet an alert will be displayed presenting the user with an option to either use iCloud or not, this answer will be stored as a user default as will the fact that the user has been asked about iCloud yet. If you want to add a user default to your app allowing the user to turn iCloud on and off the bool for wether to use iCloud or not is stored in the constant `kUseiCloud`. There is also a user default for the currently opened document, this is used to help return the user to the last place they were at. 
The document browser itself is a collection view with two sections; the first section is for recently opened documents and the second is for all documents. The first cell in the second section is for adding new documents, following the idea used in Pages and Numbers. The document cells all have a long press gesture attached to them that brings up an action sheet. This sheet will be at the bottom of the screen for iPhones and in a popover for iPads. Currently the only option that exists is to rename the document but other options will be added later.
The toolbar at the top of the browser has a cancel button for closing the browser without selectiong a document as well as an edit button. Tapping on the edit button will allow the user to select multiple documents and delete them using the delete button that appears during editing on the left side of the toolbar. Before the documents are actually deleted the user will be asked to confirm.
All user facing strings have been wrapped in localized strings but at this time English is the only language in place (feel free to add translations).

##Customizations##
####`TMSMobileAppDelegate` Functions for Subclasses to Override for Custom Behavior:####
* `iCloudContainerID() -> String?` use this function if you want to use something other than the first container listed in you entitlements. the default implementation returns nil so there is no reason to call super when overriding.
* `storeDidChange(aNote: NSNotification)` is called when changes to the key-value store come in from iCloud and assumes the changes are user default changes. the default implementation will likely work for more cases where the key-value store is being used for preferences. If there is a need to override it will likely be best to reimplement the functionality of the existing code and not call super.
* `storeToken(token: protocol<NSCoding, NSCopying, NSObjectProtocol>?)` is called when a new iCloud token is detected. subclasses will not typically need to override this function.
* `containerConfigComplete(result: NSURL?)` is called when the container has been fully setup by the system. The passed in parameter, result, will contain the URL of the container if setup was successful and nil if it wasn't. There is no need for subclasses to call super.
* `containerMismatch()` is called when the app detects that the current token is not the same as the one from the last launch indicating that the user has switched to a different iCloud account. There is no need for subclasses to call super when overriding.
* `containerChanged(aNote: NSNotification)` is called when the iCloud container changes while the app is running. this occurs when the user either signs out of iCloud or changes to a different account. There is no need for subclasses to call super when overriding.


####Additional Functions in `DocumentBrowserDelegate` for Added Functionality:####
* `documentBrowserDidCancel(documentBrowser: DocumentBrowserController)` will be called when the user cancels, aqnd closes, the document browser.
* `documentBrowser(documentBrowser: DocumentBrowserController, willDeleteDocumentAtURL urlToDelete: NSURL)` informs the delegate when a document is about to be deleted, if the selected document is currently open this is the time to close it and remove any references to it.
* `documentBrowser(documentBrowser: DocumentBrowserController, didRenameDocumentAtURL url: NSURL, to: String)` informs the delegate of name changes to documents. A change in name results in a change of path as well, as such references to the location of the document should get updated and if the document name is being displayed in the UI it should be updated.



##Known Issues##
* If the user creates a document in iCloud they will not be able to delete it right away, an unknown amount of time has to pass before it will stay deleted.


##Planned Improvements##
* Addition of an option to share via e-mail to the action sheet that appears with the long press gesture.
* Addition of an option to share via AirDrop to the action sheet that appears with the long press gesture.
* Addition of an option to share an iCloud link for documents in iCloud to the action sheet that appears with the long press gesture.