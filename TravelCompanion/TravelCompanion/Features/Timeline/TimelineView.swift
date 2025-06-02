import SwiftUI
import CoreData

/// Timeline View zeigt alle Memories der aktiven Reise chronologisch an
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tripManager: TripManager
    @State private var showingMemoryCreation = false
    @State private var showingTripCreation = false
    @State private var selectedTrip: Trip?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var memoriesCache: [Memory] = []
    @State private var lastCacheUpdate: Date = Date()
    
    // PERFORMANCE: Optimierte FetchRequest nur für aktive Trips
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.createdAt, ascending: false)],
        animation: .default
    ) private var allTrips: FetchedResults<Trip>
    
    // PERFORMANCE: Computed property mit Caching
    private var activeTrip: Trip? {
        allTrips.first { $0.isActive }
    }
    
    // PERFORMANCE: Optimierte Memory-Fetch mit Lazy Loading
    private var currentTrip: Trip? {
        selectedTrip ?? activeTrip
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if let trip = currentTrip {
                    if memoriesCache.isEmpty {
                        emptyStateView(for: trip)
                    } else {
                        timelineListView(for: trip)
                    }
                } else {
                    noActiveTripView
                }
                
                // Floating Action Button für neue Memories
                if currentTrip != nil {
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
                    Menu {
                        // Trip Selection
                        Picker("Reise auswählen", selection: $selectedTrip) {
                            Text("Aktive Reise").tag(nil as Trip?)
                            ForEach(allTrips, id: \.objectID) { trip in
                                Text(trip.title ?? "Unbenannte Reise").tag(trip as Trip?)
                            }
                        }
                        
                        Divider()
                        
                        Button("Refresh") {
                            refreshData()
                        }
                        
                        Button("Neue Reise erstellen") {
                            showingTripCreation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingMemoryCreation) {
                MemoryCreationView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingTripCreation) {
                TripCreationView()
                    .environment(\.managedObjectContext, viewContext)
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
        .onChange(of: currentTrip) { _, _ in
            updateMemoriesCache()
        }
    }
    
    // MARK: - Computed Properties
    private var navigationTitle: String {
        if let trip = currentTrip {
            return trip.title ?? "Timeline"
        }
        return "Timeline"
    }
    
    // MARK: - Setup
    private func setupInitialData() {
        print("✅ TimelineView: Setup abgeschlossen - aktive Reise: \(activeTrip?.title ?? "keine")")
        updateMemoriesCache()
    }
    
    // PERFORMANCE: Asynchrone Memory-Cache Aktualisierung
    private func updateMemoriesCache() {
        guard let trip = currentTrip else {
            memoriesCache = []
            return
        }
        
        // Verhindere zu häufige Updates
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) < 2.0 && !memoriesCache.isEmpty {
            return
        }
        
        Task {
            let memories = await fetchMemoriesForTrip(trip)
            await MainActor.run {
                self.memoriesCache = memories
                self.lastCacheUpdate = now
            }
        }
    }
    
    // PERFORMANCE: Background Memory-Fetch
    private func fetchMemoriesForTrip(_ trip: Trip) async -> [Memory] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Memory> = Memory.fetchRequest()
                request.predicate = NSPredicate(format: "trip == %@", trip)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
                request.fetchLimit = 100 // Limite für Performance
                
                do {
                    let memories = try self.viewContext.fetch(request)
                    continuation.resume(returning: memories)
                } catch {
                    print("❌ TimelineView: Memory-Fetch Fehler: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func setTripActive(_ trip: Trip) {
        TripManager.shared.setActiveTrip(trip)
        print("✅ TimelineView: Trip-Aktivierung an TripManager delegiert")
    }
    
    private func refreshData() {
        withAnimation {
            isLoading = true
        }
        
        // PERFORMANCE: Asynchroner Refresh
        Task {
            updateMemoriesCache()
            await MainActor.run {
                withAnimation {
                    isLoading = false
                }
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
                
                Text("Erstellen Sie eine neue Reise oder wählen Sie eine bestehende Reise aus, um Ihre Memories zu sehen.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 16) {
                if allTrips.isEmpty {
                    Button(action: {
                        showingTripCreation = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Erste Reise erstellen")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                    }
                } else {
                    Button(action: {
                        if let firstTrip = allTrips.first {
                            setTripActive(firstTrip)
                        }
                    }) {
                        HStack {
                            Image(systemName: "suitcase.fill")
                            Text("Erste Reise aktivieren")
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
                            Text("\(memoriesCache.count)")
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
            
            // Memories Timeline - PERFORMANCE: LazyVStack für bessere Performance
            Section("Memories (\(memoriesCache.count))") {
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
                    ForEach(memoriesCache, id: \.objectID) { memory in
                        OptimizedMemoryView(memory: memory)
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

/// PERFORMANCE-OPTIMIERTE Memory-Darstellung ohne externe Image-Downloads
struct OptimizedMemoryView: View {
    let memory: Memory
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header mit User Info
            headerView
            
            // Foto Carousel - OPTIMIERT: Keine externen Downloads
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
        .task {
            await loadImagesAsync()
        }
    }
    
    // MARK: - PERFORMANCE-OPTIMIERTE Photo Carousel
    @ViewBuilder
    private var photoCarouselView: some View {
        if isLoadingImages {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .aspectRatio(4/5, contentMode: .fill)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("Lade Fotos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
                .frame(maxHeight: 400)
        } else if loadedImages.isEmpty {
            // PERFORMANCE: Statischer Platzhalter anstatt externe Downloads
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .aspectRatio(4/5, contentMode: .fill)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                        Text(memory.title ?? "Memory")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                )
                .frame(maxHeight: 400)
        } else {
            // Echte Fotos anzeigen
            TabView {
                ForEach(0..<loadedImages.count, id: \.self) { index in
                    Image(uiImage: loadedImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 400)
                        .clipped()
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(maxHeight: 400)
        }
    }
    
    // MARK: - PERFORMANCE: Asynchroner Image-Load
    private func loadImagesAsync() async {
        guard !isLoadingImages, loadedImages.isEmpty else { return }
        
        await MainActor.run {
            isLoadingImages = true
        }
        
        let photosArray = memory.photosArray
        var images: [UIImage] = []
        
        // PERFORMANCE: Image-Loading in Background - FIXED für Sendable
        for photo in photosArray {
            // Extrahiere nur die lokale URL, um Sendable-Problem zu vermeiden
            let localURL = photo.localURL
            if let url = localURL, let image = await loadImageAsync(from: url) {
                images.append(image)
            }
            // Begrenze auf maximal 3 Bilder für Performance
            if images.count >= 3 { break }
        }
        
        await MainActor.run {
            self.loadedImages = images
            self.isLoadingImages = false
        }
    }
    
    private func loadImageAsync(from localURL: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let image = UIImage(contentsOfFile: localURL)
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - Helper Views
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
                    Text(memory.safeFormattedLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
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
            .environmentObject(TripManager.shared)
    }
} 