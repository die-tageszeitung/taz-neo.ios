//
//  ContentVC.swift
//
//  Created by Norbert Thies on 25.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import WebKit
import NorthLib

// A ContentUrl provides a WebView URL for Articles and Sections
public class ContentUrl: WebViewUrl, DoesLog {

  public var content: Content
  public lazy var url: URL = URL(fileURLWithPath: content.path)

  private var loadClosure: (ContentUrl)->()
  private var _isAvailable = false
  private var preventNotify = false
  private var errorCount = 0
  
  public var isAvailable: Bool {
    get {
      guard !_isAvailable else { return true }
      if content.html == nil { return false }
      let path = content.dir.path
      ///contentFiles no more files! to show article even if icons missing, icons needed in menu
      for f in content.contentFiles {
        if !f.fileNameExists(inDir: path) {
          self.loadClosure(self)
          return false
        }
      }
      _isAvailable = true
      return true
    }
    set {
      ///WARNING, if fired twice "wird geladen" may not disappear!
      ///if _isAvailable == newValue { return } DISABLED: Problem: if wird geladen not disappers tap on it wount work just
      _isAvailable = newValue
      if _isAvailable {
        errorCount = 0
        if preventNotify == false {
          preventNotify = true
          onMainAfter(1.0) {[weak self] in self?.preventNotify = false }
          $whenAvailable.notify(sender: self)
        }
      }
      else if errorCount > 5,
        TazAppEnvironment.sharedInstance.feederContext?.isConnected == false {
        _waitingView?.bottomText = "\(errorCount) Ladefehler...\nBitte überprüfen Sie Ihre Internetverbindung."
        Notification.receiveOnce(Const.NotificationNames.feederReachable)  { [weak self] _ in
          guard let self = self else { return }
          self.loadClosure(self)
        }
      }
      else {
        errorCount += 1
        _waitingView?.bottomText = "\(errorCount) Ladefehler..."
        delay(seconds: 0.2 * Double(errorCount)) { [weak self] in
          guard let self = self else { return }
          self.loadClosure(self)
        }
      }
    }
  }
  
  
  @Callback
  public var whenAvailable: Callback<Void>.Store

  private var _waitingView: LoadingView?
  
  public func waitingView() -> UIView? {
    if let wv = _waitingView { return wv }
    let view = LoadingView()
    view.topText = content.title ?? ""
    view.bottomText = "wird geladen..."
    _waitingView = view
    view.onTapping { [weak self] _ in
      guard let self = self,
            self.content.html != nil else { return }
      self.loadClosure(self)
    }
    onMainAfter(15.0) {[weak self] in
      guard let self = self,
            self.content.html != nil else { return }
      self.log("started autoload again! (no crash)")
      self.loadClosure(self)
    }
    return view
  }
  
  public init(content: Content, load: @escaping (ContentUrl)->()) {
    self.content = content
    self.loadClosure = load
  }
  
} // ContentUrl

extension String {
  /// Remove .html or .public.html from filename
  func nonPublic() -> String {
    var prefix = File.progname(self)
    if prefix.hasSuffix(".public") { prefix = File.progname(prefix) }
    return prefix
  }
}

open class ContentVC: WebPagerVC, IssueInfo, UIStyleChangeDelegate {
  
  @Default("multiColumnSnap")
  public var multiColumnSnap: Bool
  
  @Default("multiColumnFixedScrolling")
  public var multiColumnFixedScrolling: Bool
  
  @Default("autoHideToolbar")
  var autoHideToolbar: Bool
  
  @Default("excludeImageAltTagsFromVoiceover")
  var excludeImageAltTagsFromVoiceover: Bool
  
  private var hideOnScroll: Bool {
    if UIScreen.isIpadRegularHorizontalSize {
      return false
    }
    if autoHideToolbar == false {
      return false
    }
    if UIAccessibility.isVoiceOverRunning {
      return false
    }
    if ArticlePlayer.singleton.isOpen {
      return false
    }
    return true
  }

  /// CSS Margins for Articles and Sections
  public class var topMargin: CGFloat { return 40 }
  public static let bottomMargin: CGFloat = 50
  
  var multiColumnGap: CGFloat = 0.0
  var multiColumnWidth: CGFloat = 0.0
  var screenColumnsCount: Int = 1
  
  private var lastTrackingName: String?
  
  @Default("showBarsOnContentChange")
  var showBarsOnContentChange: Bool
  
  @Default("articleLineLengthAdjustment")
  private var articleLineLengthAdjustment: Int
  
  @Default("articleTextSize")
  private var articleTextSize: Int
  @Default("multiColumnModeLandscape")
  var multiColumnModeLandscape: Bool

  ///indicator if multiColumnMode == true & tablet & enough space to display multi columns
  private var isMultiColumnMode = false {
    didSet {
//      topConstraint?.constant = isMultiColumnMode ? Self.topMargin : 0
      
      if self.isKind(of: ArticleVC.self)
          && oldValue == true
          && isMultiColumnMode == false
          && Defaults.multiColumnMode == true {
        var tip = ""
        if Device.isIpad && UIDevice.isPortrait {
          tip = "iPad ins Querformat drehen."
        }
        else if UIScreen.main.bounds.size.width > UIWindow.size.width {
          tip = "App vergrößern."
        }
        else {
          tip = "Schriftgröße verkleinern."
        }
        Toast.show("Mehrspaltigkeit nicht verfügbar!<br>Zum Aktivieren der Mehrspaltigkeit \(tip)")
      }
    }
  }

  public var feederContext: FeederContext  
  public weak var delegate: IssueInfo!
  public var contents: [Content] = []
  public var feeder: Feeder { delegate.feeder }
  public var issue: Issue { delegate.issue }
  public var feed: Feed { issue.feed }
  public var dloader: Downloader { delegate.dloader }
  ///optional slider configured by SectionVC, PDF but not by Search/Bookmarks
  var slider:MyButtonSlider?
  /// Whether to show all content images in a gallery
  public var showImageGallery = true
  public var toolBar = ContentToolbar()
  private var toolBarConstraint: NSLayoutConstraint?
  public var backButton = Button<ImageView>()
  public var playButton = Button<ImageView>()
  
