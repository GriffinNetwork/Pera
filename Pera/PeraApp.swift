//
//  PeraApp.swift
//  Pera
//
//  Created by Zachary Griffin on 5/14/26.
//

import SwiftUI
import CoreData

@main
struct PeraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
