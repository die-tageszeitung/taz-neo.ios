//
//  WebViewCollectionVC.swift
//
//  Created by Norbert Thies on 06.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import WebKit

class WebViewCollectionVC: PageCollectionVC<WebView>, WKUIDelegate,
  WKNavigationDelegate {
    
  /// The list of String URLs to collect
  public var urls: [URL] = []
  public var path: String = ""
  
  // The closure to call when link is pressed
  private var _whenLinkPressed: ((URL,URL)->())?
  
  /// Define closure to call when link is pressed
  public func whenLinkPressed( _ closure: @escaping (URL,URL)->() ) {
    _whenLinkPressed = closure
  }
  
  public func displayFiles( path: String, files: [String] ) {
    urls = []
    self.path = path
    for f in files {
      urls.append( URL( string: "file://" + path + "/" + f )! )
    }
    self.count = urls.count
  }
  
  public func displayFiles( path: String, files: String... ) {
    displayFiles(path: path, files: files)
  }
  
  public func gotoUrl( url: URL ) {
    if let index = urls.index(of: url) {
      self.index = index
    }
  }
  
  public func gotoUrl(_ url: String) {
    gotoUrl(url: URL(string: "file://" + path + "/" + url)!)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor.white
    inset = 0
    viewProvider { [weak self] (index,view) in
      var ret: WebView
      if let v = view { ret = v }
      else {
        let webConfiguration = WKWebViewConfiguration()
        ret = WebView(frame: .zero, configuration: webConfiguration)
        ret.uiDelegate = self
        ret.navigationDelegate = self
        ret.allowsBackForwardNavigationGestures = false
        ret.scrollView.isDirectionalLockEnabled = true
        ret.scrollView.showsHorizontalScrollIndicator = false
        let pan = ret.scrollView.panGestureRecognizer
      }
      if let this = self {
        ret.load(this.urls[index])
      }
      return ret
    }
  }
  
//  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//    debug("view size=\(webView.bounds.size), content size=\(webView.scrollView.contentSize), content offset=\(webView.scrollView.contentOffset)")
//  }
//  
//   public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//     debug()
//   }
  
  public func webView(_ webView: WKWebView, decidePolicyFor nav: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = nav.request.url {
      let type = nav.navigationType
      if type == .other { decisionHandler( .allow ); return }
      else if type == .linkActivated {
        if let closure = _whenLinkPressed { closure(webView.url!, url) }
      }
    }
    decisionHandler( .cancel )
  }
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
//    if scrollView.contentOffset.x > 0
//      { scrollView.contentOffset = CGPoint(x: 0, y: scrollView.contentOffset.y) }
  }

}