  public var bookmarkButton = Button<ImageView>()
  private var playClosure: ((ContentVC)->())?
  private var bookmarkClosure: ((ContentVC)->())?
  private var backClosure: ((ContentVC)->())?
  public var homeButton = Button<ImageView>()
  private var homeClosure: ((ContentVC)->())?
  public var textSettingsButton = Button<ImageView>()
  private var textSettingsClosure: ((ContentVC)->())?
  public var shareButton = Button<ImageView>()
  private var shareClosure: ((ContentVC)->())?
  private var imageOverlay: Overlay?
  
  var isImageOverlay:Bool{
    return imageOverlay != nil
  }
  
  var settingsBottomSheet: BottomSheet2?
  private var textSettingsVC:TextSettingsVC? = TextSettingsVC()
  
  var currentAudioContent: Content? { nil }
  
  func updateAudioButton(){
    self.playButton.buttonView.name
    = ArticlePlayer.singleton.currentPlayingContent?.audioItem?.file?.sha256 == currentAudioContent?.audioItem?.file?.sha256
    ? "audio-active"
    : "audio"
  }
  

//  private var currentContents : [Content] {
//    var currentItems: [Content] = []
//    let currentIndex = index
//    currentItems.appendIfPresent(contents.valueAt(currentIndex-1))
//    currentItems.appendIfPresent(contents.valueAt(currentIndex))
//    currentItems.appendIfPresent(contents.valueAt(currentIndex+1))
//    return currentItems
//  }
  
  var mcoBottomSheet:BottomSheet2?
  
  private var issueObserver: Notification.Observer?
  private var reloadLoaded: Bool = false
  
  public var header = HeaderView()
  public var isLargeHeader = false
  
  private static var _tazApiCss: File? = nil
  public var tazApiCss: File {
    if ContentVC._tazApiCss == nil 
    { ContentVC._tazApiCss = File(dir: feeder.resourcesDir.path, fname: "tazApi.css") }
    return ContentVC._tazApiCss!
  }
  private static var _tazApiJs: File? = nil
  public var tazApiJs: File {
    if ContentVC._tazApiJs == nil 
    { ContentVC._tazApiJs = File(dir: feeder.resourcesDir.path, fname: "tazApi.js") }
    return ContentVC._tazApiJs!
  }
  
  func cleanup(){
    pager.releaseWebviews()
    settingsBottomSheet = nil
    mcoBottomSheet = nil
    slider = nil
    textSettingsVC = nil
    header.onTitle { _ in }
  }

  public func resetIssueList() {
    #warning("ToDo delegate.resetIssueList?")
//    delegate.resetIssueList()
  }
  
  var textSize: Int { Int(Defaults.singleton["articleTextSize"] ?? "100") ?? 100}

  /// Write tazApi.css to resource directory
  public func writeTazApiCss(topMargin: CGFloat? = nil,
                             bottomMargin: CGFloat? = nil, callback: (()->())? = nil) {
    let bottomMargin = bottomMargin ?? Self.bottomMargin
    let dfl = Defaults.singleton
    let colorMode = dfl["colorMode"]
    let textAlign = dfl["textAlign"] ?? "initial"
    var colorModeImport: String = ""
    if colorMode == "dark" { colorModeImport = "@import \"themeNight.css\", screen;" }
    let cssContent = """
      \(colorModeImport)

      html, body { 
        font-size: \((CGFloat(textSize)*18)/100)px; 
      }
    
      #content:first-child > *:first-child > *:first-child > img,
      #content:first-child > *:first-child > *:first-child > img:first-child{
             padding-top: -20px
      }
    
      body {
        padding-top: 78px;
        padding-bottom: \(bottomMargin+UIWindow.bottomInset/2)px;
      }
      \(bookmarkAntiSnippetCss)
      p {
        text-align: \(textAlign);
      }
      @media screen {
        \(multiColumnCss)
    
        #podcastPlayButton, #podcastPlayButtonSection { display: block; }
      }
      \(heightContrastDarkmodeTextColor)
    
      @media print {
        html, body { 
            font-size: \((CGFloat(textSize)*13)/100)px; 
        }
    
        #content p, img { page-break-inside: avoid;}
    
        .Autor, .AutorProfil, .AutorImg {
          page-break-inside: avoid;
          break-inside: avoid;
        }    
      }
    """
    URLCache.shared.removeAllCachedResponses()///did not remove old css in tazApi.css
    let types = WKWebsiteDataStore.allWebsiteDataTypes()
    let date = Date(timeIntervalSince1970: 0)
    WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: date) {
    }
    
