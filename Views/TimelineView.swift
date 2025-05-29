import SwiftUI
import CoreData

/// Haupt-Timeline Ansicht mit chronologischer Memory-Darstellung
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: TimelineViewModel
    @State private var showingMemoryCreation = false
    @State private var selectedMemory: Footstep?
    
    // Sample User und Trip für Memory-Erstellung
    @State private var currentUser: User?
    @State private var currentTrip: Trip?
    
    // FetchRequest für Performance-optimierte Darstellung
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Footstep.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var footsteps: FetchedResults<Footstep>
    
    init() {
        self._viewModel = StateObject(wrappedValue: TimelineViewModel(managedObjectContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Content
                contentView
                
                // Floating Action Button
                floatingActionButton
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterButton
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    statsButton
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Erinnerungen durchsuchen...")
            .refreshable {
                await refreshTimeline()
            }
            .sheet(isPresented: $showingMemoryCreation) {
                memoryCreationSheet
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                filterSheet
            }
            .alert("Erinnerung löschen", isPresented: $viewModel.showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    viewModel.confirmDelete()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du diese Erinnerung wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .alert("Fehler", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                setupInitialData()
            }
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if footsteps.isEmpty {
            EmptyStateView(
                hasFilters: viewModel.hasActiveFilters,
                onCreateFirstMemory: {
                    showingMemoryCreation = true
                },
                onClearFilters: viewModel.hasActiveFilters ? {
                    viewModel.clearFilters()
                } : nil
            )
        } else {
            timelineList
        }
    }
    
    // MARK: - Timeline List
    @ViewBuilder
    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Filter-Info Banner (wenn aktiv)
                if viewModel.hasActiveFilters {
                    filterInfoBanner
                }
                
                // Timeline Header mit Statistiken
                timelineHeader
                
                // Memory Cards
                ForEach(footsteps, id: \.objectID) { footstep in
                    MemoryCardView(
                        footstep: footstep,
                        onEdit: {
                            selectedMemory = footstep
                            // Hier würde zur Memory-Edit View navigiert werden
                        },
                        onDelete: {
                            viewModel.deleteFootstep(footstep)
                        }
                    )
                    .padding(.horizontal, 16)
                    .onAppear {
                        // Pagination: Lade mehr wenn nahe am Ende
                        if footstep == footsteps.last {
                            viewModel.loadMoreFootsteps()
                        }
                    }
                }
                
                // Load More Indicator
                if viewModel.isLoadingMore {
                    loadMoreIndicator
                }
                
                // Bottom Spacing für Floating Button
                Spacer()
                    .frame(height: 100)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Timeline Header
    @ViewBuilder
    private var timelineHeader: some View {
        VStack(spacing: 16) {
            // Datum Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heute")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick Stats
                quickStatsView
            }
            .padding(.horizontal, 16)
            
            // Divider
            Divider()
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Quick Stats View
    @ViewBuilder
    private var quickStatsView: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(footsteps.count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Memories")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 2) {
                Text("\(footsteps.reduce(0) { $0 + $1.photoCount })")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Fotos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Filter Info Banner
    @ViewBuilder
    private var filterInfoBanner: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Filter aktiv")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("\(viewModel.activeFilterCount) Filter angewendet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Zurücksetzen") {
                viewModel.clearFilters()
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Load More Indicator
    @ViewBuilder
    private var loadMoreIndicator: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Lade weitere Erinnerungen...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Floating Action Button
    @ViewBuilder
    private var floatingActionButton: some View {
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
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingMemoryCreation)
                
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    @ViewBuilder
    private var filterButton: some View {
        Button(action: {
            viewModel.showingFilterSheet = true
        }) {
            ZStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                
                if viewModel.hasActiveFilters {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var statsButton: some View {
        Button(action: {
            // Hier würde zur Stats-View navigiert werden
        }) {
            Image(systemName: "chart.bar.fill")
        }
    }
    
    // MARK: - Sheets
    @ViewBuilder
    private var memoryCreationSheet: some View {
        if let user = currentUser, let trip = currentTrip {
            EnhancedMemoryCreationView(trip: trip, user: user)
        } else {
            Text("Lade...")
                .onAppear {
                    setupInitialData()
                }
        }
    }
    
    @ViewBuilder
    private var filterSheet: some View {
        NavigationView {
            TimelineFilterView(viewModel: viewModel)
        }
    }
    
    // MARK: - Methods
    
    @MainActor
    private func refreshTimeline() async {
        viewModel.refreshTimeline()
        
        // Warte auf Refresh-Completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func setupInitialData() {
        // Suche oder erstelle Test-User und Trip
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let users = try viewContext.fetch(userRequest)
            let trips = try viewContext.fetch(tripRequest)
            
            if let user = users.first, let trip = trips.first {
                currentUser = user
                currentTrip = trip
            } else {
                // Erstelle Sample Data falls noch nicht vorhanden
                createSampleData()
            }
        } catch {
            print("Fehler beim Laden der Daten: \(error)")
            createSampleData()
        }
    }
    
    private func createSampleData() {
        // Erstelle einen Sample User
        let user = User(context: viewContext)
        user.id = UUID()
        user.email = "user@example.com"
        user.displayName = "Demo User"
        user.createdAt = Date()
        user.isActive = true
        
        // Erstelle einen Sample Trip
        let trip = Trip(context: viewContext)
        trip.id = UUID()
        trip.title = "Meine Reise"
        trip.tripDescription = "Standard Reise für neue Memories"
        trip.startDate = Date()
        trip.isActive = true
        trip.createdAt = Date()
        trip.owner = user
        
        // Speichern
        do {
            try viewContext.save()
            currentUser = user
            currentTrip = trip
        } catch {
            print("Fehler beim Erstellen der Sample Daten: \(error)")
        }
    }
}

// MARK: - Timeline Filter View
struct TimelineFilterView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
    )
    private var trips: FetchedResults<Trip>
    
    var body: some View {
        Form {
            Section("Reise") {
                Picker("Reise auswählen", selection: $viewModel.selectedTrip) {
                    Text("Alle Reisen").tag(nil as Trip?)
                    ForEach(trips, id: \.objectID) { trip in
                        Text(trip.title ?? "Unbekannte Reise").tag(trip as Trip?)
                    }
                }
            }
            
            Section("Zeitraum") {
                if let dateRange = viewModel.dateRange {
                    VStack(alignment: .leading) {
                        Text("Von: \(dateRange.lowerBound.formatted(date: .abbreviated, time: .omitted))")
                        Text("Bis: \(dateRange.upperBound.formatted(date: .abbreviated, time: .omitted))")
                    }
                    
                    Button("Zeitraum entfernen") {
                        viewModel.dateRange = nil
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Zeitraum auswählen") {
                        // Hier würde ein Date Range Picker geöffnet
                    }
                }
            }
            
            Section {
                Button("Alle Filter zurücksetzen") {
                    viewModel.clearFilters()
                }
                .foregroundColor(.red)
                .disabled(!viewModel.hasActiveFilters)
            }
        }
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fertig") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 