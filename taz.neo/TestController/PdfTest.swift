//
//  PdfTest.swift
//
//  Created by Norbert Thies on 08.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// OptionalImage extension to use pdf's an renders the images from pdf
/// only used page 1 at index 0 by default
/// provides functionallity to render the image in requested zoom scale
class ZoomedPdfImage: OptionalImageItem, ZoomedPdfImageSpec {
  public private(set) var pdfFilename: String
  public private(set) var maxRenderingZoomScale: CGFloat
  private var pdfPage: PdfPage?
  
  func renderImageWithScale(scale: CGFloat) -> UIImage?{
    if scale > maxRenderingZoomScale { return nil }
    return pdfPage?.image(width: UIScreen.main.nativeBounds.width*scale)
  }
  //iPhone 6 iOS 12.2 crashes at 8x // iPhone X iOS 13 returns nil
  //at 4x iPhone 6 allocates 400MB Memory due Render Image (ScreenScale 2x!) if user requests 2nd Image Render App will crash
  public required init(pdfFilename: String, _ maxRenderingZoomScale : CGFloat = 4.0 ) {
    self.pdfFilename = pdfFilename
    self.maxRenderingZoomScale = maxRenderingZoomScale
    self.pdfPage = PdfDoc(fname: File(inMain: pdfFilename)!.path)[0]
  }
  
  required init(waitingImage: UIImage? = nil) {
    fatalError("init(waitingImage:) has not been implemented")
  }
}

class PdfTest: ImageCollectionVC, CanRotate {
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  
  var logView = TestView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    Log.minLogLevel = .Debug
    Log.append(logger: consoleLogger, viewLogger)
    let nd = NotifiedDelegate.singleton!
    nd.statusBar.backgroundColor = UIColor.green
    nd.onSbTap { view in
      self.debug("Tapped")
    }
    nd.permitPush { pn in
      if pn.isPermitted { self.debug("Permission granted") }
      else { self.debug("No permission") }
    }
    nd.onReceivePush { (pn, payload) in
      self.debug(payload.toString())
    }
    self.view.backgroundColor = UIColor.red
    self.collectionView.backgroundColor = UIColor.blue
    
    for pdf in ["s1.pdf", "s2.pdf", "s3.pdf", "s1.pdf", "s2.pdf", "s3.pdf"] {
      self.images.append(ZoomedPdfImage(pdfFilename: pdf))
    }
    
    //ensure just one render high res image thread
    let serialQueue = DispatchQueue(label: "pdfrender.detail.serial.queue",
                                     qos: .userInitiated)
    
    self.onHighResImgNeeded { (oimg, callback) in
      guard var pdf_img = oimg as? ZoomedPdfImageSpec else {
        ///Not implemented yet, wrong type for render Detail Image
        _ = callback(false)
        return
      }
      serialQueue.async {
        let group = DispatchGroup()
        group.enter()
//        print("Do Render", Thread.current, pdf_img.pdfFilename)
        let img = pdf_img.renderImageWithNextScale()
//        print("Render done", Thread.current, pdf_img.pdfFilename)
        DispatchQueue.main.async(){
          if img != nil {pdf_img.image = img}
          _ = callback(img != nil)
          group.leave()
//          print("Render callback done", Thread.current, pdf_img.pdfFilename)
        }
        group.wait()
//        print("Render done free thread", Thread.current, pdf_img.pdfFilename)
      }
    }
    
    for case let zoomedPdfImage as ZoomedPdfImage in self.images {
      /// **Optional:** generate preview Image
      zoomedPdfImage.waitingImage = zoomedPdfImage.renderImageWithScale(scale: 0.125)
    }

    self.onX { [weak self] in
      guard let strongSelf = self else { return }
      if strongSelf.addedOnTap {
        print("removed Tap Recogniser for all Items!")
        strongSelf.onTap(closure: nil)
      }
      else {
        print("added Tap Recogniser for all Items!")
        strongSelf.onTap { (oImg, x, y) in
          let filename : String = {
            if let zPdfI = oImg as? ZoomedPdfImage {
              return zPdfI.pdfFilename
            }
            return "-"
          }()
          print("You Tapped at: \(x)/\(y) in: \(filename)")
        }
      }
      strongSelf.addedOnTap = !strongSelf.addedOnTap
    }
    
    //Prerender if needed!
    DispatchQueue(label: "PdfTest.viewDidLoad.prerender.detail.queue").async {
      self.renderInitialPdfs()
    }
  }
  
  private var addedOnTap = false//For self.onX Demo above
  
  private func renderInitialPdfs(){
    for case let zoomedPdfImage as ZoomedPdfImage in self.images {
      if zoomedPdfImage.image != nil { continue }
      let nextZoomScale : CGFloat = 1
      let img = zoomedPdfImage.renderImageWithScale(scale: nextZoomScale)
      if img == nil {
        self.debug("PDF Pre-Renderer returned no Image:"
          + " \(String.init(describing: img)) at zoomScale: \(nextZoomScale)")
        continue
      }
      
      self.debug("PDF Pre-Renderer Image:"
      + " \(String.init(describing: img)) with zoomScale: \(nextZoomScale)")
      
      DispatchQueue.main.async {
        zoomedPdfImage.image = img
      }
        print("sleep", zoomedPdfImage.pdfFilename)
        sleep(10)//10s
        print("sleep done")
    }
  }
} // PdfTest
