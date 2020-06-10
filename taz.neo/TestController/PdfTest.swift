//
//  PdfTest.swift
//
//  Created by Norbert Thies on 08.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


public class ZoomedPdfImage: OptionalImageItem {
  
  public var pdfFilename: String?
  public var detailZoomScale: CGFloat?
  
  public required init(pdfFilename: String?) {
    self.pdfFilename = pdfFilename
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
    
    
    for pdf in ["s1.pdf", "s2.pdf", "s3.pdf"] {
      self.images.append(ZoomedPdfImage(pdfFilename: pdf))
    }
    
    for zoomedPdfImage in self.images {
      guard let zoomedPdfImage = zoomedPdfImage as? ZoomedPdfImage,
        let filename = zoomedPdfImage.pdfFilename else { continue }
      /// **Optional:** generate preview Image
      zoomedPdfImage.waitingImage = PdfDoc(fname: File(inMain: filename)!.path)[0]?
        .image(width: UIScreen.main.bounds.width/4)
      zoomedPdfImage.detailZoomScale = 0.25
      ///append HighResRequested Handler
      zoomedPdfImage.onHighResImgNeeded(zoomFactor: 1.1) { (callback: @escaping (UIImage?) -> ()) in
        DispatchQueue(label: "pdfrender.detail.serial.queue").async {
          guard let filename = zoomedPdfImage.pdfFilename else { return }
          let nextZoomScale = (zoomedPdfImage.detailZoomScale ?? 0) * 2
          print("nextZoomScale:", nextZoomScale)
          let img = PdfDoc(fname: File(inMain: filename)!.path)[0]?
            .image(width: UIScreen.main.bounds.width*nextZoomScale)
          zoomedPdfImage.detailZoomScale = nextZoomScale
          DispatchQueue.main.async {
            if img?.size == CGSize.zero {
              self.error("PDF Renderer returned Empty Image,"
                      + " this happens in high Zoom Scales!")
              callback(nil)
            }
            else {
              self.error("PDF Renderer returned Image:"
                       + " \(String.init(describing: img))")
               callback(img)
            }
          }
        }
      }
      
      zoomedPdfImage.onTap { (x, y) in
        self.log("You Tapped at: \(x),\(y)"
               + " in \(zoomedPdfImage.pdfFilename ?? "-")")
      }
      
      DispatchQueue(label: "pdfrender.serial.queue").async {
        self.renderInitialPdfs()
      }
    }
  }
  
  private func renderInitialPdfs(){
    for zoomedPdfImage in self.images {
      guard let zoomedPdfImage = zoomedPdfImage as? ZoomedPdfImage,
        let filename = zoomedPdfImage.pdfFilename else { continue }
      let img = PdfDoc(fname: File(inMain: filename)!.path)[0]?
        .image(width: UIScreen.main.bounds.width*2)
      DispatchQueue.main.async {
        zoomedPdfImage.image = img
        zoomedPdfImage.detailZoomScale = 2
      }
    }
  }
  
} // PdfTest
