# taz.neo


WTF

(M124 2025-07-10 00:18:27) BackgroundDownloadService.prepareIfResoucesUpdateRequired(issueMinResourceVersion:localResources:remoteResourceBaseUrl:feederContext:isBackground:) Info:
  need to download 124 updated resource files

(T111 2025-07-10 00:18:23) BackgroundDownloadService.downloadResourcesIfNeeded(isBackground:) Info:
  updatedResourcesFiles contains: 0 files

Background Resources Update alalysing log Protokoll_25-07-09_13/57/15.txt
✅❌⚠️
Auf dem Gerät
- Test Server, push token geholt, live server, offline app restart, background ✅
- send push.✅..analyse

Log:
- TazAppEnvironment.setupFeeder     resourceVersion = 213 
✅ ist vom TestServer
-  feederStatus: product...:publicationDates(start:"2024-07-25") 
✅ ist testServer
- ... NSErrorFailingURLStringKey=https://dl.taz.de/appGraphQl,  
✅ Live Server Aktiv
- BackgroundDownloadService.fetchFromRemote(isBackground:) Info: lastLocalIssueDate: 25.7.2024 
⚠️ unerwartet: macht gleich mal ein offline fetch der BG Download, kommt von Resume??? 
- GqlFeeder.latestIssueAndFeed(feed:key:isPages:withAudio:latestKnownPublicationDate:returnOnMain:isBackGround:) Info:
  ...fetch issue/feed data for taz return on Main: false **inBackground: false** last issue: , latestKnownPublicationDate: 2024-07-25
✅ nicht im BG MODUS!! 
**TODO: ANALYSIERE!!** ist das deaktivierbar? nach feederContext und Network Status? was passiert bei online wird korrekt geladen (... nach diesem Testplan ...Testserver...)
- BackgroundDownloadService.scheduleBackgroundIssueCheck(earliestBeginDate:) Info:
  Scheduling background task at 09.07.25 13:56:59 (in 59s)
✅ der scheduleBackgroundIssueCheck wird nach fehlschlag richtig eingereiht
**TODO: ANALYSIERE!!** teste damit den schedule check!!!
- BackgroundDownloadService.doCheckForNewIssue(isPush:isBackground:_:) Info: ❌ Autodownload Error: 
✅ schlägt wie zu erwarten fehl
...
(T73 2025-07-09 13:55:59) BackgroundDownloadService.applicationRestarted(with:) Info:
  ...loaded data for issue: 2024-07-25
(T74 2025-07-09 13:55:59) BackgroundDownloadService.applicationRestarted(with:) Info:
  DownloadData for issue: 2024-07-25 found issue is: not downloaded
(T75 2025-07-09 13:55:59) BackgroundDownloadService.applicationRestarted(with:) Info:
  ⚠️ Failed to load data for issue 2024-07-25: BackgroundDownloadError(message: "No Download found for Issue...remove DownloadData")
(T76 2025-07-09 13:55:59) BackgroundDownloadService.applicationRestarted(with:) Info:
  Delete Default for: 2024-07-25
**TODO: ANALYSIERE!!** ist das so korrekt?
lösche die download daten bei Resume wenn offline? Was ist mit richtigen Downloads?

(M88 2025-07-09 13:56:00) AppDelegate.applicationDidEnterBackground(_:) Info:
  enter background: background
**OK**
  (M89 2025-07-09 13:56:24) FeederContext.netStatusChanged(isConnected:) Info:
  NET STATUS CHANGED isConnected: true 
**SCHLECHT!**
jetzt macht er einen GqlFeeder.feederStatus bekommt die neuen PubDates und die Ressourcen
...eigentlich ganz gut ABER
**Werden die Ressourcen jetzt 2x geladen?**

**❌❌❌ Wieso muss ich das Ressourcen ZIP laden, obwohl nur 1-2Dateien aktualisiert wurden? ❌❌❌**

3 AUFGABEN:
...finde alle resources raus, die sich aktualisiert haben
...lade nur die aktualisierten Resources
...verwende nur eine BG Session!!!



wie komme ich an meine lokalen ressourcen?

es soll ja nur eine Resources geben also StoredResources 



iOS-App for reading the "taz" digital newspaper

## Author

