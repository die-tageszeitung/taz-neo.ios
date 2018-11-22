//
//  WebViewCollectionVC.swift
//
//  Created by Norbert Thies on 06.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import WebKit

class WebViewCell: UICollectionViewCell {
  var webView: WebView!
}

public class OldWebViewCollectionVC: UIViewController, UICollectionViewDelegate,
  UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
  WKUIDelegate, WKNavigationDelegate {

  var initialItem: IndexPath?
  
  @IBOutlet weak var collectionView: UICollectionView! {
    didSet {
      self.collectionView.delegate = self
      self.collectionView.dataSource = self
    }
  }
  
  /// The list of String URLs to collect
  public var urls: [URL] = []
  
  // The closure to call when link is pressed
  private var _whenLinkPressed: ((URL,URL)->())?
  
  /// Define closure to call when link is pressed
  public func whenLinkPressed( _ closure: @escaping (URL,URL)->() ) {
    _whenLinkPressed = closure
  }

  public func displayFiles( path: String, files: [String] ) {
    urls = []
    for f in files {
      urls.append( URL( string: "file://" + path + "/" + f )! )
    }
  }
  
  public func displayFiles( path: String, files: String... ) {
    displayFiles(path: path, files: files)
  }
  
  public func gotoUrl( url: URL ) {
    if let index = urls.index(of: url) {
      let ipath = IndexPath(item: index, section: 0)
      initialItem = ipath
    }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
  }

  // MARK: - UICollectionViewDataSource

  public func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return urls.count
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let ipath = initialItem {
      collectionView.scrollToItem(at: ipath, at: .left, animated: false)
      initialItem = nil
    }
    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WebViewCell",
      for: indexPath) as? WebViewCell {
      debug( "cell at \(indexPath.section), \(indexPath.item)" )
      if cell.webView == nil {
        let webConfiguration = WKWebViewConfiguration()
        cell.webView = WebView(frame: cell.bounds, configuration: webConfiguration)
        cell.webView.uiDelegate = self
        cell.webView.navigationDelegate = self
        cell.addSubview(cell.webView)
      }
      cell.webView.load(urls[indexPath.item])
      return cell
    }
    else { return WebViewCell() }
  }

  // MARK: - UICollectionViewDelegate

  /*
  // Uncomment this method to specify if the specified item should be highlighted during tracking
  override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
      return true
  }
  */

  /*
  // Uncomment this method to specify if the specified item should be selected
  override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
      return true
  }
  */

  /*
  // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
  override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
      return false
  }

  override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
      return false
  }

  override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
  
  }
  */

  /*
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    debug( "webview navigation finished" )
  }
  
  public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    debug()
  }
 */
  
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
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    return self.view.bounds.size
  }
}
