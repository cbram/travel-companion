import SwiftUI
import CoreData

/// Timeline View zeigt alle Memories der aktiven Reise chronologisch an
struct TimelineView: View {
    @StateObject private var tripManager = TripManager.shared
    @State private var showingMemoryCreation = false
    @Environment(\.managedObjectContext) private var viewContext
    
    // Korrekte Initialisierung des FetchRequest
    @State private var memories: [Memory] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                if let currentTrip = tripManager.currentTrip {
                    if memories.isEmpty {
                        emptyStateView(for: currentTrip)
                    } else {
                        timelineListView(for: currentTrip)
                    }
                } else {
                    noActiveTripView
                }
                
                // Floating Action Button für neue Memories
                if tripManager.currentTrip != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingMemoryCreation = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.blue))
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingMemoryCreation) {
                MemoryCreationView()
            }
            .onAppear {
                loadMemories()
            }
            .onChange(of: tripManager.currentTrip) { _ in
                loadMemories()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var navigationTitle: String {
        if let tripTitle = tripManager.currentTrip?.title {
            return tripTitle
        }
        return "Timeline"
    }
    
    // MARK: - No Active Trip View
    private var noActiveTripView: some View {
        VStack(spacing: 24) {
            Image(systemName: "suitcase.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("Keine aktive Reise")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Wählen Sie eine Reise aus oder erstellen Sie eine neue, um Ihre Memories zu sehen.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            NavigationLink(destination: TripsListView()) {
                HStack {
                    Image(systemName: "suitcase.fill")
                    Text("Zu den Reisen")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
    }
    
    // MARK: - Empty State View
    private func emptyStateView(for trip: Trip) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Noch keine Memories")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Erstellen Sie Ihr erstes Memory für '\(trip.title ?? "diese Reise")' und dokumentieren Sie Ihre Abenteuer.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                showingMemoryCreation = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Erstes Memory erstellen")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
    }
    
    // MARK: - Timeline List View
    private func timelineListView(for trip: Trip) -> some View {
        List {
            // Trip Header
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "suitcase.fill")
                            .foregroundColor(.blue)
                        Text(trip.title ?? "Reise")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        if trip.isActive {
                            Text("AKTIV")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let description = trip.tripDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Trip Statistiken
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(memories.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Memories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedDuration(for: trip))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Dauer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.blue.opacity(0.05))
            
            // Memories Timeline
            Section("Memories") {
                ForEach(memories, id: \.objectID) { memory in
                    MemoryTimelineRowView(memory: memory)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            loadMemories()
        }
    }
    
    // MARK: - Data Loading
    private func loadMemories() {
        guard let currentTrip = tripManager.currentTrip else {
            memories = []
            return
        }
        
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", currentTrip)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        
        do {
            memories = try viewContext.fetch(request)
        } catch {
            print("❌ TimelineView: Fehler beim Laden der Memories: \(error)")
            memories = []
        }
    }
    
    // MARK: - Helper Methods
    private func formattedDuration(for trip: Trip) -> String {
        let startDate = trip.startDate ?? Date()
        let endDate = trip.endDate ?? Date()
        let duration = endDate.timeIntervalSince(startDate)
        
        if duration <= 0 {
            return "Laufend"
        }
        
        let days = Int(duration) / (24 * 3600)
        if days > 0 {
            return "\(days) Tag\(days == 1 ? "" : "e")"
        } else {
            let hours = Int(duration) / 3600
            return "\(hours) Stunde\(hours == 1 ? "" : "n")"
        }
    }
}

/// Einzelne Memory-Row in der Timeline
struct MemoryTimelineRowView: View {
    let memory: Memory
    
    var body: some View {
        HStack(spacing: 16) {
            // Zeitlinie-Indikator
            VStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            // Memory Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(memory.title ?? "Memory")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let content = memory.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Fotos Preview (falls vorhanden)
                if let photos = memory.photos?.allObjects as? [Photo], !photos.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.blue)
                        Text("\(photos.count) Foto\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                // Location Info
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: memory.timestamp ?? Date())
    }
    
    private var formattedLocation: String {
        return String(format: "%.4f°, %.4f°", memory.latitude, memory.longitude)
    }
}

// MARK: - Preview
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 