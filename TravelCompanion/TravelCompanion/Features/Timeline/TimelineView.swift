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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(memoriesCache, id: \.objectID) { memory in
                            InstagramStyleMemoryCard(memory: memory)
                                .padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 10)
                }
                .navigationTitle("Timeline")
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
                .refreshable {
                    refreshData()
                }
                
                // ✅ FLOATING ACTION BUTTON für neue Memories
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
        }
        .onAppear {
            setupInitialData()
        }
        .onChange(of: currentTrip) { _, _ in
            updateMemoriesCache()
        }
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
    
    private func setTripActive(_ trip: Trip) async {
        await TripManager.shared.setActiveTrip(trip)
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
                            Task {
                                await setTripActive(firstTrip)
                            }
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
}

// MARK: - Instagram-Style Memory Card
struct InstagramStyleMemoryCard: View {
    let memory: Memory
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (User Info)
            headerSection
            
            // Main Photo - INSTAGRAM STYLE
            photoSection
            
            // Action Buttons
            actionButtonsSection
            
            // Content
            contentSection
            
            // Timestamp
            timestampSection
        }
        .background(Color(.systemBackground))
        .onAppear {
            loadPhotoIfNeeded()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // User Avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(memory.author?.initials ?? "?")
                        .font(.system(size: 14, weight: .semibold))
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
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Photo Section - ECHTES INSTAGRAM LAYOUT
    private var photoSection: some View {
        Group {
            if isLoading {
                // Loading State
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            } else if let image = loadedImage {
                // INSTAGRAM-STYLE: Echtes Foto in voller Breite
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: calculateOptimalHeight(for: image)
                    )
                    .clipped()
            } else {
                // Fallback: Kein Foto
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                            Text(memory.title ?? "Memory")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    )
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
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
            
            Button(action: {}) {
                Image(systemName: "bookmark")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            if let title = memory.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
            }
            
            // Description
            if let content = memory.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .lineLimit(nil)
            }
        }
    }
    
    // MARK: - Timestamp
    private var timestampSection: some View {
        Text(memory.formattedTimestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
    
    // MARK: - Photo Loading
    private func loadPhotoIfNeeded() {
        guard loadedImage == nil else { return }
        
        Task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        guard let firstPhoto = memory.photosArray.first,
              let localURL = firstPhoto.localURL else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // Load image from local URL
        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let loadedImage = UIImage(contentsOfFile: localURL)
                continuation.resume(returning: loadedImage)
            }
        }
        
        await MainActor.run {
            self.loadedImage = image
            self.isLoading = false
        }
    }
    
    // MARK: - Helper Methods
    private func calculateOptimalHeight(for image: UIImage) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let aspectRatio = image.size.height / image.size.width
        let calculatedHeight = screenWidth * aspectRatio
        
        // Instagram-like height constraints (200-600px)
        return min(max(calculatedHeight, 200), 600)
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