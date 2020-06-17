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
  public func whenAvailable(closure: @escaping () -> ()) {
    self.availableClosure = closure
  }
  public var isAvailable: Bool {
    get { return image != nil }
    set { if newValue { availableClosure?() } }
  }
  public func onHighResImgNeeded(zoomFactor: CGFloat, closure: @escaping
    (@escaping (UIImage?) -> ()) -> ()) {}  
  public func onTap(closure: @escaping (Double, Double) -> ()) {}
}

public class ContentImageVC: ImageCollectionVC, CanRotate {
  
  /// The Content whoose images are to display
  var content: Content
  /// The name of the image that has been tapped
  var imageTapped: String?
  /// The delegate providing Issue infos
  var delegate: IssueInfo
  /// The ZoomedImage
  var image: ZoomedImage?
  /// Show an image gallery if available
  var showImageGallery = true
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  
  /// Create a ZoomedImage from a pair of images
  private func zoomedImage(pair: (normal: ImageEntry?, high: ImageEntry?)) -> ZoomedImage? {
    guard let normal = pair.normal else { return nil }
    let image = ZoomedImage()
    let path = delegate.feeder.issueDir(issue: delegate.issue).path
    image.waitingImage = UIImage(contentsOfFile: "\(path)/\(normal.fileName)")
    if let high = pair.high {
      delegate.dloader.downloadIssueFiles(issue: delegate.issue, files: [high]) 
      { err in
        if err == nil { 
          image.image = UIImage(contentsOfFile: "\(path)/\(high.fileName)")
        } else { image.image = image.waitingImage }
        self.debug("image \(high.fileName): \(image.image!.size)")
        image.isAvailable = true 
      }
    }
    else { image.image = image.waitingImage }
    return image
  } 
  
  /// Create a ZoomedImage from an image file name
  private func zoomedImage(fname: String) -> ZoomedImage? {
    let image = ZoomedImage()
    let path = delegate.feeder.issueDir(issue: delegate.issue).path
    let highRes = StoredImageEntry.highRes(fname)
    if File("\(path)/\(highRes)").exists {
      image.image = UIImage(contentsOfFile: "\(path)/\(highRes)")
    }
    else { image.image = UIImage(contentsOfFile: "\(path)/\(fname)") }
    image.isAvailable = true 
    return image
  }
  
  /// Create a ZoomedImage from a content and an image name
  private func zoomedImage(content: Content, name: String) -> ZoomedImage? {
    let pdict = content.photoDict
    let pref = StoredImageEntry.prefix(name)
    if let pair = pdict[pref] { return zoomedImage(pair: pair) }
    else { return nil }
  }
  
  /// Create ZoomedImages for all images of a content
  private func zoomedImages(content: Content) -> [ZoomedImage] {
    content.photoPairs.map { zoomedImage(pair: $0) }.filter { $0 != nil } as! [ZoomedImage]
  }
  
  /// Create ZoomedImages for all images of a content, load tapped image first
  private func zoomedImages(content: Content, name: String) -> 
    (Int, [ZoomedImage]) {
    var ret: [ZoomedImage] = []
    var idx: Int = -1
    if let tapped = zoomedImage(content: content, name: name) {
      for (i,pair) in content.photoPairs.enumerated() {
        if pair.normal?.fileName == name { ret += tapped; idx = i }
        else { if let zimg = zoomedImage(pair: pair) { ret += zimg } }
      }
    }
    if idx < 0 { 
      if let zimg = zoomedImage(fname: name) { ret += zimg }
      idx = ret.count - 1
    }
    return (idx, ret)
  }
  
  private func popVC(setPortrait: Bool = false) {
    if setPortrait {
      let portrait = UIInterfaceOrientation.portrait.rawValue
      UIDevice.current.setValue(portrait, forKey: "orientation")
    }
    self.navigationController?.popViewController(animated: false)
  }
  
  private func setupImageView() {
    guard let img = self.imageTapped else { popVC(); return }      
    let pdict = content.photoDict
    let pref = StoredImageEntry.prefix(img)
    if let pair = pdict[pref] { image = zoomedImage(pair: pair) }
    guard let image = self.image else { popVC(); return }
    let imageView = ZoomedImageView(optionalImage: image)
    self.view.addSubview(imageView)
    pin(imageView, to: self.view)
    imageView.onX { self.popVC(setPortrait: true) }
  }
  
  private func exportImage() {
    if let img = self.images[self.index!] as? ZoomedImage {
      let dialogue = ExportDialogue<Any>()
      dialogue.present(item: img.image!, subject: "Bild")
    }
  }
  
  private func setupImageCollectionVC() {
    if let img = self.imageTapped { 
      if showImageGallery {
        let (n,images) = zoomedImages(content: self.content, name: img)
        self.images = images
        self.index = n
      }
      else {
        if let image = zoomedImage(content: self.content, name: img) {
          self.images = [image]
          self.index = 0
        }
      }
    }
    else { 
      self.images = zoomedImages(content: self.content)
      self.index = 0
    }
    self.onX { self.popVC(setPortrait: true) }
    self.addMenuItem(title: "Bild Teilen", icon: "square.and.arrow.up") { title in
      self.exportImage()
    }
    self.addMenuItem(title: "Abbrechen", icon: "xmark.circle") {_ in}
  }
  
  public init(content: Content, delegate: IssueInfo, imageTapped: String? = nil) {
    self.content = content
    self.delegate = delegate
    self.imageTapped = imageTapped
    super.init() 
    super.pinTopToSafeArea = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setupImageCollectionVC()
//    setupImageView()
  }
    
} // ContentImageVC