    File.open(path: tazApiCss.path, mode: "w") { f in f.writeline(cssContent)
      callback?()
    }
  }
  
  var heightContrastDarkmodeTextColor : String {
    if App.isRelease && DefaultAuthenticator.isTazLogin == false { return ""}
    if Defaults.darkMode == false { return ""}
    if UITraitCollection.current.accessibilityContrast != .high { return ""}
    return "a:link, a:visited, body, span.AbstraktUntenLinks, span.AbstraktUntenRechts, div.AnzeigenSonderSeitenTitel::before, em.ctColorBlack, div.AnzeigenSonderSeitenTitel, h4.Dach, div.ArtikelTyp_AKOM1_2017 h4.Dach, div.ArtikelTyp_AKOM2_2017 h4.Dach, div.ArtikelTyp_AKolumne1_2017 h4.Dach, span.Stichwort, h4.AutorName, h5.AutorJob, span.TitelSpitz, span.Spitzmarke, div.Shorty, .ShortyTitel, div.Shorty h2.Titel, div.eptShorty, h2 span.Stichwort, div.eptBildbox h2 span.Stichwort, div.ArtikelTyp_AKOM1 h4.Dach, div.ArtikelTyp_AKOM2 h4.Dach, div.ArtikelTyp_AKolumne1 h4.Dach, div.Shorty, div.VerzeichnisArtikel, div.Autoren, div.SectionArticleEnd, div.SectionArticleEnd.Kurztitel, .SectionArticleEnd.Linkliste, div.lastElement, div.Autor, div.eptMeldung h4.Dach, div.eptKommentar h4.Dach, div.eptKolumne h4.Dach, div.eptShorty h2.Titel, div.eptShorty p.ShortyTitel, div.AnzeigenSonderSeitenUnterzeile {color: #fff}"
  }
  
  var multiColumnCss : String {
    let css = getMultiColumnCss()
    isMultiColumnMode = css != nil
//    self.collectionView.showsHorizontalScrollIndicator = false
    return css ?? singleColumnCss
  }
  
  ///CSS fix for Search Article Result with snippet css highlight, removes highlight
  var bookmarkAntiSnippetCss : String {
    guard delegate != nil else {
      log("!ERROR!: Prevented crash on disappeared VC\nIt seams there is a unreleased Reference again! Fix it!")
      return ""
    }
    if issue.isBookmarkIssue {
      return """
        body span.snippet {
          background-color  : unset;
        }
      """
    }
    return ""
  }
  
  var singleColumnCss : String {
    if Device.isIpad == false {
      return """
      body #content {
       padding-bottom: \(footerHeight)px;
      }
      """
    }
    let textSizeFactor = floor(CGFloat(textSize)/10)/10 ///(0.3...2.0)
    let rowWidth = 825.0*textSizeFactor //734 for 0.8&0.9 / 835 fot 0.6 and 0.8
    var maxWidth = min(rowWidth, UIWindow.size.width - 36)
    if articleLineLengthAdjustment < 0 {
      maxWidth *= 0.7
    }
    else if articleLineLengthAdjustment == 0 {
      maxWidth *= 0.8
    }
    maxWidth = floor(maxWidth)
    return """
    body #content {
        width: \(maxWidth)px;
        margin-left: \(-maxWidth/2)px;
        padding-bottom: \(footerHeight)px;
        position: absolute;
        left: 50%;
    }
    """
  }
  
  public override func handleRightTap() -> Bool {
    guard isMultiColumnMode && !(self is SectionVC) else {
      let isNotAtEnd = super.handleRightTap()
      if hideOnScroll { toolBar.show(show: !isNotAtEnd, animated: true) }
      isNotAtEnd
      ? (self as? HelpProviding)?.hideHelpButton()
      : (self as? HelpProviding)?.showHelpButton()
      return isNotAtEnd
    }
    guard let sv = self.currentWebView?.scrollView  else { return false }
    if sv.contentOffset.x + 2 + sv.frame.size.width > sv.contentSize.width { return false }
    /// scroll visible row count right usually:
    /// contentOffset.x + sv.frame.size.width - multiColumnGap
    /// but in case of misplaced scrolling/offset, we need to 'snap' next row
    let currentRow = sv.contentOffset.x/CGFloat(rowWidth)
    let offset = 0
    let nextRow = CGFloat(Int(currentRow) + max(1, screenColumnsCount - offset))
    var x = rowWidth*nextRow
    if !multiColumnFixedScrolling {
      let maxX = CGFloat(sv.contentSize.width - sv.frame.size.width)
      if maxX - x < 5 { x = maxX }  ///fix round errors
      x = min(maxX, x)
    }
    (self as? HelpProviding)?.hideHelpButton()
    //debug(">>> scroll from \(sv.contentOffset.x) right to xoffset: \(x) ")
    sv.setContentOffset(CGPoint(x: x, y: 0), animated: true)
    sv.flashScrollIndicators()
    return true
  }
  
  var rowWidth:CGFloat { multiColumnWidth + multiColumnGap}
  fileprivate let footerHeight:Int
  = 50 + Int(UIWindow.bottomInset) //Footer+SafeArea Padding
  
  public override func handleLeftTap() -> Bool {
    guard isMultiColumnMode && !(self is SectionVC) else { return super.handleLeftTap() }
    guard let sv = self.currentWebView?.scrollView  else { return false }
    if sv.contentOffset.x - 2 < 0 { return false }
    /// scroll visible row count right usually:
    /// contentOffset.x + sv.frame.size.width - multiColumnGap
    /// but in case of misplaced scrolling/offset, we need to 'snap' next row
    let currentRow = sv.contentOffset.x/CGFloat(rowWidth)
    let wrongOffset = abs(floor(currentRow) - currentRow) > 0.1
    let offset = wrongOffset ? 1 : 0
    let nextRow = CGFloat(Int(currentRow) - max(1, screenColumnsCount - offset))
    var x = max(0, rowWidth*nextRow)//nextStart
    if x < 5 { x = 0 }///fix round errors
    sv.setContentOffset(CGPoint(x: x, y: 0), animated: true)
    sv.flashScrollIndicators()
    return true
  }
  
  func getMultiColumnCss() -> String?  {
    let columns = Defaults.columnSetting.used
    guard Defaults.multiColumnMode && columns >= 2 else { return nil }
    
    let padding
    = articleTextSize <= 100
    ? 30.0
    : 30.0 * floor(CGFloat(articleTextSize)/10)/10
    let colF = CGFloat(columns)
    multiColumnWidth = floor((UIWindow.size.width + 1 - (colF + 1)*padding)/colF)
    screenColumnsCount = columns
    multiColumnGap = padding
    ///Top Padding for Content behind header; not needed for Footer, there we use bottomAnchor
    ///for footer a Padding is Required in SingleColumnCSS!!
    let headerHeight:Int = 68
    ///10 for a little spacing between last text line and fixed Toolbar
    let hFix = footerHeight + headerHeight + 10
    let buFix = hFix - 20 + Int(CGFloat(articleTextSize*70)/100)
    /**
     ***pretty ugly css** but:
        * content paddings&margins increase column gap
        * need to add padding/margin at end
        * tap to scroll needs perect alligned columns
        * body #content minus margin-left fixes: gap increase
        * body needs padding bottom of 50, but set this activates vertical scrolling
        * => set height  height: calc(100vh - 128px); 128 = 68+50 top/bottom + 10px extra margin/padding
      */
    return """
      html {
        height: 100%;
      }
      body:has(.article) {
        padding: \(headerHeight)px 0 0 0;
        height: calc(100vh - \(hFix)px);
        margin-left: \(Int(multiColumnGap))px;
        overflow-x: scroll;
        column-width: \(Int(multiColumnWidth))px;
        width: fit-content;
        column-fill: auto;
        column-gap: 0;
        orphans: 3; /*at least 3 lines in a block at end*/
        widows: 3; /*at least 3 lines in a block at start*/
      }
      body #content.article {
        margin: 0;
        width: \(Int(multiColumnWidth))px;
        padding-right: \(Int(multiColumnGap))px;
        position: relative;/*important overwrite scroll.css defaults*/
        left: 0;/*important overwrite scroll.css defaults*/
        overflow-y: hidden;
      }
      body #content.article .Autor {
        break-inside: avoid;
      }
      body #content.article #foto img {
        break-inside: avoid;
        object-fit: contain;
        max-height: calc(100vh - \(buFix)px);
      }
      #content div {
        /*fix: 240417-w+u-1 author box broken text in ip6m/ios17.4/100%fontSize/Landscape */
        break-inside: avoid;
      }
      body #content {
       padding-bottom: \(footerHeight)px;
      }
    """
  }
  
  /// Return dictionary for dynamic HTML style data
  public static func dynamicStyles() -> [String:String] {
    var css: [String:String] = [:]
    let dfl = Defaults.singleton
    css["colorTheme"] = dfl["colorMode"] == "dark" ? "dark" : "light"
    css["textAlign"] = dfl["textAlign"]
    css["fontSize"] = dfl["articleTextSize"]
    css["columnSize"] = dfl["articleColumnPercentageWidth"]
    return css
  }
  
  public func setDynamicStyles(webView: WebView) async throws -> Bool {
    let css = Self.dynamicStyles()
    let js = """
      (() => {
        if (typeof tazApi.hasDynamicStyles === "function" && tazApi.hasDynamicStyles()) {
          tazApi.setColorTheme("\(css["colorTheme"]!)");
          tazApi.setTextAlign("\(css["textAlign"]!)");
          tazApi.setFontSize("\(css["fontSize"]!)");
          tazApi.setColumnSize("\(css["columnSize"]!)");
          return true;
        }
        return false;
      })()
    """
    if let retval = try? await webView.jsexec(js) {
      return retval as? Int != 0
    }
    else { return false }
  }
    
  /// Setup JS bridge
  func setupBridge() {
    self.bridge = JSBridgeObject(name: "tazApi")
    self.bridge?.addfunc("openImage") { [weak self] jscall in
      guard let self = self else { return NSNull() }
      #warning("Prevent Open Image Galery due Focus could not be set")
      /// focus stays in Background
      /// prevent open due image galery make no sense due missing alt text
      if UIAccessibility.isVoiceOverRunning { return NSNull() }
      if let args = jscall.args, args.count > 0,
         let img = args[0] as? String {
        let current = self.contents[self.index]
        let imgVC = ContentImageVC(content: current,
                                   delegate: self,
                                   imageTapped: img,
                                   showImageGallery: self.showImageGallery)
        self.imageOverlay = Overlay(overlay:imgVC , into: self)
        self.imageOverlay?.maxAlpha = 0.9
        Usage.track(Usage.event.various.ImageGalery,
                    name: "open",
                    dimensions: current.customDimensions)
        self.imageOverlay?.open(animated: true, fromBottom: true)
        // Inform Application to re-evaluate Orientation for current ViewController
        NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification,
                                        object: nil)
        (self as? HelpProviding)?.hideHelpButton()
        self.updateAccessibility(postLayoutChanged: true)
        self.imageOverlay?.onClose {[weak self] in
          (self as? HelpProviding)?.showHelpButton()
          self?.imageOverlay = nil///former we had a delayed set nil
          self?.updateAccessibility(postLayoutChanged: true)
          guard Device.isIphone else { return }
          /// reset orientation to portrait, really no negative effect on iPad?
          UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
          
        }
        imgVC.toClose {[weak self] in
          self?.imageOverlay?.close(animated: true, toBottom: true)
        }
      }
      return NSNull()
    }
    
    self.bridge?.addfunc("trackAdIfNeeded") { [weak self] jscall in
      guard self != nil else { return NSNull() }
      if let args = jscall.args, args.count > 0,
         let adIdentifier = args[0] as? String,
         let htmlName = args[1] as? String,
         self?.lastTrackingName != htmlName,
         htmlName == self?.currentWebView?.url?.lastPathComponent {
        let issueDate = self?.issue.date.ISO8601 ?? "-"
        let sectionTitle
        = self?.header.title
        ?? self?.contents.valueAt(self?.index ?? 0)?.title
        ?? "-"
        Usage.track(Usage.event.advertisement.sectionAdShown
                   , name: "\(issueDate)/\(sectionTitle)/\(adIdentifier)")
        self?.lastTrackingName = htmlName
        onMain(after: 5.0) {[weak self] in
          ///reset after a few seconds to prevent double trackings in edge cases
          self?.lastTrackingName = nil
        }
      }
      return NSNull()
    }
    
    self.bridge?.addfunc("setBookmark") { [weak self] jscall in
      guard self != nil else { return NSNull() }
      if let args = jscall.args, args.count > 1,
         let name = args[0] as? String,
         let hasBookmark = args[1] as? Int {
        let bm = hasBookmark != 0
        ///logic error if  expired account articles downloaded with expired account have .public.html former downloaded .html
//        let artName = name + (self.feederContext.isAuthenticated ? ".html" : ".public.html")
        var arts = StoredArticle.get(file: name + ".html")
        if arts.count == 0 {
          arts = StoredArticle.get(file: name + ".public.html")
        }
        arts.first?.hasBookmark.toggle()
      }
      return NSNull()
    }
    self.bridge?.addfunc("getBookmarks") { [weak self] jscall in
      guard let _ = self else { return NSNull() }
      let arts = Bookmarks.shared.bookmarkSection?.articles ?? []
      var names: [String] = []
      for a in arts { names += a.html?.name.nonPublic() ?? "-" }
      return names
    }
    self.bridge?.addfunc("shareArticle") { [weak self] jscall in
      guard let self = self else { return NSNull() }
      if let args = jscall.args, args.count > 0,
         let name = args[0] as? String,
         let art = self.issue.article(artname: name) {
        self.export(article: art)
      }
      return NSNull()
    }
    self.bridge?.addfunc("togglePlayButtonNative") { [weak self] jscall in
      guard let self = self else { return NSNull() }
      if let args = jscall.args, args.count > 1,
         let msid = args[0] as? String,
         let fileName = args[1] as? String {
        play(msid: msid, audioFileName: fileName)
      }
      return NSNull()
    }

    self.bridge?.addfunc("gotoIssue") { [weak self] jscall in
      guard let self = self else { return NSNull() }
      if let args = jscall.args, args.count > 0,
         let tiSince1970S = args.first as? String,
         let tiSince1970 = Double(tiSince1970S) {
            let ti = TimeInterval(floatLiteral: tiSince1970)
            let date = Date(timeIntervalSince1970: ti)
        Notification.send(Const.NotificationNames.gotoIssue, content: date, sender: self)
      }
      return NSNull()
    }
    self.bridge?.addfunc("toast") { [weak self] jscall in
      guard let _ = self else { return NSNull() }
      if let args = jscall.args, args.count > 0,
         let msg = args[0] as? String {
        var duration = 3.0
        if args.count > 1 {
          if let d = args[1] as? Int { duration = Double(d) }
          else if let d = args[1] as? Double { duration = d }
        }
        jscall.delayCallback = true
        Toast.show(msg, minDuration: duration) { wasTapped in
          jscall.callback(arg: wasTapped, isDelayed: true)
        }
      }
      return NSNull()
    }
    self.bridge?.addfunc("setDynamicStyles") { [weak self] jscall in
      guard let self = self, let wv = jscall.webView
      else { return NSNull() }
      Task { try? await self.setDynamicStyles(webView: wv) }
      return NSNull()
    }
    self.bridge?.addfunc("gotoStart") { [weak self] _ in
      self?.scrollTo(index: 0)
      Toast.show("Das ist der Anfang!")
      return NSNull()
    }
  }
  
  func export(article: Article){
    ArticleExportDialogue.show(article: article,
                               image: article.cellIconImage,
                               sourceView: shareButton)
  }
  
  var reopenArticleDocName: String?
  var reopenArticleScrollPos: CGFloat?
  
  var scrollToPosJsV: String {
    guard let scrollPos = reopenArticleScrollPos,
          let docname = reopenArticleDocName else { return "" }
    return """
      const url = new URL(window.location.href);
      const pathParts = url.pathname.split('/');
      const filename = pathParts.pop();
      const docname = "\(docname)";
      if (filename == docname) { 
        window.addEventListener("load", () => {
          const hasScrolled = sessionStorage.getItem("scrolled_" + docname);
          if (hasScrolled) { return; }
          const scrollHeight = document.documentElement.scrollHeight;
          const clientHeight = document.documentElement.clientHeight;
          const maxScrollY = scrollHeight;
          const targetScrollY = \(scrollPos) * maxScrollY;
          tazApi.log(`>>> Scroll ${docname} to: \(scrollPos) yPos: ${targetScrollY}`);
          window.scrollTo({
            top: targetScrollY,
            behavior: 'auto'
          });
          sessionStorage.setItem("scrolled_" + docname, "true");
        });
      }
      """
    /**
     Debug Helper:
     tazApi.log(`>>> Apply last ScrollPos if: ${filename} == ${docname}`);
     tazApi.log(`>>> Scroling vars scrollHeight : ${scrollHeight} clientHeight : ${clientHeight}`);
     tazApi.log(`>>> Apply last ScrollPos (\(scrollPos)) for: ${docname}`);
     */
  }
  
  var scrollToPosJsH: String {
    guard let scrollPos = reopenArticleScrollPos,
          let docname = reopenArticleDocName else { return "" }
    return """
      const url = new URL(window.location.href);
      const pathParts = url.pathname.split('/');
      const filename = pathParts.pop();
      const docname = "\(docname)";
      if (filename == docname) { 
        window.addEventListener("load", () => {
          const hasScrolled = sessionStorage.getItem("scrolled_" + docname);
          if (hasScrolled) { return; }
          const scrollWidth = document.documentElement.scrollWidth;
          const clientWidth = document.documentElement.clientWidth;
          const maxScroll = scrollWidth - clientWidth 
          const targetScrollX = \(scrollPos) * maxScroll;
          tazApi.log(`>>> Scroll ${docname} to: \(scrollPos) yPos: ${targetScrollX}`);
          window.scrollTo({
            left: targetScrollX,
            behavior: 'auto'
          });
          sessionStorage.setItem("scrolled_" + docname, "true");
        });
      }
      """
  }
 
  /// Define the closure to call when the back button is tapped
  public func onBack(closure: @escaping (ContentVC)->()) 
    { backClosure = closure }
  
  /// Define the closure to call when the bookmark button is tapped
  public func onBookmark(closure: @escaping (ContentVC)->()) 
    { bookmarkClosure = closure }
  
  /// Define the closure to call when the home button is tapped
  public func onSettings(closure: @escaping (ContentVC)->())
    { textSettingsClosure = closure }
  
  /// Define the closure to call when the home button is tapped
  public func onHome(closure: @escaping (ContentVC)->()) 
    { homeClosure = closure }
  
  public func onShare(closure: @escaping (ContentVC)->()) {
    shareClosure = closure
    if playClosure == nil { toolBar.setArticleBar() }
    else { toolBar.setArticlePlayBar() }
  }
  
  public func onPlay(closure: ((ContentVC)->())?) {
    playClosure = closure
    if self is SectionVC { return }
    if closure == nil { toolBar.setArticleBar() }
    else { toolBar.setArticlePlayBar() }
  }
  
  var bottomSheetDefaultCoverage: CGFloat {
    448 + UIWindow.safeInsets.bottom + (self.textSettingsVC?.multiColumnButtonsAdditionalHeight ?? 0)
  }
  
  var bottomSheetDefaultSlideDown: CGFloat { self.textSettingsVC?.slideDownHeight ?? 0 }
  
  func setupSettingsBottomSheet() {
    guard let textSettingsVC = textSettingsVC else { return }
    settingsBottomSheet = BottomSheet2(slider: textSettingsVC, into: self)
    settingsBottomSheet?.xButton.tazX()
    settingsBottomSheet?.onX {[weak self] in
      self?.settingsBottomSheet?.close()
    }
    settingsBottomSheet?.updateMaxWidth()
    self.settingsBottomSheet?.coverage = self.bottomSheetDefaultCoverage
    onSettings{ [weak self] _ in
      guard let self = self else { return }
      self.settingsBottomSheet?.coverage = self.bottomSheetDefaultCoverage
      self.debug("*** Action: <Settings> pressed")
      if self.settingsBottomSheet?.isOpen ?? false {
          self.settingsBottomSheet?.close()
      }
      else {
        self.settingsBottomSheet?.open()
        self.settingsBottomSheet?.slideDown(self.bottomSheetDefaultSlideDown)
      }
      
      self.textSettingsVC?.updateButtonValuesOnOpen()
    }
  }
  
  @objc func backButtonLongPress(_ sender: UIGestureRecognizer) {
    (self as? ArticleVC)?.persistReadProgress()
    self.navigationController?.popToRootViewController(animated: true)
  }
  
  lazy var backButtonLongPressGestureRecognizer:UILongPressGestureRecognizer
  = UILongPressGestureRecognizer(target: self,
                                 action: #selector(backButtonLongPress))
  
  func setupToolbar() {
    backButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.backClosure?(self)
    }
    backButton.addGestureRecognizer(backButtonLongPressGestureRecognizer)
    bookmarkButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.bookmarkClosure?(self)
    }
    
    self.playButton.buttonView.onTapping { [weak self] _ in
      guard let self = self else { return }
      self.playClosure?(self)
    }
    homeButton.onPress { [weak self] _ in 
      guard let self = self else { return }
      self.homeClosure?(self)
    }
    shareButton.onPress { [weak self] _ in 
      guard let self = self else { return }
      self.shareClosure?(self)
    }
    textSettingsButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.textSettingsClosure?(self)
      Usage.track(Usage.event.dialog.TextSettings)
    }
    
    backButton.pinSize(CGSize(width: 47, height: 47))
    shareButton.pinSize(CGSize(width: 47, height: 47))
    textSettingsButton.pinSize(CGSize(width: 47, height: 47))
    playButton.pinSize(CGSize(width: 47, height: 47))
    bookmarkButton.pinSize(CGSize(width: 47, height: 47))
    homeButton.pinSize(CGSize(width: 47, height: 47))
    
    backButton.hinset = 0.15
    shareButton.hinset = 0.15
    textSettingsButton.hinset = 0.15
    playButton.hinset = 0.15
    bookmarkButton.hinset = 0.15
    homeButton.hinset = 0.15
    
    backButton.buttonView.name = "chevron-left"
    backButton.buttonView.imageView.contentMode = .right
    shareButton.buttonView.name = "share"
    textSettingsButton.buttonView.name = "text-settings"
    bookmarkButton.buttonView.name = "star"
    playButton.buttonView.name = "audio"
    homeButton.buttonView.name = "home"
 
    toolBar.addArticleButton(bookmarkButton, direction: .center)
    toolBar.addArticleButton(Toolbar.Spacer(), direction: .center)
    
    toolBar.addArticleButton(shareButton, direction: .center)
    toolBar.addArticlePlayButton(Toolbar.Spacer(), direction: .center)
    if self is SectionVC {
      toolBar.addButton(playButton, direction: .center)
    }
    else {
      toolBar.addArticlePlayButton(playButton, direction: .center)
    }
    toolBar.addButton(backButton, direction: .left)
    toolBar.addButton(textSettingsButton, direction: .right)
    toolBar.applyDefaultTazSyle()
    toolBar.pinTo(self.view)
    
    backButton.isAccessibilityElement = true
    textSettingsButton.isAccessibilityElement = false //make no sense just for seeing people
    homeButton.isAccessibilityElement = true
    playButton.isAccessibilityElement = true
    shareButton.isAccessibilityElement = true
    playButton.isAccessibilityElement = true
    bookmarkButton.isAccessibilityElement = true
    backButton.accessibilityTraits = .button
    homeButton.accessibilityTraits = .button
    shareButton.accessibilityTraits = .button
    playButton.accessibilityTraits = .button
    bookmarkButton.accessibilityTraits = .button
    backButton.accessibilityLabel = "zurück"
    homeButton.accessibilityLabel = "Ausgabenübersicht"
    shareButton.accessibilityLabel = "Teilen"
    playButton.accessibilityLabel = "Vorlesen"
    bookmarkButton.accessibilityLabel = "Lesezeichen setzen"
  }
  
  /// Insert new content at (before) index
  public func insertContent(content: Content, at idx: Int) {
    let curl = ContentUrl(content: content) { [weak self] curl in
      guard let self = self,
      self.delegate != nil else { return }
      if content.primaryIssue?.isBookmarkIssue == true {
        guard let baseUrl = curl.content.baseURL else { return }
        self.dloader.downloadSearchHitFiles(files: curl.content.files,
                                            baseUrl: baseUrl) { err in
          curl.isAvailable = err == nil
        }
        return
      }
      
      self.dloader.downloadIssueData(issue: self.issue, files: curl.content.files) { err in
        curl.isAvailable = err == nil
      }
    }
    contents.insert(content, at: idx)
    insert(wwurl: curl, at: idx)
  }
  
  /// Delete content at index
  public func deleteContent(at idx: Int) {
    guard idx < contents.count else { return }
    contents.remove(at: idx)
    delete(at: idx)
  }
  
  /// Define new contents
  public func setContents(_ contents: [Content]) {
    self.contents = contents
    ///On wild clicking (enter leave issues, download...)  prev guard not worked, so using local vars
    ///Previous check vars in dloader callback to fix:
    ///Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value
    ///=> ensure dloader is not nil, cannot use "extension IssueInfo" dloader its not an force unwraped...
    if self.delegate == nil ||
        self.delegate.feederContext.dloader == nil { return }
    let selfSafeIssue = self.delegate.issue
    let selfSafeDloader = self.dloader
    
    let curls: [ContentUrl] = contents.map { cnt in
      ContentUrl(content: cnt) {[weak self] curl in
        if curl.content.primaryIssue == nil
          || curl.content.primaryIssue?.isBookmarkIssue == true
            || selfSafeIssue.isBookmarkIssue == true {
          guard let baseUrl = curl.content.baseURL,
                let issueDate = curl.content.issueDate,
                let storedFeeder = self?.feederContext.storedFeeder,
                let issueDir = Bookmarks.shared.commonIssueDir(for: issueDate)
          else { return }
          issueDir.createGlobalLinksIfNeeded(feeder: storedFeeder)
          self?.dloader.downloadSearchHitFiles(files: curl.content.files,
                                              baseUrl: baseUrl,
                                              targetDir: issueDir) { err in
            curl.isAvailable = err == nil
          }
          return
        }
        selfSafeDloader.downloadIssueData(issue: selfSafeIssue,
                                          files: curl.content.files) { err in
          curl.isAvailable = err == nil
        }
      }
    }
    self.pager.urls = curls
  }
  override public var addtionalBarHeight: CGFloat{
    header.frame.size.height + toolBar.frame.size.height
  }
  override public var textLineHeight: CGFloat {
    //Custom FontScale/100 * defaultFontSize*lineightFactor
    CGFloat(Defaults.articleTextSize.articleTextSize/100*Int(Const.Size.DefaultFontSize*1.6))
  }
  
