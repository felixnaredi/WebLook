//
//  PreviewViewController.swift
//  QuickLookExtension
//
//  Created by Felix Naredi on 2019-04-23.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {

  override var nibName: NSNib.Name? {
    return NSNib.Name("PreviewViewController")
  }

  override func loadView() {
    super.loadView()
    // Do any additional setup after loading the view from its nib.
  }

  public func preparePreviewOfSearchableItem(
    identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void
  ) {
    // Perform any setup necessary in order to prepare the view.

    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.
    handler(nil)
  }

}
