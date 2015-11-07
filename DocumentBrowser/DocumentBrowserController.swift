/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Originally written by Apple Inc. 2015
    Modified by Mike Swan June 2015

    Abstract:
    This is the `DocumentBrowserController` which handles display of all elements of the Document Browser.  It listens for notifications from the `DocumentBrowserQuery` and `ThumbnailCache` and updates the `UICollectionView` for the Document Browser when events
                occur.
*/

/// Errors used throughout TMSDocumentBrowser
enum DocumentBrowserError: ErrorType {
    case BookmarkResolveFailed
    case ThumbnailLoadFailed
}

import UIKit

/** 
    The `DocumentBrowserDelegate` protocol…
*/
@objc protocol DocumentBrowserDelegate : NSObjectProtocol {
    /// Used to inform the delegate the document browser was cancelled by the user.
    optional func documentBrowserDidCancel(documentBrowser: DocumentBrowserController)
    /// Used to inform the delegate what document was chosen so that it can be opened or other action can be taken.
    func documentBrowser(documentBrowser: DocumentBrowserController, didPickURL url: NSURL)
    /// Used to inform the delegate when a document is about to be deleted so that it can be closed before deletion.
    optional func documentBrowser(documentBrowser: DocumentBrowserController, willDeleteDocumentAtURL urlToDelete: NSURL)
    /// Used to inform the delegate that a particular document has been renamed, and as a result moved to a new path, so that any references to the path or name can be updated.
    optional func documentBrowser(documentBrowser: DocumentBrowserController, didRenameDocumentAtURL url: NSURL, to: String)
    /// Called when the user has choosen to create a new document. The passed in url will include the filename and use the first file extension from allowedFileExtensionsForDocumentBrowser().
    func createDocumentAtURL(url: NSURL)
    /// Should provide a string array with all file extensions that should be displayed in the browser.
    func allowedFileExtensionsForDocumentBrowser(documentBrowser: DocumentBrowserController) -> [String]
}

/**
    The `DocumentBrowserController` registers for notifications from the `ThumbnailCache`
    and the `DocumentBrowserQuery` and updates the UI for changes.  It also handles
    pushing the `DocumentViewController` when a document is selected.
*/
class DocumentBrowserController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, DocumentBrowserQueryDelegate, RecentModelObjectsManagerDelegate, ThumbnailCacheDelegate, DocumentCollectionViewCellDelegate {
    // MARK: Properties
    
    static let recentsSection = 0
    static let documentsSection = 1
    var documents = [DocumentBrowserModelObject]()
    var recents = [RecentModelObject]()
    var browserQuery = DocumentBrowserQuery()
    let recentsManager = RecentModelObjectsManager()
    let thumbnailCache = ThumbnailCache(thumbnailSize: CGSize(width: 220, height: 270))
    @IBInspectable var allowedExtensions :[String]!
    @IBOutlet var deleteButton: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var collectionView: UICollectionView!
    var doneButton = UIBarButtonItem()
    weak var delegate: DocumentBrowserDelegate!
    
    private let coordinationQueue: NSOperationQueue = {
        let coordinationQueue = NSOperationQueue()
        
        coordinationQueue.name = "com.theMikeSwan.TMSDocumentBrowser.documentbrowser.coordinationQueue"
        
        return coordinationQueue
    }()
    
