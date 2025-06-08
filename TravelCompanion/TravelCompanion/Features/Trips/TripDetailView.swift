import SwiftUI

/// Detailansicht für eine Reise mit Edit- und Management-Funktionen
struct TripManagementView: View {
    let trip: Trip
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingEditSheet = false
    @State private var showingEndTripAlert = false
    @State private var showingDeleteAlert = false
    
    var isActiveTrip: Bool {
        trip == tripManager.currentTrip
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                headerSection
                
                // Quick Actions
                quickActionsSection
                
                // Statistics Section
                statisticsSection
                
                // Memories Section
                memoriesSection
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle(trip.formattedTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Edit Trip
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        Label("Reise bearbeiten", systemImage: "pencil")
                    }
                    
                    // Activate/Deactivate Trip
                    if isActiveTrip {
                        Button(action: {
                            showingEndTripAlert = true
                        }) {
                            Label("Reise beenden", systemImage: "stop.circle")
                        }
                    } else {
                        Button(action: {
                            Task {
                                await tripManager.setActiveTrip(trip)
                            }
                        }) {
                            Label("Reise aktivieren", systemImage: "play.circle")
                        }
                    }
                    
                    Divider()
                    
                    // Delete Trip
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Reise löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TripEditView(trip: trip)
        }
        .alert("Reise beenden", isPresented: $showingEndTripAlert) {
            Button("Beenden", role: .destructive) {
                Task {
                    await tripManager.endCurrentTrip()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchten Sie diese Reise beenden? Das GPS-Tracking wird gestoppt.")
        }
        .alert("Reise löschen", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                Task {
                    await tripManager.deleteTrip(trip)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchten Sie diese Reise wirklich löschen? Alle Memories und Fotos gehen verloren.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Badge
            HStack {
                statusBadge
                Spacer()
            }
            
            // Beschreibung
            if let description = trip.tripDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Datum
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text(formattedDateRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    private var statusBadge: some View {
        Group {
            if isActiveTrip {
                Label("AKTIV", systemImage: "location.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(16)
            } else if trip.endDate != nil {
                Label("BEENDET", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .cornerRadius(16)
            } else {
                Label("GEPLANT", systemImage: "calendar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aktionen")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Activate/End Trip Button
                if isActiveTrip {
                    TripActionButton(
                        title: "Reise beenden",
                        icon: "stop.circle.fill",
                        color: .red,
                        action: { showingEndTripAlert = true }
                    )
                } else if trip.endDate == nil {
                    TripActionButton(
                        title: "Aktivieren",
                        icon: "play.circle.fill",
                        color: .green,
                        action: {
                            Task {
                                await tripManager.setActiveTrip(trip)
                            }
                        }
                    )
                }
                
                // Edit Trip Button
                TripActionButton(
                    title: "Bearbeiten",
                    icon: "pencil.circle.fill",
                    color: .blue,
                    action: { showingEditSheet = true }
                )

                // GPS-Track anzeigen Button
                if #available(iOS 17.0, *) {
                    NavigationLink(destination: GPSTrackView(trip: trip)) {
                        TripActionButton(
                            title: "GPS-Track",
                            icon: "map.fill",
                            color: .purple,
                            action: {}
                        )
                    }
                    .buttonStyle(PlainButtonStyle()) // Verhindert, dass der Link wie ein normaler Button aussieht
                }
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistiken")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                StatisticCard(
                    title: "Memories",
                    value: "\(trip.memoriesCount)",
                    icon: "location.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Dauer",
                    value: trip.formattedDuration,
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatisticCard(
                    title: "Teilnehmer",
                    value: "\(trip.participantsCount)",
                    icon: "person.2.fill",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Memories Section
    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Memories")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Alle anzeigen") {
                    // TODO: Navigation zu einer vollen Memories-Liste
                }
                .font(.subheadline)
            }
            
            // Memories List
            if !trip.memoriesArray.isEmpty {
                LazyVStack(spacing: 20) {
                    ForEach(trip.memoriesArray) { memory in
                        memoryCardView(for: memory)
                    }
                }
            } else {
                emptyMemoriesView
            }
        }
    }
    
    private func memoryHeader(for memory: Memory) -> some View {
        HStack(spacing: 12) {
            Text(memory.author?.initials ?? "U")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(memory.author?.displayName ?? "Unbekannter Nutzer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("📍 \(memory.location.formattedCoordinates)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private func memoryCardView(for memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Memory Header
            memoryHeader(for: memory)
            
            // Memory Image (falls vorhanden) - FIXED: Instagram-Style Full Width
            if let photo = memory.photosArray.first, let uiImage = photo.loadUIImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 300) // ✅ Volle Breite, max Höhe für Instagram-Look
                    .clipped()
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
            
            // Memory Content
            VStack(alignment: .leading, spacing: 8) {
                Text(memory.formattedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(memory.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var emptyMemoriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.circle")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("Noch keine Memories")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Starten Sie Ihre Reise und sammeln Sie Erinnerungen!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Computed Properties
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        
        guard let startDate = trip.startDate else { return "Unbekannt" }
        
        if let endDate = trip.endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return "Seit \(formatter.string(from: startDate))"
        }
    }
}

// MARK: - Supporting Views
struct TripActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .cornerRadius(12)
        }
    }
}

struct StatisticCard: View {
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TripMemoryRowView: View {
    let memory: Memory
    
    var body: some View {
        HStack(spacing: 12) {
            // Memory Icon
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                )
            
            // Memory Info
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.formattedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(memory.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Photo Count (wenn vorhanden)
            if memory.photosCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(memory.photosCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Trip Edit View
struct TripEditView: View {
    let trip: Trip
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var tripManager: TripManager
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startDate: Date = Date()
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reise-Details")) {
                    TextField("Titel", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                    
                    DatePicker("Startdatum", selection: $startDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Reise bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task {
                           await saveTrip()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        title = trip.title ?? ""
        description = trip.tripDescription ?? ""
        startDate = trip.startDate ?? Date()
    }
    
    private func saveTrip() async {
        isSaving = true
        
        // Update trip properties
        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.tripDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.startDate = startDate
        
        // Save to Core Data
        if CoreDataManager.shared.save() {
            print("✅ Trip erfolgreich aktualisiert")
            await tripManager.refreshTrips()
            presentationMode.wrappedValue.dismiss()
        } else {
            print("❌ Fehler beim Speichern des Trips")
        }
        
        isSaving = false
    }
}

// MARK: - Preview
struct TripManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TripManagementView(trip: SampleDataCreator.createSampleTrip())
        }
        .environmentObject(TripManager.shared)
        .environmentObject(UserManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 