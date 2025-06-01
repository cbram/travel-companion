import SwiftUI
import CoreData

/// Timeline View zeigt alle Memories der aktiven Reise chronologisch an
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingMemoryCreation = false
    @State private var selectedTrip: Trip?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Fetch alle Memories für automatische Updates
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)],
        animation: .default
    ) private var allMemories: FetchedResults<Memory>
    
    // Fetch alle Trips für Auswahl
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.createdAt, ascending: false)],
        animation: .default
    ) private var allTrips: FetchedResults<Trip>
    
    // Computed property für aktive Trip
    private var activeTrip: Trip? {
        allTrips.first { $0.isActive }
    }
    
    // Gefilterte Memories für aktive Trip
    private var filteredMemories: [Memory] {
        guard let trip = selectedTrip ?? activeTrip else { return [] }
        return allMemories.filter { $0.trip == trip }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if let currentTrip = selectedTrip ?? activeTrip {
                    if filteredMemories.isEmpty {
                        emptyStateView(for: currentTrip)
                    } else {
                        timelineListView(for: currentTrip)
                    }
                } else {
                    noActiveTripView
                }
                
                // Floating Action Button für neue Memories
                if (selectedTrip ?? activeTrip) != nil {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if allTrips.count > 1 {
                        Menu {
                            ForEach(allTrips, id: \.objectID) { trip in
                                Button(action: {
                                    selectedTrip = trip
                                }) {
                                    HStack {
                                        Text(trip.title ?? "Unbenannte Reise")
                                        if trip.isActive {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                        if trip == selectedTrip {
                                            Image(systemName: "eye.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button("Alle Reisen") {
                                selectedTrip = nil
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Aktualisieren") {
                        refreshData()
                    }
                }
            }
            .sheet(isPresented: $showingMemoryCreation) {
                MemoryCreationView()
            }
            .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .refreshable {
                refreshData()
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    // MARK: - Computed Properties
    private var navigationTitle: String {
        if let trip = selectedTrip {
            return trip.title ?? "Timeline"
        } else if let activeTrip = activeTrip {
            return activeTrip.title ?? "Timeline"
        }
        return "Timeline"
    }
    
    // MARK: - Setup Methods
    private func setupInitialData() {
        // Wenn keine Trips vorhanden sind, erstelle Sample Data
        if allTrips.isEmpty {
            print("📝 TimelineView: Keine Trips gefunden, erstelle Sample Data")
            createSampleDataIfNeeded()
        }
        
        // Wenn kein aktiver Trip vorhanden ist, setze den ersten als aktiv
        if activeTrip == nil, let firstTrip = allTrips.first {
            setTripActive(firstTrip)
        }
    }
    
    private func createSampleDataIfNeeded() {
        SampleDataCreator.createSampleData(in: viewContext)
        do {
            try viewContext.save()
            print("✅ TimelineView: Sample Data erfolgreich erstellt")
        } catch {
            print("❌ TimelineView: Fehler beim Erstellen von Sample Data: \(error)")
            errorMessage = "Fehler beim Laden der Daten: \(error.localizedDescription)"
        }
    }
    
    private func setTripActive(_ trip: Trip) {
        // Alle anderen Trips deaktivieren
        allTrips.forEach { $0.isActive = false }
        // Ausgewählten Trip aktivieren
        trip.isActive = true
        
        do {
            try viewContext.save()
            print("✅ TimelineView: Trip '\(trip.title ?? "Unknown")' als aktiv gesetzt")
        } catch {
            print("❌ TimelineView: Fehler beim Setzen des aktiven Trips: \(error)")
            errorMessage = "Fehler beim Aktivieren der Reise: \(error.localizedDescription)"
        }
    }
    
    private func refreshData() {
        withAnimation {
            isLoading = true
        }
        
        // Core Data Context refreshen
        viewContext.refreshAllObjects()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isLoading = false
            }
        }
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
            
            Button(action: {
                if let firstTrip = allTrips.first {
                    setTripActive(firstTrip)
                } else {
                    createSampleDataIfNeeded()
                }
            }) {
                HStack {
                    Image(systemName: allTrips.isEmpty ? "plus.circle.fill" : "suitcase.fill")
                    Text(allTrips.isEmpty ? "Erste Reise erstellen" : "Erste Reise aktivieren")
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
                            Text("\(filteredMemories.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Memories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.formattedDuration)
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
            Section("Memories (\(filteredMemories.count))") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Lade Memories...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(filteredMemories, id: \.objectID) { memory in
                        InstagramStyleMemoryView(memory: memory)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            refreshData()
        }
    }
}

/// Instagram-ähnliche Memory-Darstellung in der Timeline
struct InstagramStyleMemoryView: View {
    let memory: Memory
    @State private var currentPhotoIndex = 0
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header mit User Info
            headerView
            
            // Foto Carousel
            photoCarouselView
            
            // Action Buttons
            actionButtonsView
            
            // Content
            contentView
            
            // Timestamp
            timestampView
        }
        .background(Color(.systemBackground))
        .cornerRadius(0)
        .onAppear {
            loadImages()
        }
    }
    
    // MARK: - Photo Carousel
    @ViewBuilder
    private var photoCarouselView: some View {
        if loadedImages.isEmpty && !isLoadingImages {
            // Fallback für Memories ohne echte Fotos - zeige Demo-Foto
            AsyncImage(url: URL(string: "https://picsum.photos/400/500?random=\(abs(memory.objectID.hashValue) % 1000 + 1)")) { image in
                image
                    .resizable()
                    .aspectRatio(4/5, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(4/5, contentMode: .fill)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
            .frame(maxHeight: 400)
        } else if isLoadingImages {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(4/5, contentMode: .fill)
                .overlay(
                    ProgressView("Lade Fotos...")
                        .tint(.white)
                )
                .frame(maxHeight: 400)
        } else if loadedImages.count == 1 {
            // Einzelnes Foto
            Image(uiImage: loadedImages[0])
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: 400)
                .clipped()
        } else {
            // Mehrere Fotos - Carousel
            TabView(selection: $currentPhotoIndex) {
                ForEach(0..<loadedImages.count, id: \.self) { index in
                    Image(uiImage: loadedImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 400)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(maxHeight: 400)
            .overlay(alignment: .topTrailing) {
                // Photo Counter
                if loadedImages.count > 1 {
                    Text("\(currentPhotoIndex + 1)/\(loadedImages.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadImages() {
        guard !isLoadingImages, loadedImages.isEmpty else { return }
        
        isLoadingImages = true
        let photosArray = memory.photosArray
        
        Task {
            var images: [UIImage] = []
            
            for photo in photosArray {
                if let image = photo.loadUIImage() {
                    images.append(image)
                }
            }
            
            await MainActor.run {
                self.loadedImages = images
                self.isLoadingImages = false
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            // Avatar (Kreis mit Initialen)
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(memory.author?.initials ?? "?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.author?.displayName ?? "Unbekannt")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(memory.formattedLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: {}) {
                Image(systemName: "heart")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Button(action: {}) {
                Image(systemName: "message")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Button(action: {}) {
                Image(systemName: "paperplane")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titel
            Text(memory.title ?? "Memory")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Beschreibung
            if let content = memory.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Timestamp View
    private var timestampView: some View {
        Text(memory.formattedTimestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}

// MARK: - Preview
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 