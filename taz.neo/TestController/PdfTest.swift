//
//  PdfTest.swift
//
//  Created by Norbert Thies on 08.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class PdfTest: UIViewController {
  var doc: PdfDoc = PdfDoc(fname: File(inMain: "s1.pdf")!.path)
  var imageView = ImageView()
  var pdfs = ["s1.pdf", "s2.pdf", "s3.pdf"]
  var current: Int?
  var nextPdf: PdfDoc { 
    if var i = current {
      if i == 2 { i = 0 }
      else { i += 1 }
      current = i
    }
    else { current = 0 }
    return PdfDoc(fname: File(inMain: pdfs[current!])!.path)
  }

  func showNext() {
    if let img = nextPdf[0]?.image(width: UIScreen.main.bounds.width*2) {
      self.imageView.image = img
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.imageView)
    self.imageView.pinWidth(self.view.bounds.size.width)
    //self.imageView.pinAspect(ratio: img.size.width/img.size.height)
    pin(self.imageView.centerX, to: self.view.centerX)
    pin(self.imageView.centerY, to: self.view.centerY)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    showNext()
    every(seconds: 1.0) {_ in self.showNext() }
  }  

} // PdfTest