    func usingiCloud() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(kUseiCloud) == true && NSFileManager.defaultManager().ubiquityIdentityToken != nil
    }
    
    // MARK: View Controller Override
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if usingiCloud() {
            browserQuery.startQuery()
            browserQuery.delegate = self
        } else {
            configureForLocal()
        }
        
        // Initialize ourself as the delegate of our created queries.
        
        thumbnailCache.delegate = self
        
        recentsManager.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "toggleEditing:")
        var buttons = toolbar.items
        guard let index = buttons?.indexOf(deleteButton) else { return }
        buttons?.removeAtIndex(index)
        toolbar.setItems(buttons, animated: false)
        setupConstraints()
    }
    
    /// Just here to deal with some strange constraint issues
    func setupConstraints() {
        let viewDict = ["toolbar":toolbar, "collectionView":collectionView]
        let verticalString = "V:|-20-[toolbar]-0-[collectionView]-0-|"
        let horizontalString = "H:|-0-[toolbar]-0-|"
        let verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(verticalString, options: NSLayoutFormatOptions.AlignAllLeading, metrics: nil, views: viewDict)
        let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat(horizontalString, options: NSLayoutFormatOptions.AlignAllLeading, metrics: nil, views: viewDict)
        let collectionViewHConstraints = NSLayoutConstraint.constraintsWithVisualFormat(String(stringLiteral: "H:|-0-[collectionView]-0-|"), options: NSLayoutFormatOptions.AlignAllLeading, metrics: nil, views: viewDict)
        view.removeConstraints(view.constraints)
        toolbar.removeConstraints(toolbar.constraints)
        collectionView.removeConstraints(collectionView.constraints)
        view.addConstraints(verticalConstraints)
        view.addConstraints(horizontalConstraints)
        view.addConstraints(collectionViewHConstraints)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if usingiCloud() {
            browserQuery.resumeQuery()
        } else {
            configureForLocal()
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        if usingiCloud() {
            browserQuery.pauseQuery()
        }
    }
    
    @IBAction func insertNewObject(sender: UIBarButtonItem) {
        var url = NSURL()
        if usingiCloud() {
            let appDelegate = UIApplication.sharedApplication().delegate as! TMSMobileAppDelegate
            url = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(appDelegate.iCloudContainerID())!
            url = url.URLByAppendingPathComponent("Documents", isDirectory: true)
            url = freeDocumentURLInDirectory(url)
            var tempURL = NSURL.fileURLWithPath(NSTemporaryDirectory())
            tempURL = tempURL.URLByAppendingPathComponent(url.lastPathComponent!)
            delegate?.createDocumentAtURL(tempURL)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                do {
                    try NSFileManager.defaultManager().setUbiquitous(true, itemAtURL: tempURL, destinationURL: url)
                } catch {
                    NSLog("Error moving document to iCloud: \(error)")
                }
            })
        } else {
            url = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
            url = freeDocumentURLInDirectory(url)
            delegate?.createDocumentAtURL(url)
            configureForLocal()
        }
    }
    
    func freeDocumentURLInDirectory(directory: NSURL) -> NSURL {
        let filemanager = NSFileManager.defaultManager()
        let newDocName = NSLocalizedString("Untitled", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Untitled", comment: "Default name for untitled documents")
        var url = directory.URLByAppendingPathComponent(newDocName)
        url = url.URLByAppendingPathExtension(delegate.allowedFileExtensionsForDocumentBrowser(self)[0])
        if !filemanager.fileExistsAtPath(url.path!) {
            return url
        }
        var i = 2
        var done = false
        while !done {
            let testName = newDocName.stringByAppendingFormat(" %i", i)
            url = directory.URLByAppendingPathComponent(testName)
            url = url.URLByAppendingPathExtension(delegate.allowedFileExtensionsForDocumentBrowser(self)[0])
            let fileExists = filemanager.fileExistsAtPath(url.path!)
            if fileExists { i++ }
            else { done = true }
        }
        return url
    }
    
    func configureForLocal() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let localDocuments = NSMutableArray()
            let allowedExtensions = self.delegate.allowedFileExtensionsForDocumentBrowser(self)
            let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
            do {
                let localResults = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path as String) as [String]
            for result in localResults {
                let url = NSURL(fileURLWithPath: path.stringByAppendingPathComponent(result))
                if allowedExtensions.contains(url.pathExtension!) {
                    localDocuments.addObject(DocumentBrowserModelObject(url: url))
                }
                
            }
            self.documents = (localDocuments.copy() as! [DocumentBrowserModelObject])
            self.collectionView?.reloadData()

            } catch {
                NSLog("Error getting local documents \(error)")
            }
        })
    }
    
    // MARK: DocumentBrowserQueryDelegate

    func documentBrowserQueryResultsDidChangeWithResults(results: [DocumentBrowserModelObject], animations: [DocumentBrowserAnimation]) {
        if animations == [.Reload] {
            /*
                Reload means we're reloading all items, so mark all thumbnails
                dirty and reload the collection view.
            */
            documents = results
            thumbnailCache.markThumbnailCacheDirty()
            collectionView?.reloadData()
        }
        else {
            var indexPathsNeedingReload = [NSIndexPath]()
            
            let collectionView = self.collectionView!

            collectionView.performBatchUpdates({
                /*
                    Perform all animations, and invalidate the thumbnail cache 
                    where necessary.
                */
                indexPathsNeedingReload = self.processAnimations(animations, oldResults: self.documents, newResults: results, section: DocumentBrowserController.documentsSection)

                // Save the new results.
                self.documents = results
            }, completion: { success in
                if success {
                    collectionView.reloadItemsAtIndexPaths(indexPathsNeedingReload)
                }
            })
        }
    }

    // MARK: RecentModelObjectsManagerDelegate
    
    func recentsManagerResultsDidChange(results: [RecentModelObject], animations: [DocumentBrowserAnimation]) {
        if animations == [.Reload] {
            recents = results
            
            let indexSet = NSIndexSet(index: DocumentBrowserController.recentsSection)

            collectionView?.reloadSections(indexSet)
        }
        else {
            var indexPathsNeedingReload = [NSIndexPath]()

            let collectionView = self.collectionView!
            collectionView.performBatchUpdates({
                /*
                    Perform all animations, and invalidate the thumbnail cache 
                    where necessary.
                */
                indexPathsNeedingReload = self.processAnimations(animations, oldResults: self.recents, newResults: results, section: DocumentBrowserController.recentsSection)

                // Save the results
                self.recents = results
            }, completion: { success in
                if success {
                    collectionView.reloadItemsAtIndexPaths(indexPathsNeedingReload)
                }
            })
        }
    }
    
    // MARK: Animation Support
