//
//  ArticlePlayer+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 13.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

extension ArticlePlayer: HelpProviding {  
  var helpItems: [HelpItem] {
    
    let minimize = HelpItem(title:"Player verkleinern",
                        text: "Tippen Sie auf den Pfeil, um den Player zu verkleinern. Die Wiedergabe läuft dabei weiter.",
                          isCircleCutout: true,
                            targetView: self.userInterface.minimizeButton)
    
    let openArticle = HelpItem(title:"Zum Artikel",
                        text: "Tippen Sie auf die Überschrift (Bild oder Autor), um den Artikel wieder zu öffnen.",
                            targetView: self.userInterface.titleLabel)
    
    let readSpeed = HelpItem(title:"Vorlese\u{00AD}geschwindigkeit",
                        text: "Passen Sie hier die Geschwindigkeit der Sprachausgabe an.",
                          isCircleCutout: true,
                            targetView: self.userInterface.rateButton)
    
    let slider = HelpItem(title:"Spulen",
                        text: "Bewegen Sie den weißen Punkt, um im Text vor- oder zurückzuspringen. Links sehen Sie die vergangene, rechts die verbleibende Zeit.",
                            targetView: self.userInterface.slider)
    
    let skipBack = HelpItem(title:"Zum Anfang des Artikels",
                        text: "Tippen Sie hier, um zum Anfang des Artikels zu springen.",
                            isCircleCutout: true,
                            targetView: self.userInterface.backButton)
    
    let skipForward = HelpItem(title:"Zum nächsten Artikel",
                        text: "Tippen Sie hier, um den nächsten Artikel der Ausgabe oder Leseliste zu starten.",
                               isCircleCutout: true,
                            targetView: self.userInterface.forwardButton)
    
    let seekBack = HelpItem(title:"Zum Satzanfang",
                        text: "Tippen Sie hier, um zum Anfang des aktuellen Satzes zu springen.",
                            isCircleCutout: true,
                            targetView: self.userInterface.seekBackwardButton)
    let playPause = HelpItem(title:"Abspielen oder pausieren",
                        text: "Starten oder pausieren Sie die Wiedergabe jederzeit.",
                             isCircleCutout: true,
                            targetView: self.userInterface.toggleButton)
    let seekForeward = HelpItem(title:"Zum nächsten Satz",
                        text: "Tippen Sie hier, um zum Beginn des nächsten Satzes zu springen.",
                                isCircleCutout: true,
                            targetView: self.userInterface.seekForwardButton)

    let proTip = HelpItem(title:"Tipp: Steuerung via iOS Kontrollzentrum",
                                     text: "Sie können zur Wiedergabesteuerung – Abspielen, Pausieren, vorheriger oder nächster Artikel – auch das iOS Kontrollzentrum verwenden, ohne die App zu öffnen. So funktioniert die Steuerung auch mit Bluetooth-Geräten, Apple Watch oder CarPlay.\n\n\n\n\n\n\n")
    return [minimize, openArticle, readSpeed, slider, skipBack, skipForward, seekBack, playPause, seekForeward, proTip]
  }
  
}
