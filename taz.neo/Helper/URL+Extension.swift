//
//  URL+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.03.26.
//  Copyright © 2026 taz. All rights reserved.
//

import Foundation
import UIKit

extension URL {

  /// Opens the URL via `UIApplication` and performs advertisement tap tracking
  /// if the URL matches the `dl.taz.de/anzstat` tracking endpoint.
  ///
  /// If the URL contains an `id` query parameter, this identifier is sent
  /// to the analytics system as an advertisement tap event before the URL
  /// is opened.
  ///
  /// - Note: If the URL cannot be opened by the system (`canOpenURL == false`)
  ///   nothing happens.
  func openLinkAndTrackAdIfNeeded() {
    trackAdIfNeeded()
    guard UIApplication.shared.canOpenURL(self) else { return }
    UIApplication.shared.open(self, options: [:], completionHandler: nil)
  }

  /// Checks whether the URL is a `dl.taz.de/anzstat` tracking URL and,
  /// if so, extracts the `id` query parameter and reports it as an
  /// advertisement tap event.
  ///
  /// Example tracking URL:
  /// `https://dl.taz.de/anzstat?...&id=TrackingID1234`
  ///
  /// If the URL does not match the expected host/path or no `id` parameter
  /// is present, the function silently returns.
  private func trackAdIfNeeded() {
    guard self.absoluteString.contains("dl.taz.de/anzstat") else { return }

    guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
          let adIdentifier = components.queryItems?.first(where: { $0.name == "id" })?.value
    else { return }

    Usage.track(Usage.event.advertisement.adTapped, name: adIdentifier)
  }
}
