//
//  screenfree_writerApp.swift
//  screenfree_writer
//
//  Created by Louise on 2025/3/13.
//

import SwiftUI

@main
struct screenfree_writerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
