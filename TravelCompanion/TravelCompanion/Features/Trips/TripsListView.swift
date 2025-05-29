import SwiftUI

/// View zur Anzeige und Verwaltung aller Reisen
/// Zeigt Liste mit aktiver Reise, ermöglicht Wechsel und Löschen
struct TripsListView: View {
    @StateObject private var viewModel = TripsListViewModel()
    @StateObject private var tripManager = TripManager.shared
    @State private var showingTripCreation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Hauptinhalt
                if tripManager.allTrips.isEmpty {
                    emptyStateView
                } else {
                    tripsListView
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingTripCreation = true
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
            .navigationTitle("Meine Reisen")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshTrips()
            }
            .sheet(isPresented: $showingTripCreation) {
                TripCreationView()
            }
            .alert("Reise löschen", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Löschen", role: .destructive) {
                    viewModel.confirmDelete()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchten Sie diese Reise wirklich löschen? Alle Footsteps und Fotos gehen verloren.")
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "suitcase")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("Keine Reisen vorhanden")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Erstellen Sie Ihre erste Reise und beginnen Sie Ihre Abenteuer zu dokumentieren.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
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
        }
    }
    
    // MARK: - Trips List View
    private var tripsListView: some View {
        List {
            ForEach(tripManager.allTrips, id: \.objectID) { trip in
                TripRowView(
                    trip: trip,
                    isActive: trip == tripManager.currentTrip,
                    onTap: {
                        viewModel.selectTrip(trip)
                    }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: viewModel.deleteTrips)
        }
        .listStyle(.plain)
    }
}

/// Einzelne Trip-Row in der Liste
struct TripRowView: View {
    let trip: Trip
    let isActive: Bool
    let onTap: () -> Void
    
    @StateObject private var tripManager = TripManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon und Active Indicator
                ZStack {
                    Circle()
                        .fill(isActive ? Color.green : Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isActive ? "checkmark.circle.fill" : "suitcase.fill")
                        .font(.title2)
                        .foregroundColor(isActive ? .white : .blue)
                }
                
                // Trip Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(trip.title ?? "Unbekannte Reise")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isActive {
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
                            .lineLimit(2)
                    }
                    
                    // Statistiken
                    HStack(spacing: 16) {
                        // Datum
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedDateRange)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Footsteps Count
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(footstepsCount) Orte")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Dauer
                        Text(formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        
        let startDate = trip.startDate ?? Date()
        if let endDate = trip.endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return "seit \(formatter.string(from: startDate))"
        }
    }
    
    private var formattedDuration: String {
        let stats = tripManager.getStatistics(for: trip)
        return stats.formattedDuration
    }
    
    private var footstepsCount: Int {
        let footsteps = CoreDataManager.shared.fetchFootsteps(for: trip)
        return footsteps.count
    }
}

/// ViewModel für TripsListView
class TripsListViewModel: ObservableObject {
    @Published var showDeleteConfirmation = false
    private var tripToDelete: Trip?
    
    // MARK: - Trip Selection
    func selectTrip(_ trip: Trip) {
        TripManager.shared.setActiveTrip(trip)
        print("✅ TripsListView: Reise als aktiv gesetzt: \(trip.title ?? "Unbekannt")")
    }
    
    // MARK: - Trip Deletion
    func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            let trip = TripManager.shared.allTrips[index]
            tripToDelete = trip
            showDeleteConfirmation = true
            break // Nur eine Reise zur Zeit löschen
        }
    }
    
    func confirmDelete() {
        guard let trip = tripToDelete else { return }
        
        TripManager.shared.deleteTrip(trip)
        tripToDelete = nil
        
        print("✅ TripsListView: Reise gelöscht: \(trip.title ?? "Unbekannt")")
    }
    
    // MARK: - Refresh
    func refreshTrips() async {
        // Kurze Verzögerung für Pull-to-Refresh Animation
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        DispatchQueue.main.async {
            // TripManager lädt automatisch bei Core Data Änderungen
            print("🔄 TripsListView: Reisen aktualisiert")
        }
    }
}

// MARK: - Preview
struct TripsListView_Previews: PreviewProvider {
    static var previews: some View {
        TripsListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 