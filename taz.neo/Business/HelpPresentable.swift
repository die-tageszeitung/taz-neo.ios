//
//  HelpPresentable.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.25.
//  Copyright © 2025 taz. All rights reserved.
//


/// Jeder VC der Hilfe anbieten möchte, implementiert dieses Protokoll
protocol HelpPresentable where Self: UIViewController {
    /// Wird aufgerufen wenn der globale Help Button getippt wird
    func openHelp()
}