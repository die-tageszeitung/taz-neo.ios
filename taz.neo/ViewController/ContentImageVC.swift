//
//  ContentImageVC.swift
//
//  Created by Norbert Thies on 29.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class ZoomedImage: OptionalImage {
  /// The main image to display
  public var image: UIImage?
  /// An alternate image to display when the main image is not yet available
  public var waitingImage: UIImage?
  /// Returns true if 'image' is available
  private var availableClosure: (()->())?
  /// Defines a closure to call when the main image becomes available
  public func whenAvailable(closure: @escaping ()->()) {
    self.availableClosure = closure
  }
  public var isAvailable: Bool {
    get { return image != nil }
    set { if newValue { availableClosure?() } }
  }
}
/// WARNING Changing the DeviceOrientation manually results in unexpected behaviour in ZoomedImageView
public class ContentImageVC: UIViewController {
  
  /// The Content whoose images are to display
  var content: Content
  /// The name of the image that has been tapped
  var imageTapped: String?
  /// The delegate providing Issue infos
  var delegate: IssueInfo
  /// The ZoomedImage
  var image = ZoomedImage()
    
  private func setup() {
    guard let img = self.imageTapped else { return }
    let pdict = content.photoDict
    let pref = StoredImageEntry.prefix(img)
    if let pair = pdict[pref], let normal = pair.normal {
      let path = delegate.feeder.issueDir(issue: delegate.issue).path
      if let high = pair.high {
        image.waitingImage = UIImage(contentsOfFile: "\(path)/\(normal.fileName)")
        delegate.dloader.downloadIssueFiles(issue: delegate.issue, files: [high]) 
        { [weak self] err in
          guard let self = self else { return }
          if err == nil { 
            self.image.image = UIImage(contentsOfFile: "\(path)/\(high.fileName)")
          } else { self.image.image = self.image.waitingImage }
          self.image.isAvailable = true 
        }
      }
    }    
  }
  
  public init(content: Content, delegate: IssueInfo, imageTapped: String? = nil) {
    self.content = content
    self.delegate = delegate
    self.imageTapped = imageTapped
    super.init(nibName: nil, bundle: nil) 
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    guard image.waitingImage != nil else { 
      self.navigationController?.popViewController(animated: false)
      return
    }
    let imageView = ZoomedImageView(optionalImage: self.image, verifyInterfaceOrientationOnStart: true)
    self.view.addSubview(imageView)
    pin(imageView, to: self.view)
    imageView.onX {
      /// WARNING Changing the DeviceOrientation manually results in unexpected behaviour in ZoomedImageView
//      let portrait = UIInterfaceOrientation.portrait.rawValue
//      UIDevice.current.setValue(portrait, forKey: "orientation")
      self.navigationController?.popViewController(animated: false)
    }
  }
    
} // ContentImageVC
