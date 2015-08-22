//
//  DocumentCollectionViewCell.swift
//  ShapeEdit
//

import UIKit

protocol DocumentCollectionViewCellDelegate {
    func presentActionSheet(sheet: UIAlertController, forCell cell:UICollectionViewCell)
    func presentAlert(alert:UIAlertController)
    func documentMovedFromPath(origin: String, toPath dest:String)
}


class DocumentCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var iconView: UIImageView!
	@IBOutlet weak var documentName: UILabel!
	@IBOutlet weak var documentLocation: UILabel!
	@IBOutlet weak var lastOpened: UILabel!
	private var documentNameTextField: UITextField! // For getting the new name for a document
    var delegate: DocumentCollectionViewCellDelegate!
	var thumbnailImage: UIImage! {
	    didSet {
	        if thumbnailImage != nil {
	            iconView.image = thumbnailImage
	        }
	    }
	}
	var document:ModelObject! {
        willSet {
            if document != nil {
                NSNotificationCenter.defaultCenter().removeObserver(self)
            }
        }
        didSet {
	        if document != nil {
	            documentName.text = document.displayName
	            documentLocation.text = document.subtitle
                lastOpened.text = document.lastAccessed
	        }
	    }
	}
    // System tells us about the gesture twice for a single long press, this means we make two action sheets unless we stop ourselves.
    var handlingGesture = false
	
	required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let selectedView = UIImageView(frame: self.bounds)
        selectedView.image = UIImage(named: "Selection")
        selectedView.alpha = 0.3
        self.selectedBackgroundView = selectedView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture")
        self.addGestureRecognizer(longPressGesture)
    }
    
    func newName(note: NSNotification) {
        documentName.text = document.displayName
    }
	
	func handleLongPressGesture() {
        if !handlingGesture {
            handlingGesture = true
            let optionsSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            optionsSheet.addAction(cancelAction())
            optionsSheet.addAction(renameAction())
            // TODO: add action for emailing document
            // TODO: add action for sharing by AirDrop
            let fileManager = NSFileManager.defaultManager()
            if fileManager.isUbiquitousItemAtURL(document.URL) {
                // TODO: add action for sharing iCloud link if document is in iCloud
//                fileManager.URLForPublishingUbiquitousItemAtURL(document.URL, expirationDate: <#T##AutoreleasingUnsafeMutablePointer<NSDate?>#>)
            }
            delegate?.presentActionSheet(optionsSheet, forCell: self)
        }
    }
	
	func cancelAction() -> UIAlertAction {
        let title = NSLocalizedString("Cancel", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Cancel", comment: "For canceling the displayed alert.")
        return UIAlertAction(title: title, style: .Cancel, handler: { (action) -> Void in self.handlingGesture = false })
	}
	
	func renameAction() -> UIAlertAction {
        let actionTitle = NSLocalizedString("Rename…", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Rename…", comment: "Title of action to rename the selected document.")
        let action = UIAlertAction(title: actionTitle, style: .Default,
            handler: { (action) -> Void in
                self.handlingGesture = false
                let currentFilename = self.documentName.text
                let title = NSString(format: NSLocalizedString("Rename %@", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Rename %@", comment: "Title of alert asking the user for the new name of the document."), currentFilename!) as String
                let message = NSString(format: NSLocalizedString("Enter a new name for %@.", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Enter a new name for %@.", comment: "Message of alert asking the user for the new name of the document."), currentFilename!) as String
                let renameAlert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
                renameAlert.addTextFieldWithConfigurationHandler(
                    {(textField: UITextField!) in
                        textField.placeholder = currentFilename
                        textField.clearButtonMode = .WhileEditing
                        self.documentNameTextField = textField
                })
                renameAlert.addAction(self.cancelAction())
                let renameTitle = NSLocalizedString("Rename", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Rename", comment: "Title of button to confirm renaming of the selected document.")
                renameAlert.addAction(UIAlertAction(title: renameTitle,
                    style: .Default, handler: { (action) -> Void in
                        let originPath = self.document.URL.path!
                        var destPath = (originPath as NSString).stringByDeletingLastPathComponent
                        let destName = self.documentNameTextField.text
                        if destName == nil || destName == "" { return }
                        destPath = (destPath as NSString).stringByAppendingPathComponent(destName!)
                        destPath = (destPath as NSString).stringByAppendingPathExtension((originPath as NSString).pathExtension)!
                        if NSFileManager.defaultManager().fileExistsAtPath(destPath) {
                            self.fileExistsAtPath(destPath)
                        } else {
                            dispatch_async(dispatch_get_global_queue(
                                DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                                    self.moveDocumentAtPath(originPath, toPath: destPath)
                            })
                        }
                }))
                self.delegate?.presentAlert(renameAlert)
        })
        return action
	}
	
	func fileExistsAtPath(existingPath: String) {
        var name = (existingPath as NSString).lastPathComponent as NSString
        name = name.stringByDeletingPathExtension
        let title = NSLocalizedString("Document Already Exists!", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Document Already Exists!", comment: "Title of alert informing the user the name they have chosen for the document already exists.")
        let message = NSString(format: NSLocalizedString("A document named, %@, already exists…", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "A document named, %@, already exists…", comment: "Message of alert informing the user the name they have chosen for the document already exists."), name) as String
        let replaceTitle = NSLocalizedString("Replace", tableName: kDocumentBrowserStringTable, bundle: NSBundle.mainBundle(), value: "Replace", comment: "Title of button to confirm replacing the document with the previously entered name.")
        let fileExistsAlert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        fileExistsAlert.addAction(UIAlertAction(title: replaceTitle, style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            let fileCoordinator = NSFileCoordinator(filePresenter: nil)
            var error: NSError?
//            let destURL = NSURL(string: existingPath.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)!
            let destURL = NSURL(string: existingPath.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet())!)!
            fileCoordinator.coordinateWritingItemAtURL(destURL, options: .ForDeleting, error: &error, byAccessor: { (destURL) -> Void in
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(existingPath as String)
                } catch _ {
                }
            })
            dispatch_async(dispatch_get_global_queue(
                DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                    self.moveDocumentAtPath(self.document.URL.path!, toPath: existingPath)
            })
        }))
        fileExistsAlert.addAction(self.cancelAction())
        delegate?.presentAlert(fileExistsAlert)
	}
	
	func moveDocumentAtPath(originPath: String, toPath: String) {
	    let fileCoordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?
        let originURL = NSURL(string: originPath.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet())!)!
        fileCoordinator.coordinateWritingItemAtURL(originURL,
            options: .ForMoving, error: &error,
            byAccessor: { (originURL) -> Void in
            do {
                try NSFileManager.defaultManager().moveItemAtPath(originPath as String, toPath: toPath as String)
            } catch {
                NSLog("Failed to move document from path \(originPath) to path \(toPath): error \(error)")
            }
            self.delegate.documentMovedFromPath(originPath, toPath: toPath)
        })
	}
}