//  // MARK: - viewDidLoad
  override public func viewDidLoad() {
    writeTazApiCss()
    writeTazApiJs()
    super.viewDidLoad()
    self.view.addSubview(header)
    defaultAccessibilityView = header
    pin(header, toSafe: self.view, exclude: .bottom)
    setupSettingsBottomSheet()
    setupToolbar()
    
    scrollViewDidEndScrolling{ [weak self] offset in
      guard let self = self,
              self.isMultiColumnMode,
              self.multiColumnSnap,
              self is ArticleVC else { return }
      let nextRow = offset.x/CGFloat(self.rowWidth)
      self.currentWebView?.scrollView.setContentOffset(CGPoint(x: rowWidth*round(nextRow), y: 0), animated: true)
    }
    
    whenScrolled { [weak self] ratio in
      if (ratio < 0) {
        self?.slider?.showMenuImage = true
        if self?.hideOnScroll == false { return }
        self?.toolBar.show(show: false, animated: true)
        (self as? HelpProviding)?.hideHelpButton()
      }
      else {
        self?.slider?.showMenuImage = false
        self?.toolBar.show(show:true, animated: true)
        (self as? HelpProviding)?.showHelpButton()
      }
    }
    onDisplay {[weak self]_, ov  in
      //Note: use this due onPageChange only fires on link @see WebCollectionView
      if self?.showBarsOnContentChange == true {
        self?.toolBar.show(show:true, animated: true)
        self?.header.show(show: true, animated: true)
        (self as? HelpProviding)?.showHelpButton()
      }
      
      if let wv = ov?.mainView as? WebView {
        self?.updateAudioInWebview(wv)
      }
      
      if self?.hideOnScroll == false {
        self?.additionalSafeAreaInsets
        = UIEdgeInsets(top: 0,
                       left: 0,
                       bottom: UIWindow.bottomInset + 30,
                       right: 0)
      }
    }
    
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.persistReadProgress()
      ArticleDB.save()
    }
    Notification.receive(UIApplication.willTerminateNotification) { [weak self] _ in
      self?.persistReadProgress()
      ArticleDB.save()
    }
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButton()
      self?.updateAudioInWebview()
      
    }
    registerForStyleUpdates()
  }
  
  func persistReadProgress() {}///overwrite in Subclass
  
  func updateSliderWidth(newParentWidth: CGFloat? = nil){
    let maxWidth = Const.Size.ContentSliderMaxWidth
    slider?.ocoverage
    = min(maxWidth, (newParentWidth ?? maxWidth + 28.0) - 28.0 )
  }
  
  public func setupSlider() {
    guard slider != nil else { return }
    updateSliderWidth(newParentWidth: UIScreen.shortSide)
    let logo = App.isTAZ ? "logo" : "logoLMD"
    slider?.setImage( UIImage(named: logo),
                      menuImage: UIImage(named: "BurgerMenu")?.withTintColor(.white, renderingMode: .alwaysOriginal),
                      closeImage: UIImage(named: "closeX")?.withTintColor(.white, renderingMode: .alwaysOriginal))
    slider?.button.accessibilityLabel = "Inhalt öffnen"
    slider?.button.accessibilityHint = "Ressorts und Artikel als Liste"
    slider?.button.backgroundColor = Const.SetColor.CIColor.color
    slider?.buttonAlpha = 1.0
    slider?.closedBottonImageOffsetX = 0.0
    header.leftConstraint?.constant = 8 + (slider?.visibleButtonWidth ?? 0.0)
    ///enable shadow for sliderView
    slider?.sliderView.clipsToBounds = false
    slider?.onOpen{[weak self] _ in
      Usage.track(Usage.event.drawer.action_open.Open, name: "Logo Tap")
      Notification.send(Const.NotificationNames.helpProviderChanged)
      self?.slider?.button.accessibilityLabel = "Inhalt schließen"
      self?.slider?.button.accessibilityHint = nil
      self?.updateAccessibility(postLayoutChanged: true)
    }
    slider?.onClose{[weak self] _ in
      guard self?.navigationController?.topViewController == self else { return }
      Notification.send(Const.NotificationNames.helpProviderChanged)
      self?.slider?.button.accessibilityLabel = "Inhalt öffnen"
      self?.slider?.button.accessibilityHint = "Ressorts und Artikel als Liste"
      self?.updateAccessibility(postLayoutChanged: true)
    }
  }
  
  public func applyStyles() {
    settingsBottomSheet?.color = Const.SetColor.HBackground.color
    settingsBottomSheet?.handleColor = Const.SetColor.ios(.opaqueSeparator).color
    settingsBottomSheet?.shadeView.backgroundColor = Const.SetColor.taz(.shade).color
    settingsBottomSheet?.xButton.tazX()
    self.scrollView.backgroundColor = Const.SetColor.HBackground.color
    self.view.backgroundColor = Const.SetColor.HBackground.color
    self.scrollView.indicatorStyle = Defaults.darkMode ?  .white : .black
    slider?.sliderView.shadow()
    slider?.button.shadow()
    updateWebwiews()
  }
  
  open override var preferredStatusBarStyle: UIStatusBarStyle {
    return Defaults.darkMode ?  .lightContent : .default
  }
  
  func updateWebwiews(_ callback: (()->())? = nil){
    if isImageOverlay { return }
    //log(">>> before reloading webViews with rowWidth: \(rowWidth)")
    writeTazApiCss {[weak self] in
      self?.reloadLoaded = true
      //self?.log(">>> reloading webViews with rowWidth: \(self?.rowWidth ?? 0)")
      self?.reloadAllWebViews()
      self?.reloadLoaded = false
      callback?()
    }
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if sizeChanged {
      sizeChanged = false
      onMainAfter {[weak self] in
        self?.updateWebwiews()
      }
    }
  }
  
  private var sizeChanged = false
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if self.view.frame.size != size {
      sizeChanged = true
    }
    updateSliderWidth(newParentWidth: size.width)
    settingsBottomSheet?.updateMaxWidth(for: size.width)
    onMain(after: 0.7) {[weak self] in
      guard let self = self else { return }
      let oldCoverage = self.settingsBottomSheet?.coverage ?? 0
      let newCoverage = self.bottomSheetDefaultCoverage
      if abs(oldCoverage - newCoverage) < 2 { return }//no rotate
      ///**Tip** If there are update with issues, look in git history former the menu was closed and re-opened to fix this
      self.settingsBottomSheet?.coverage =  newCoverage
      self.slider?.applyImage(open: self.slider?.isOpen ?? false)
    }
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    ensureToolbarInFrontOfTapButtons()
  }
  
  /// ensures that left/right tap buttons are behind tollbar and content slider
  func ensureToolbarInFrontOfTapButtons(){
    toolBar.bringToFront()
    slider?.sliderView.bringToFront()
    slider?.button.bringToFront()
  }
  
  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.scrollView.backgroundColor = Const.SetColor.HBackground.color
    self.view.backgroundColor = Const.SetColor.HBackground.color
    self.accessibilityElements = accessibilityViews
  }
  
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    #warning("move this to get rid of UITableViewAlertForLayoutOutsideViewHierarchy  (SymbolicBreakpoint) Error")
    slider?.close()
    self.settingsBottomSheet?.close()
    if let overlay = imageOverlay { overlay.close(animated: false) }
    if let io = issueObserver {
      Notification.remove(observer: io)
    }
    Notification.remove(observer: self)
  }
  
  public func setup(contents: [Content], isLargeHeader: Bool) {
    setContents(contents)
    self.isLargeHeader = isLargeHeader
    self.pager.baseDir = feeder.baseDir.path
    onBack { [weak self] _ in
      self?.debug("*** Action: <Back> pressed")
      self?.navigationController?.popViewController(animated: true)
    }
    onHome { [weak self] _ in
      self?.debug("*** Action: <Home> pressed")
      self?.resetIssueList()
      self?.navigationController?.popToRootViewController(animated: true)
    }
    if let io = issueObserver {
      Notification.remove(observer: io)
    }
    
    issueObserver = Notification.receiveOnce("issue", from: issue) { [weak self] notif in
      self?.reloadAllWebViews()
    }
  }
 
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(urls: [], baseDir: nil)
    hidesBottomBarWhenPushed = true
  }  
   
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


