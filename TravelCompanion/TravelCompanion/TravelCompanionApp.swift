//
//  TravelCompanionApp.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import SwiftUI

@main
struct TravelCompanionApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
