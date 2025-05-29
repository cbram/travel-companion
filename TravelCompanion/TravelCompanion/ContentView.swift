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
            setupInitialData()
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
    
    private func setupInitialData() {
        // Überprüfe ob Sample Data benötigt wird
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let users = try viewContext.fetch(userRequest)
            let trips = try viewContext.fetch(tripRequest)
            
            // Erstelle Sample Data falls leer
            if users.isEmpty || trips.isEmpty {
                createInitialData()
            }
        } catch {
            print("❌ ContentView: Fehler beim Überprüfen der initialen Daten: \(error)")
            createInitialData()
        }
    }
    
    private func createInitialData() {
        print("🏗️ ContentView: Erstelle initiale Sample-Daten...")
        
        // Erstelle einen Sample User
        let user = User(context: viewContext)
        user.email = "user@travelcompanion.app"
        user.displayName = "Reisender"
        user.createdAt = Date()
        user.isActive = true
        
        // Erstelle einen Default Trip
        let trip = Trip(context: viewContext)
        trip.title = "Meine erste Reise"
        trip.tripDescription = "Willkommen bei TravelCompanion!"
        trip.startDate = Date()
        trip.createdAt = Date()
        trip.isActive = true
        trip.owner = user
        
        // Speichere Änderungen
        do {
            try viewContext.save()
            print("✅ ContentView: Sample-Daten erstellt")
        } catch {
            print("❌ ContentView: Fehler beim Speichern der Sample-Daten: \(error)")
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
