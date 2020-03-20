//
//  UITests.swift
//
//  Created by Norbert Thies on 02.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

class UITests: UIViewController {
  lazy var toolBar = Toolbar()
  lazy var backButton = Button<LeftArrowView>(width: 30, height: 30)
  lazy var loadingView = LoadingView()
  lazy var undefinedView = UndefinedView()
  lazy var startupView = StartupView()
  
  func buildPinExample() {
    let viewA = UIView()
    let viewB = UIView()
    viewA.backgroundColor = UIColor.yellow
    viewB.backgroundColor = UIColor.blue
    self.view.addSubview(viewA)
    self.view.addSubview(viewB)
    viewA.pinWidth(200)
    viewA.pinHeight(200)
    viewB.pinWidth(50)
    viewB.pinHeight(50)
    var x = pin(viewA.centerX, to: self.view.centerX)
    var y = pin(viewA.centerY, to: self.view.centerY)
    pin(viewB.centerX, to: viewA.centerX)
    pin(viewB.centerY, to: viewA.centerY)
    delay(seconds: 2.0) { y.isActive = false; y = pin(viewA.top, to: self.view.topGuide()) }
    delay(seconds: 4.0) { y.isActive = false; y = pin(viewA.bottom, to: self.view.bottomGuide()) }
    delay(seconds: 6.0) { y.isActive = false; y = pin(viewA.centerY, to: self.view.centerY) }
    delay(seconds: 8.0) { x.isActive = false; x = pin(viewA.right, to: self.view.rightGuide(isMargin: true)) }
    delay(seconds: 10.0) { x.isActive = false; x = pin(viewA.left, to: self.view.leftGuide(isMargin: true)) }
    delay(seconds: 12.0) { x.isActive = false; x = pin(viewA.centerX, to: self.view.centerX) }
  }
  
  func pinTest() {
    self.view.backgroundColor = UIColor.rgb(0xeeeeee)
    toolBar.placeInView(self.view, isTop: false)
    toolBar.backgroundColor = UIColor.rgb(0x101010)
    backButton.pinWidth(30)
    backButton.pinHeight(30)
    toolBar.addButton(backButton, direction: .left)
    toolBar.setButtonColor(UIColor.rgb(0xeeeeee))
    backButton.onPress {_ in 
      print(self.backButton.frame)
    }
    buildPinExample()
  }
  
  func loadingTest() {
    self.view.backgroundColor = UIColor.white
    loadingView.topText = "Der Artikel:\nKeine Ahnung von diesem Sujet bzw. von dieser Materie und von so vielem mehr"
    loadingView.bottomText = "wird geladen"
    self.view.addSubview(loadingView)
    pin(loadingView, to: self.view, dist: 8)
  }
  
  func undefinedTest() {
    self.view.addSubview(undefinedView)
    pin(undefinedView, to: self.view)
  }
  
  func startupViewTest() {
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
    startupView.isAnimating = true
  }
  
  func gifTest() {
    if let path = Bundle.main.path(forResource: "test", ofType: "gif"),
      let image = UIImage.animatedGif(File(path).data, duration: 1.5) {
      let iv = UIImageView(image: image)
      self.view.addSubview(iv)
      iv.pinSize(image.size)
      pin(iv.top, to: self.view.topGuide(), dist: 20)
      pin(iv.left, to: self.view.leftGuide(), dist: 20)
    }
  }
  
  func fontTest() {
    print("nodename: \(Utsname.nodename)")
    print("sysname:  \(Utsname.sysname)")
    print("release:  \(Utsname.release)")
    print("version:  \(Utsname.version)")
    print("machine:  \(Utsname.machine)")
    if let font = UIFont.new(name: "Aktiv Grotesk Bold", size: 14) {
      let label = UILabel()
      label.font = font
      label.text = "Family: \(font.familyName), Name: \(font.fontName)"
      self.view.addSubview(label)
      pin(label.top, to: self.view.topGuide(), dist: 20)
      pin(label.left, to: self.view.leftGuide(), dist: 20)
    }
  }
  
  func alertTest() {
    let actions = [
      Alert.action("test 1") { s in print(s) },
      Alert.action("test 2") { s in print(s) },
      Alert.action("test 3") { s in print(s) },
      Alert.action("test 4") { s in print(s) }
    ]
    Alert.actionSheet(title: "Titel", message: "Test", actions: actions)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor.white
    //pinTest()
    //loadingTest()
    //undefinedTest()
    startupViewTest()
    delay(seconds: 2) { self.alertTest() }
    //gifTest()
    //fontTest()
    //alertTest()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
//    print(self.undefinedView.frame)
//    print(self.undefinedView.label.frame)
//    print(self.view.frame)
//    print(toolBar.frame)
//    print(backButton.frame)
  }
  
}

