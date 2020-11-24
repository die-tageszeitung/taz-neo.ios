//
//  IssueInfoProtocol.swift
//  taz.neo
//
//  Created by Norbert Thies on 29.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation

/// The protocol used to communicate with calling VCs which can provide
/// infos regarding Feeder, Issue and Downloader
public protocol IssueInfo {
  /// The feeder context
  var feederContext: FeederContext { get }
  /// One Issue of a Feed
  var issue: Issue { get }
  /// Reset the list of Issues to the most current issue
  func resetIssueList()
}

public extension IssueInfo {
  /// The feeder delivering Feeds of Issues
  var feeder: Feeder { feederContext.storedFeeder }
  /// The Downloader to get data from the Feeder
  var dloader: Downloader { feederContext.dloader }
  /// The Feed containing Issues
  var feed: Feed { issue.feed }
}
