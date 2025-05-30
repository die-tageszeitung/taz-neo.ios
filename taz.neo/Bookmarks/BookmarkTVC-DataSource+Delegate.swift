//
//  BookmarkTVC-DataSource+Delegate.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// MARK: - BookmarkTVC Helper for UITableViewDataSource UITableViewDelegate

/// BookmarkTVC Helper for UITableViewDataSource UITableViewDelegate
extension BookmarkTVC {
  
  fileprivate func article(for indexPath: IndexPath) -> Article? {
    let sectionKey = sortedSectionKeys[indexPath.section]
    guard let articlesForSection = groupedArticles[sectionKey] else { return nil }
    if indexPath.row - 1  > articlesForSection.count { return nil }
    return articlesForSection[indexPath.row - 1]
  }
}

// MARK: - BookmarkTVC: UITableViewDataSource

extension BookmarkTVC: UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    groupedArticles.keys.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionKey = sortedSectionKeys[section]
    return (groupedArticles[sectionKey]?.count ?? -1) + 1
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.row == 0 {
      // Header-Zelle
      guard let headerCell = tableView.dequeueReusableCell(withIdentifier: BookmarkTableHeaderCell.ReuseIdentifier, for: indexPath) as? BookmarkTableHeaderCell,
            let feed = Bookmarks.shared.bookmarkIssue?.feed as? StoredFeed else { return BookmarkTableHeaderCell() }
      
      let article = article(for: IndexPath(item: 1, section: indexPath.section))
      headerCell.dateLabel.text
      = App.isLMD
      ? article?.issueDate?.stringWith(dateFormat: "MMMM YYYY")
      : article?.issueDate?.validityDateText(timeZone: GqlFeeder.tz, feed: feed)
      headerCell.image = Bookmarks.lowresMomentImage(for: article)
      return headerCell
    }
    
    guard let cell
            = tableView.dequeueReusableCell(withIdentifier: BookmarksCell.ReuseIdentifier,
                                            for: indexPath) as? BookmarksCell,
          let article = article(for: indexPath) else { return BookmarksCell() }
    cell.article = article
    
    cell.onShare { [weak self] (art, sourceView) in
      self?.shareArticle(article: art, sourceView: sourceView)
    }
    
    
    if let issue = article.primaryIssue {
      cell.image = cell.article?.images?.first?.image(dir: issue.dir)?.invertedIfNeeded
    }
    else if let issueDate = article.issueDate,
            let dir = Bookmarks.shared.commonIssueDir(for: issueDate) {
      cell.image = cell.article?.images?.first?.image(dir: dir)?.invertedIfNeeded
    }
    
    let sectionKey = sortedSectionKeys[indexPath.section]
    cell.dottedLine.isHidden = groupedArticles[sectionKey]?.count == indexPath.row
    return cell
  }
}

// MARK: - UITableViewDelegate
extension BookmarkTVC: UITableViewDelegate {
  
  // MARK: - Cell....
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row > 0 { return UITableView.automaticDimension }
    return indexPath.section == 0 ? 57.0 + Const.Dist2.m20 : 57.0
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let cell = tableView.cellForRow(at: indexPath) as? BookmarkTableHeaderCell,
       let article = article(for: IndexPath(item: 1, section: indexPath.section)) {
      Notification.send(Const.NotificationNames.gotoIssue, content: article.issueDate, sender: self)
    }
    
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article else { return }
    open(article: article)
  }
  
  // MARK: - Cell Swipe
  
  func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article
    else { return nil }
    let openIssueAction = UIContextualAction(style: .normal, title: "Ausgabe\nanzeigen", handler: {[weak self] (_, _, completionHandler) in
      Notification.send(Const.NotificationNames.gotoIssue, content: article.issueDate, sender: self)
      completionHandler(true)
    }
    )
    // Show Current Cloud Upload Status
    openIssueAction.backgroundColor = .systemGreen
    openIssueAction.image = UIImage(systemName: "arrowshape.turn.up.right")//?.imageWith(size: CGSize(width: 20, height: 25), tintColor: .white)
    let swipeConfiguration = UISwipeActionsConfiguration(actions: [openIssueAction])
    return swipeConfiguration
  }
  
  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article
    else { return nil }
    let deleteAction = UIContextualAction(style: .destructive, title: "löschen", handler: {(_, _, completionHandler) in
      self.removeBookmarkArticleCell(at: indexPath, article: article)
      Bookmarks.set(article: article, bookmarked: false)
      completionHandler(true)
    }
    )
    // Show Current Cloud Upload Status
    deleteAction.image = UIImage(systemName: "trash")//?.imageWith(size: CGSize(width: 20, height: 25), tintColor: .white)
    let swipeConfiguration = UISwipeActionsConfiguration(actions: [deleteAction])
    return swipeConfiguration
  }
  
  // MARK: - Footer
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 0.7
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    if section == sortedSectionKeys.count - 1 { return nil }
    return tableView.dequeueReusableHeaderFooterView(withIdentifier: TableSectionSeperatorFooterView.ReuseIdentifier)
  }
}
