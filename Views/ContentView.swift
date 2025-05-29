import SwiftUI
import CoreData

/// Haupt-Content View mit TabView Integration für die TravelCompanion App
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timeline Tab (Haupt-Tab)
            TimelineView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "clock.fill" : "clock")
                    Text("Timeline")
                }
                .tag(0)
            
            // Map Tab (Vorbereitung für zukünftige Implementation)
            MapPlaceholderView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "map.fill" : "map")
                    Text("Karte")
                }
                .tag(1)
            
            // Trips Tab (Vorbereitung für zukünftige Implementation)
            TripsPlaceholderView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "suitcase.fill" : "suitcase")
                    Text("Reisen")
                }
                .tag(2)
            
            // Profile Tab (Vorbereitung für zukünftige Implementation)
            ProfilePlaceholderView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profil")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        // Customize TabBar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Shadow
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        appearance.shadowImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Placeholder Views für zukünftige Tabs

/// Placeholder View für die Karten-Funktionalität
struct MapPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Karten-Ansicht")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Hier werden alle deine Footsteps auf einer interaktiven Karte angezeigt.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 8) {
                    Text("Geplante Features:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("MapKit Integration", systemImage: "checkmark.circle")
                        Label("Footstep-Marker", systemImage: "checkmark.circle")
                        Label("Route-Anzeige", systemImage: "checkmark.circle")
                        Label("Clustering", systemImage: "checkmark.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Karte")
        }
    }
}

/// Placeholder View für die Trip-Verwaltung
struct TripsPlaceholderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
    )
    private var trips: FetchedResults<Trip>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "suitcase")
                    .font(.system(size: 60))
                    .foregroundColor(.green.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Reisen-Verwaltung")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Verwalte deine Reisen und organisiere deine Footsteps.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Aktuelle Trips anzeigen
                if trips.isEmpty {
                    Text("Noch keine Reisen vorhanden")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aktuelle Reisen (\(trips.count)):")
                            .font(.headline)
                        
                        ForEach(trips.prefix(3), id: \.objectID) { trip in
                            HStack {
                                Image(systemName: "suitcase.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text(trip.title ?? "Unbekannte Reise")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(trip.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                VStack(spacing: 8) {
                    Text("Geplante Features:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Trip-Erstellung & -Bearbeitung", systemImage: "checkmark.circle")
                        Label("Teilnehmer-Verwaltung", systemImage: "checkmark.circle")
                        Label("Trip-Statistiken", systemImage: "checkmark.circle")
                        Label("Export-Funktionen", systemImage: "checkmark.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reisen")
        }
    }
}

/// Placeholder View für das Benutzer-Profil
struct ProfilePlaceholderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.createdAt, ascending: false)]
    )
    private var users: FetchedResults<User>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: false)]
    )
    private var footsteps: FetchedResults<Footstep>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Profile Image Placeholder
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text(users.first?.displayName ?? "Demo User")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(users.first?.email ?? "user@example.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Stats Grid
                statsGrid
                
                VStack(spacing: 8) {
                    Text("Geplante Features:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Benutzer-Einstellungen", systemImage: "checkmark.circle")
                        Label("Account-Verwaltung", systemImage: "checkmark.circle")
                        Label("Datenschutz-Optionen", systemImage: "checkmark.circle")
                        Label("App-Einstellungen", systemImage: "checkmark.circle")
                        Label("Daten-Export", systemImage: "checkmark.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profil")
        }
    }
    
    @ViewBuilder
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Memories",
                value: "\(footsteps.count)",
                icon: "camera.fill",
                color: .blue
            )
            
            StatCard(
                title: "Fotos",
                value: "\(footsteps.reduce(0) { $0 + $1.photoCount })",
                icon: "photo.fill",
                color: .green
            )
            
            StatCard(
                title: "Reisen",
                value: "\(Set(footsteps.compactMap { $0.trip }).count)",
                icon: "suitcase.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
    }
}

/// Kleine Statistik-Karte für das Profil
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 