Norbert Thies, norbert@taz.de   
Ringo Müller, https://github.com/bochos-bln

## License

taz.neo is available under the AGPL. See the LICENSE file for more info.


## Setup & Requirements
- Place the "North Lib" Project Library directory next to the taz.neo directory
- **may add post-checkout hook by:**
  - mkdir .git/hooks
  - cp taz.neo/Supporting\ Files/Scripts/post-checkout-prototype.sh .git/hooks/post-checkout
  - chmod u+x .git/hooks/post-checkout
- **may generate (gitignored) BuildConst.swift && ConfigSettings.xcconfig by:**
  - ruby taz.neo/Supporting\ Files/Scripts/genBuildConst.rb -D
  To get rid of: "Build input file cannot be found: '~/src/TAZ/taz-neo.ios/taz.neo/Supporting Files/Scripts/BuildConst.swift'"
- may add fonts and other optional files
- run (with latest released Xcode) and enjoy

## Branching & Release Builds
- there are 3 permanent branches: release, beta, alpha
  - **release** branch
     - contains production code, anything here is: deployable, code-reviewed, tested
       - review code on merge (Pair Code Review)
       - use pull requests!
       - test after merge
     - usually only merge from beta or hotfix-??? branches to release branch
     - use the beta branch fo merge and test different features and fixes 
     - a merge to release branch is usually associated with a release Build (at lease a Release Candidate) 
     - after App Store Publishing the related Commit gets the related Tag with the Version Number
  - **beta** branch
     - development start from here and (finally) target the beta branch
     - review code on merge (reviewer should be a 2nd person: 4-eyes / two-men rule)
     - test merged code
     - sync with master frequently (at least after/before Release)
   - **alpha** branch
     - review code on merge (reviewer is the developer)
     - sync with master/beta frequently (at least after/before Release)
 - there is no permanent **lmd** branch, lmd is a feature branch which should be merged from release or beta and merged to alpha/beta
    - when lmd branch is merged to beta, a Build/SMoke Test is required on the lmd target
- there are additionally temporary branches: hotfix-someStrangeBugFix, feature-aNewFeature
  - **hotfix-...** branch
     - branched from release, targeting release
   - **feature-...** branch
     - project is buildable
     - frequently pull latest changed from one of the permanent branches (release, beta, alpha)
     - merge demo/preview from feature branches to alpha branch with a code review (by developer) 

### Alpha Builds **de.taz.taz.neo**
- should be created from "alpha" Branch
- should have the App Name: "taz.alpha"
- has a taz App Icon with an additional ⍺

### Beta Builds **de.taz.taz.beta**
- should be created from "beta" Branch
- should have the App Name: "taz.beta"
- currently have no Push Notifications
- has a taz App Icon with an additional ß

### App Store Builds **de.taz.taz.2**
- should be created from "release" Branch
- should have the App Name: "die tageszeitung"
- has the default taz App Icon

### Debug run and App Archiving
- change the BundleID/App name (above) depending on current git branch (in post-checkout hook @see above: Setup...)
- in archive step, check if local git is in sync with desired branch in official repository to support the requirements from above for beta and Release Builds
- there is just 1 Target for the app
- builds number scheme ist autogenerated within yyyMMdd??

### Branch & Environment Switch while Xcode is running
- Attention: Xcode ignores changes in current xcschemes (and project) file(s) so:
  - Option 1: restart xcode   
    close xcode by:    
    >> kill $(ps aux | grep 'Xcode' | awk '{print $2}')   
    >> cd ~/src/TAZ/taz-neo.ios/taz.neo/Supporting\ Files/Scripts   
    >> ./changeConfiguration.sh Alpha|Beta|Release   
    open xcode with:    
    >> xed   
  - Option 2: delete content of:   
    ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex   
    and   
    ~/Library/Developer/Xcode/DerivedData/taz.neo   
    to tell xcode to re-read theese files   
- **Change environment** (alpha|betarelease) from commandline, in taz.neo project dir:   
    >> ./taz.neo/Supporting\ Files/Scripts/refreshEnvironment.sh alpha
- **generate current build number** (without commit and remote check)   
    >> ruby taz.neo/Supporting\ Files/Scripts/genBuildConst.rb -in