extension Defaults {
  static var multiColumnMode: Bool {
    return UIDevice.isPortrait && Defaults.singleton["multiColumnModePortrait"]?.bool ?? false
    || UIDevice.isLandscape && Defaults.singleton["multiColumnModeLandscape"]?.bool ?? false
  }
}

// MARK: - ContentVC Accessibility
/**
 A ContentVC is a view controller that displays an array of Articles or Sections
 in a collection of WebViews
 */
extension ContentVC {
  
  @objc var nextItemAccessibilityLabel: String? { return nil }
  @objc var prevItemAccessibilityLabel: String? { return nil }
  
  @objc override public var accessibilityViews: [UIView] {
    var elements: [UIView] = [] ///NOT: super.accessibilityViews, different Order here!
    if let imgVC = imageOverlay?.overlayVC as? ContentImageVC {
      elements = [imgVC.view, imgVC.xButton]
      elements.appendIfPresent(ArticlePlayer.accessibilityToggleButtonIfPresent)
      elements.appendIfPresent(HelpBusiness.accessibileHelpButton)
      elements.appendIfPresent(ArticlePlayer.accessibilityCloseButtonIfPresent)
    }
    else if slider?.isOpen == true {
      let contentTable
      = (self as? SectionVC)?.contentTable
      ?? ((self as? ArticleVC)?.adelegate as? SectionVC)?.contentTable
      elements.appendIfPresent(slider?.button)
      elements.appendIfPresent(ArticlePlayer.accessibilityToggleButtonIfPresent)
      elements.appendIfPresent(ArticlePlayer.accessibilityCloseButtonIfPresent)
      elements.appendIfPresent(contentTable?.headerListenLabel)
      elements.appendIfPresent(HelpBusiness.accessibileHelpButton)
      elements.appendIfPresent(contentTable?.headerCollapseIcon)
      elements.appendIfPresent(contentTable?.tableView)
    } else {
      elements.append(header)
      elements.appendIfPresent(slider?.button)
      elements.appendIfPresent(ArticlePlayer.accessibilityToggleButtonIfPresent)
      elements.appendIfPresent(ArticlePlayer.accessibilityCloseButtonIfPresent)
      ///Only append next/prev Buttons id label is set
      leftTapEnEdgeButton.accessibilityLabel = prevItemAccessibilityLabel
      if leftTapEnEdgeButton.accessibilityLabel != nil {
        elements.append(leftTapEnEdgeButton)
      }
      rightTapEnEdgeButton.accessibilityLabel = nextItemAccessibilityLabel
      if rightTapEnEdgeButton.accessibilityLabel != nil {
        elements.append(rightTapEnEdgeButton)
      }
      elements.appendIfPresent(HelpBusiness.accessibileHelpButton)
      elements.append(toolBar)
      elements.appendIfPresent(pager.currentActive)
    }
    return elements
  }
  
  func updateAccessibility(postLayoutChanged:Bool){
    self.view.accessibilityElements = self.accessibilityViews
    if postLayoutChanged {
      UIAccessibility.post(notification: .layoutChanged,
                           argument: self.view)
    }
  }
}

