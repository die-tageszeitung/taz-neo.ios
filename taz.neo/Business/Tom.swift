//
//  Tom.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.03.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import Foundation

class Tom {
  static func toms(issue: Issue) -> [Article] {
    createDirsIfNeeded()
    var arts: [Article] = []
    
    for tom in tomFiles {
      let art = VirtualArticle()
      let fe = TmpFileEntry(name: "\(tom).html")
      fe.path = Dir.tomsPath + "/\(tom).html"
      fe.content = tomHtml(tom)
      art.primaryIssue = issue
      art.html = fe
      if tom == "tom_12" {
        art.title = "Das Ende ist da!"
      }
      else {
        art.title = "Das Ende ist nah!"
      }
      arts += art
    }
    return arts
  }
  
  static func tomHtml(_ tom: String) -> String {
    
    let onclick
    = tom == tomFiles.last
    ? "onclick=\"tazApi.gotoStart();\""
    : ""
    
    return """
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <meta http-equiv="Content-Type" content="text/html" charset="utf-8">
        <title>Das Ende ist nah!</title>
        <script src="resources/tazApi.js" type="text/javascript" charset="utf-8" language="javascript">
        </script>
        <style>
          body, html {
            margin: 0;
            overflow: hidden;
            background-color: transparent;
         }
         img {/*landscape/default*/
          transform: translate(-50%, 0%);
          left: 50%;
          bottom: -23%;
          position: fixed;
          height: 110%;
          border: 0.7px solid black;
          border-radius: 2px;
         }
        @media (max-aspect-ratio: 0.6) {/*portrait*/
          img {
            border: none;
            width: 100%;
            height: inherit;
            bottom: -10%;
          }
        }
      }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <img alt="Tom Karikatur" \(onclick) src="\(tom).png"/>
      </div>
    </body>
  </html>
  """
  }
  /**
  Aspect Ratios:
   iPad landscape 1.2...1.5     1366/1024 = 1.333
   iPad hochformat: 0.5...1.2    1024/1366 = 0.74
   Image Ratio Bild 1.5 => 1.4 ist Schwellwert
   Ipad Hochformat slideover: 375/1224  = 0.3
   */
  
  static let tomFiles = ["tom_01", "tom_02", "tom_03", "tom_04", "tom_05", "tom_06", "tom_07", "tom_08", "tom_09", "tom_10", "tom_11", "tom_12"]
  
  static func createDirsIfNeeded(){
    let dir = Dir.tomsDir
    
    if dir.exists { return }
    
    dir.create()
    let rlink = File(dir: dir.path, fname: "resources")
    let glink = File(dir: dir.path, fname: "global")
    
    guard let feederContext = TazAppEnvironment.sharedInstance.feederContext else { return }
    
    if !rlink.isLink { rlink.link(to: feederContext.gqlFeeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feederContext.gqlFeeder.globalDir.path) }
    
    for filename in tomFiles {
      if let url = Bundle.main.url(forResource: filename, withExtension: "png", subdirectory: "BundledResources") {
        let file = File(url.path )
        file.copy(to: dir.path.appending("/\(filename).png"))
      }
    }
    
  }
}

extension File {
  /// returns the searchResults directory
  public static var tomsPath: String {
    return TazAppEnvironment.sharedInstance.feederContext?.storedFeeder.baseDir.path.appending("/tmp-toms")
    ?? Dir.appSupportPath.appending("/tmp-toms")
  }
  
  /// returns the toms directory
  public static var tomsDir: Dir {
    return Dir(Dir.tomsPath)
  }
}
