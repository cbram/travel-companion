import SwiftUI
import CoreData

struct MemoryCreationExample: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingMemoryCreation = false
    
    // Sample data for demo
    @State private var selectedTrip: Trip?
    @State private var currentUser: User?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Memory Creation Demo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Erstelle neue Reise-Erinnerungen mit GPS und Fotos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // Demo Content
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                        Text("Kamera & Galerie Integration")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                        Text("Automatische GPS-Koordinaten")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(.orange)
                        Text("Offline-Speicherung")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "cylinder.fill")
                            .foregroundColor(.purple)
                        Text("Core Data Integration")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Create Memory Button
                Button(action: {
                    setupDemoData()
                    showingMemoryCreation = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Neue Erinnerung erstellen")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Text("Hinweis: Stellt sicher, dass GPS-Berechtigung erteilt ist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("TravelCompanion")
        }
        .sheet(isPresented: $showingMemoryCreation) {
            if let trip = selectedTrip, let user = currentUser {
                MemoryCreationView(trip: trip, user: user)
            }
        }
        .onAppear {
            setupDemoData()
        }
    }
    
    private func setupDemoData() {
        // Create or fetch demo user and trip
        if currentUser == nil {
            currentUser = createDemoUser()
        }
        
        if selectedTrip == nil {
            selectedTrip = createDemoTrip(for: currentUser!)
        }
    }
    
    private func createDemoUser() -> User {
        let user = User(context: viewContext)
        user.id = UUID()
        user.email = "demo@travelcompanion.com"
        user.displayName = "Demo Benutzer"
        user.createdAt = Date()
        user.isActive = true
        
        try? viewContext.save()
        return user
    }
    
    private func createDemoTrip(for user: User) -> Trip {
        let trip = Trip(context: viewContext)
        trip.id = UUID()
        trip.title = "Demo Reise"
        trip.tripDescription = "Eine wunderbare Demo-Reise"
        trip.startDate = Date()
        trip.isActive = true
        trip.createdAt = Date()
        trip.owner = user
        
        try? viewContext.save()
        return trip
    }
}

// MARK: - Alternative Integration Beispiel

struct TripDetailView: View {
    let trip: Trip
    let user: User
    
    @State private var showingMemoryCreation = false
    @FetchRequest private var memories: FetchedResults<Memory>
    
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        
        // Fetch memories for this trip
        self._memories = FetchRequest(
            entity: Memory.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)],
            predicate: NSPredicate(format: "trip == %@", trip)
        )
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Trip Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.title ?? "Unbekannte Reise")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let description = trip.tripDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Gestartet am \(trip.startDate ?? Date(), style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Memories List
                ForEach(memories, id: \.id) { memory in
                    MemoryRowView(memory: memory)
                }
                
                if memories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Noch keine Erinnerungen")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Erstelle deine erste Reise-Erinnerung!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                }
            }
            .padding()
        }
        .navigationTitle("Reise Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingMemoryCreation = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingMemoryCreation) {
            MemoryCreationView(trip: trip, user: user)
        }
    }
}

struct MemoryRowView: View {
    let memory: Memory
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail or placeholder
            if let photo = memory.photos?.first as? Photo,
               let localURL = photo.localURL,
               let image = UIImage(contentsOfFile: localURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title ?? "Unbekannt")
                    .font(.headline)
                    .lineLimit(1)
                
                if let content = memory.content {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(memory.timestamp ?? Date(), style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("\(memory.latitude, specifier: "%.2f"), \(memory.longitude, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

struct MemoryCreationExample_Previews: PreviewProvider {
    static var previews: some View {
        MemoryCreationExample()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 