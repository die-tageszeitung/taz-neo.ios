//
//  DownloadStatusButtonExtension.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import NorthLib

extension DownloadStatusButton {
  func setStatus(from issue:Issue?){
    if issue?.isDownloading ?? false{
      indicator.downloadState = .waiting
    }
    else if issue?.status.downloaded ?? false {
      indicator.downloadState = .done
    }
    else {
      indicator.downloadState = .notStarted
    }
  }
}
