//
//  ContentView.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import SwiftUI
import CoreData

/// Haupt-Content View mit TabView Navigation für die TravelCompanion App
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tripManager = TripManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timeline Tab - Zeigt Memories der aktiven Reise
            TimelineView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "clock.fill" : "clock")
                    Text("Timeline")
                }
                .tag(0)
            
            // Trips Tab - Verwaltung aller Reisen
            TripsListView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "suitcase.fill" : "suitcase")
                    Text("Reisen")
                }
                .tag(1)
            
            // Settings Tab - App-Einstellungen
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                    Text("Einstellungen")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    // MARK: - Setup Methods
    private func setupTabBarAppearance() {
        // TabBar Appearance konfigurieren
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Shadow für moderne Optik
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        appearance.shadowImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
