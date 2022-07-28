//
//  ExpiredView.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class ExpiredView : FormView{
    
  func marketingContainerWidth(button: Padded.Button,
                               htmlFile:String,
                               htmlHeight:CGFloat = 150,
                               fallbackText:String) -> Padded.View{
    let wrapper = Padded.View()
    var intro:UIView
    let trialHtml = File(htmlFile)
    
    if trialHtml.exists {
      let wv = WebView()
      //      wv.webView.load(url: dataPolicy.url)
      wv.load(url: trialHtml.url)
      wv.pinHeight(htmlHeight)
      wv.isOpaque = false
      wv.backgroundColor = .clear
      intro = wv
    } else {
      let lbl = UILabel()
      lbl.text = fallbackText
      lbl.numberOfLines = 0
      lbl.textAlignment = .center
      lbl.contentFont()
      intro = lbl
    }
    
    wrapper.addSubview(intro)
    wrapper.addSubview(button)
    
    pin(intro, to: wrapper, dist: Const.Dist.margin, exclude: .bottom)
    pin(button, to: wrapper, dist: Const.Dist.margin, exclude: .top)
    pin(button.top, to: intro.bottom, dist: Const.Dist.margin)
    
    wrapper.backgroundColor = UIColor.rgb(0xDEDEDE)
    wrapper.layer.cornerRadius = 8.0
    
    return wrapper
    
  }
  
  var trialSubscriptionButton = Padded.Button(title: "Kostenlos Probelesen")
  var switchButton = Padded.Button(title: "Wechseln")
  var extendButton = Padded.Button(title: "Zubuchen")
  
  static let miniPadding = 0.0
  
  override func createSubviews() -> [UIView] {
    return   [
      Padded.Label(title: "Anmeldung für Digital-Abonnent:innen").boldContentFont(size: 18),
      marketingContainerWidth(button: trialSubscriptionButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/trialNOTEXISTFALLBACHTEST.html"),
                              fallbackText: Localized("trial_subscription_title")),
      marketingContainerWidth(button: extendButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/extend.html"),
                              htmlHeight: 290,
                              fallbackText: Localized("trial_subscription_title")),
      marketingContainerWidth(button: switchButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/switch.html"),
                              fallbackText: Localized("trial_subscription_title"))
    ]
  }
}