// TODO: find the issue around this code and kill it! Deleting documents keeps causing issues with range exceptions on the old results.
    private func processAnimations<ModelType: ModelObject>(animations: [DocumentBrowserAnimation], oldResults: [ModelType], newResults: [ModelType], section: Int) -> [NSIndexPath] {
        let collectionView = self.collectionView!
        
        var indexPathsNeedingReload = [NSIndexPath]()
        
        for animation in animations {
            switch animation {
                case .Add(let row):
                    if section == DocumentBrowserController.recentsSection {
                        collectionView.insertItemsAtIndexPaths([ NSIndexPath(forRow: row, inSection: section) ])
                    } else {
                        collectionView.insertItemsAtIndexPaths([ NSIndexPath(forRow: (row + 1), inSection: section) ])
                    }
                
                case .Delete(let row):
                    if section == DocumentBrowserController.recentsSection {
                        collectionView.deleteItemsAtIndexPaths([
                            NSIndexPath(forRow: row, inSection: section)
                            ])
                        
                        let URL = oldResults[row].URL
                        self.thumbnailCache.removeThumbnailForURL(URL)
                    } else {
                        collectionView.deleteItemsAtIndexPaths([
                            NSIndexPath(forRow: (row + 1), inSection: section)
                            ])
                        
                        let URL = oldResults[row].URL
                        self.thumbnailCache.removeThumbnailForURL(URL)
                    }
                
                    
                case .Move(let from, let to):
                    if section == DocumentBrowserController.recentsSection {
                        let fromIndexPath = NSIndexPath(forRow: from, inSection: section)
                        
                        let toIndexPath = NSIndexPath(forRow: to, inSection: section)
                        
                        collectionView.moveItemAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
                    } else {
                        let fromIndexPath = NSIndexPath(forRow: (from + 1), inSection: section)
                        
                        let toIndexPath = NSIndexPath(forRow: (to + 1), inSection: section)
                        
                        collectionView.moveItemAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
                    }
                
                
                case .Update(let row):
                    if section == DocumentBrowserController.recentsSection {
                        indexPathsNeedingReload += [
                            NSIndexPath(forRow: row, inSection: section)
                        ]
                        
                        let URL = newResults[row].URL
                        self.thumbnailCache.markThumbnailDirtyForURL(URL)
                    } else {
                        indexPathsNeedingReload += [
                            NSIndexPath(forRow: (row + 1),  inSection: section)
                        ]
                        
                        let URL = newResults[row].URL
                        self.thumbnailCache.markThumbnailDirtyForURL(URL)
                    }
                    
                    
                case .Reload:
                    fatalError("Unreachable")
            }
        }
        
        return indexPathsNeedingReload
    }

    // MARK: ThumbnailCacheDelegateType
    
    func thumbnailCache(thumbnailCache: ThumbnailCache, didLoadThumbnailsForURLs URLs: Set<NSURL>) {
        let documentPaths: [NSIndexPath] = URLs.flatMap { URL in
            guard let matchingDocumentIndex = documents.indexOf({ $0.URL == URL }) else { return nil }
            
            return NSIndexPath(forItem: matchingDocumentIndex, inSection: DocumentBrowserController.documentsSection)
        }
        
        let recentPaths: [NSIndexPath] = URLs.flatMap { URL in
            guard let matchingRecentIndex = recents.indexOf({ $0.URL == URL }) else { return nil }
            
            return NSIndexPath(forItem: matchingRecentIndex, inSection: DocumentBrowserController.recentsSection)
        }
        
        self.collectionView!.reloadItemsAtIndexPaths(documentPaths + recentPaths)
    }

    // MARK: - Collection View

     func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 2
    }

     func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == DocumentBrowserController.recentsSection {
            return recents.count
        }

        return documents.count + 1
    }

     func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell = UICollectionViewCell()
        if indexPath.section == DocumentBrowserController.documentsSection && indexPath.row == 0 {
            cell = collectionView.dequeueReusableCellWithReuseIdentifier("newDocCell", forIndexPath: indexPath)
        } else {
            let docCell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! DocumentCollectionViewCell
            
            let document = documentForIndexPath(indexPath)
            docCell.document = document
            docCell.thumbnailImage = thumbnailCache.loadThumbnailForURL(document.URL)
            docCell.delegate = self
            cell = docCell
        }
        return cell
    }

     func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionHeader, withReuseIdentifier: "Header", forIndexPath: indexPath) as! HeaderView

            let recent = NSLocalizedString("Recently Viewed", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Recently Viewed", comment: "Title for header of recently viewed documents")
            let all = NSLocalizedString("All Documents", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "All Documents", comment: "Title for header of all documents section")
            header.title = indexPath.section == DocumentBrowserController.recentsSection ? recent : all
            
            return header
        }

        return UICollectionReusableView()
    }
    
     func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection == true {
            if indexPath == NSIndexPath(forItem: 0, inSection: DocumentBrowserController.documentsSection) {
                collectionView.deselectItemAtIndexPath(indexPath, animated: false)
            } else {
                deleteButton.enabled = true
            }
        } else {
            if indexPath.section == DocumentBrowserController.documentsSection && indexPath.row == 0 {
                insertNewObject(UIBarButtonItem())
            } else {
                let document = documentForIndexPath(indexPath)
                delegate.documentBrowser(self, didPickURL: document.URL)
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection == true && !(collectionView.indexPathsForSelectedItems()!.count > 0) {
            deleteButton.enabled = false
        }
    }
    
     func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        // If its the new document cell there is no document for it
        if indexPath.section == DocumentBrowserController.documentsSection && indexPath.row == 0 {
            return
        }
        // If the last document in a section was deleted we may get a strane row index that is out of bounds…
        if indexPath.section == DocumentBrowserController.documentsSection && indexPath.row >= documents.count {
            return
        }
        if indexPath.section == DocumentBrowserController.recentsSection && indexPath.row >= recents.count {
            return
        }
        
        let document = documentForIndexPath(indexPath)
        var indexPaths = collectionView.indexPathsForVisibleItems()
        let pathToRemove = NSIndexPath(forRow: 0, inSection: DocumentBrowserController.documentsSection)
        if indexPaths.contains(pathToRemove) {
            let x = indexPaths.indexOf(pathToRemove)!
            indexPaths.removeAtIndex(x)
        }
        var indexPathsCopy = indexPaths
        for y in indexPaths {
            switch y.section {
            case DocumentBrowserController.recentsSection:
                if y.row >= recents.count {
                    let z = indexPathsCopy.indexOf(y)!
                    indexPathsCopy.removeAtIndex(z)
                }
            case DocumentBrowserController.documentsSection:
                if y.row >= documents.count {
                    let z = indexPathsCopy.indexOf(y)!
                    indexPathsCopy.removeAtIndex(z)
                }
                
            default:
                fatalError("Unknown section.")
            }
        }
        indexPaths = indexPathsCopy
        
        let visibleURLs: [NSURL] = indexPaths.map { indexPath in
            
            let document = documentForIndexPath(indexPath)
            
            return document.URL
        }
        
        if !visibleURLs.contains(document.URL) {
            thumbnailCache.cancelThumbnailLoadForURL(document.URL)
        }
    }

    
    // MARK: Document handling support
    
    private func documentBrowserModelObjectForURL(url: NSURL) -> DocumentBrowserModelObject? {
        guard let matchingDocumentIndex = documents.indexOf({ $0.URL == url }) else { return nil }
        
        return documents[matchingDocumentIndex]
    }

    private func documentForIndexPath(indexPath: NSIndexPath) -> ModelObject {
        if indexPath.section == DocumentBrowserController.recentsSection {
            return recents[indexPath.row]
        }
        else if indexPath.section == DocumentBrowserController.documentsSection {
            return documents[indexPath.row - 1]
        }

        fatalError("Unknown section.")
    }
    
    // MARK: - Document Opening
    /// The delegate should call back to this function upon successfully opening the chosen document to add it to the recents list
    func documentWasOpenedSuccessfullyAtURL(URL: NSURL) {
        NSUserDefaults.standardUserDefaults().setObject(URL.absoluteString, forKey: kCurrentDocument)
        recentsManager.addURLToRecents(URL)
    }
    
    /// The delegate should call back to this function when the document has been created
    func documentCreationComplete() {
        if !usingiCloud() {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.configureForLocal()
            })
        }
    }
    
    // MARK: - Navigation
    
    @IBAction func closeBrowser(sender: UIBarButtonItem) {
        delegate?.documentBrowserDidCancel?(self)
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Editing
    @IBAction func toggleEditing(sender: AnyObject) {
        editing = !editing
        super.setEditing(editing, animated: true)
        var replacementButton = doneButton
        var replacementIndex = 0
        var buttons = toolbar.items!
        if editing {
            deleteButton.enabled = false
            buttons.insert(deleteButton, atIndex: 0)
            replacementIndex = buttons.indexOf(editButton)!
            collectionView?.allowsMultipleSelection = true
        } else {
            let deleteIndex = buttons.indexOf(deleteButton)!
            buttons.removeAtIndex(deleteIndex)
            replacementIndex = buttons.indexOf(doneButton)!
            replacementButton = editButton
            collectionView?.allowsMultipleSelection = false
            guard let indexPaths = collectionView?.indexPathsForSelectedItems() else { return }
            if indexPaths.count > 0 {
                collectionView!.deselectItemAtIndexPath(indexPaths[0], animated: false)
            }
        }
        buttons[replacementIndex] = replacementButton
        toolbar.setItems(buttons as [UIBarButtonItem], animated: true)
    }
    
    @IBAction func deleteItems(sender: AnyObject) {
        guard var selectedPaths = collectionView?.indexPathsForSelectedItems() else { return }
        let alertTitle = NSLocalizedString("Delete File(s)", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Delete File(s)", comment: "Title of alert asking for confirmation of file deletion.")
        let cancelTitle = NSLocalizedString("Cancel", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Cancel", comment: "Button title for canceling an alert.")
        let deleteTitle = NSLocalizedString("Delete", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Delete", comment: "Button title to confirm deletion of documents.")
        let deleteMessage = String(format: NSLocalizedString("Are you sure you want to delete %i file(s)?", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Are you sure you want to delete %i file(s)?", comment: "Message of document deletion confirmation."), selectedPaths.count)
        
        let deleteAlert = UIAlertController(title: alertTitle, message: deleteMessage, preferredStyle: UIAlertControllerStyle.Alert)
        deleteAlert.addAction(UIAlertAction(title: cancelTitle, style: .Cancel) { (_) in })
        deleteAlert.addAction(UIAlertAction(title: deleteTitle, style: .Destructive, handler: { (action) -> Void in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                // Make a copy of the documents to prevent shifting index issues
                var removedARecentDoc = false
                let tempDocs = NSMutableArray(array: self.documents)
                let tempRecents = NSMutableArray(array: self.recents)
                let indexesToRemove = [] as NSMutableArray
                for indexPath in selectedPaths {
                    let fileCoordinator = NSFileCoordinator(filePresenter: nil)
                    var objectToDelete: ModelObject
                    if indexPath.section == DocumentBrowserController.recentsSection {
                        objectToDelete = tempRecents[indexPath.row] as! ModelObject
                    } else {
                        objectToDelete = self.documents[indexPath.row - 1] as ModelObject
                    }
                    let urlToDelete = objectToDelete.URL
                    
                    // If the thumbnail is still being loaded we should stop.
                    self.thumbnailCache.cancelThumbnailLoadForURL(urlToDelete)
                    self.delegate?.documentBrowser?(self, willDeleteDocumentAtURL: urlToDelete)
                    fileCoordinator.coordinateWritingItemAtURL(urlToDelete, options: NSFileCoordinatorWritingOptions.ForDeleting, error: nil, byAccessor: { (url) -> Void in
                        do {
                            try NSFileManager.defaultManager().removeItemAtURL(url)
                        } catch {
                            NSLog("Unable to remove document at url: \(url). Error: \(error)")
                        }
                    })
                    if indexPath.section == DocumentBrowserController.documentsSection {
                        tempDocs.removeObject(objectToDelete)
                    } else {
                        indexesToRemove.addObject(selectedPaths.indexOf(indexPath)!)
                        removedARecentDoc = true
                    }
                }
                
                self.documents = (tempDocs as AnyObject as! [DocumentBrowserModelObject])
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if !self.usingiCloud(){
                        for i in indexesToRemove {
                            selectedPaths.removeAtIndex(i as! Int)
                        }
                        self.collectionView!.deleteItemsAtIndexPaths(selectedPaths)
                        // If we removed a recent document we need to reload the collection view to catch the change
                        if removedARecentDoc {
                            self.configureForLocal()
                        }
                    }
                    self.toggleEditing(NSObject())
                })
            })
        }))
        presentViewController(deleteAlert, animated: true, completion: nil)
    }
    
    // MARK: - DocumentCollectionViewCell
    func presentActionSheet(sheet: UIAlertController, forCell cell: UICollectionViewCell) {
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            let sheetController = sheet
            sheetController.modalPresentationStyle = UIModalPresentationStyle.Popover
            let popoverController = sheetController.popoverPresentationController
            popoverController?.sourceView = cell
            popoverController?.sourceRect = cell.bounds
            presentViewController(sheetController, animated: true, completion: nil)
        } else {
            presentViewController(sheet, animated: true, completion: nil)
        }
    }
    
    func presentAlert(alert: UIAlertController) {
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func documentMovedFromPath(origin: String, toPath dest: String) {
        if !usingiCloud() {
            configureForLocal()
        }
        delegate?.documentBrowser?(self, didRenameDocumentAtURL: NSURL(string: origin)!, to: (dest as NSString).lastPathComponent)
    }
    
    func allowedFileExtensions() -> [String] {
        return delegate.allowedFileExtensionsForDocumentBrowser(self)
    }
}
