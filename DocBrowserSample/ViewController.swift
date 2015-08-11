//
//  ViewController.swift
//  DocBrowserSample
//
//  Created by Mike Swan on 7/28/15.
//  Copyright © 2015 theMikeSwan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, DocumentBrowserDelegate {
    @IBOutlet weak var textView: UITextView!
    var document: Document?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if document == nil {
            textView.attributedText = NSAttributedString(string: "")
            textView.userInteractionEnabled = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - DocumentBrowserDelegate functions
    func documentBrowser(documentBrowser: DocumentBrowserController, didPickURL url: NSURL) {
        if document != nil {
            saveDocument()
            document?.closeWithCompletionHandler(nil)
        }
        document = Document(fileURL: url)
        document?.openWithCompletionHandler({ (success) -> Void in
            if success {
                let vc = self.presentedViewController as! DocumentBrowserController
                vc.documentWasOpenedSuccessfullyAtURL(url)
                self.textView.attributedText = self.document!.contentString
                self.textView.userInteractionEnabled = true
                self.dismissViewControllerAnimated(true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Open Failed", message: "Failed to open the selected document", preferredStyle: UIAlertControllerStyle.Alert)
                self.presentViewController(alert, animated: true, completion: nil)
            }
        })
    }
    
    func documentBrowser(documentBrowser: DocumentBrowserController, willDeleteDocumentAtURL urlToDelete: NSURL) {
        if urlToDelete == document?.fileURL {
            document?.closeWithCompletionHandler({ (_) -> Void in
                self.textView.attributedText = NSAttributedString(string: "")
                self.textView.userInteractionEnabled = false
                self.document = nil
            })
        }
    }
    
    func allowedFileExtensionsForDocumentBrowser(documentBrowser: DocumentBrowserController) -> [String] {
        return ["rtf"]
    }
    
    func createDocumentAtURL(url: NSURL) {
        let newDocument = Document(fileURL: url)
        newDocument.contentString = NSAttributedString(string: "")
        newDocument.saveToURL(url, forSaveOperation: .ForCreating, completionHandler: { (success) in
            if !success {
                NSLog("File creation FAILED at \(url)!")
                // TODO: Let user know creation failed
            } else {
                let vc = self.presentedViewController as! DocumentBrowserController
                vc.documentCreationComplete()
            }
        })
    }
    
    // MARK: - Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDocumentBrowser" {
            saveDocument()
            let vc = segue.destinationViewController as! DocumentBrowserController
            vc.delegate = self
        }
    }
    
    func saveDocument() {
        if document != nil {
            document?.contentString = textView.attributedText
            document?.saveToURL((document?.fileURL)!, forSaveOperation: UIDocumentSaveOperation.ForOverwriting, completionHandler: { (success) -> Void in
                if !success {
                    print("error saving document.")
                }
            })
//            document?.savePresentedItemChangesWithCompletionHandler({ (error) -> Void in
//                if error != nil {
//                    NSLog("Error saving file \(error)")
//                }
//            })
        }
    }

}

