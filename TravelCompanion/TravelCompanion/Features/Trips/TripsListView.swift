import SwiftUI

/// View zur Anzeige und Verwaltung aller Reisen
/// Zeigt Liste mit aktiver Reise, ermöglicht Wechsel und Löschen
struct TripsListView: View {
    @StateObject private var viewModel = TripsListViewModel()
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    @State private var showingTripCreation = false
    @State private var showingQuickActions = false
    @State private var selectedTrip: Trip?
    
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
                // Refresh über TripManager
                tripManager.refreshTrips()
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
                Text("Möchten Sie diese Reise wirklich löschen? Alle Memories und Fotos gehen verloren.")
            }
            .confirmationDialog("Reise verwalten", isPresented: $showingQuickActions, presenting: selectedTrip) { trip in
                Button("Reise beenden") {
                    tripManager.endCurrentTrip()
                }
                
                Button("Bearbeiten") {
                    // Navigation zur TripDetailView wird automatisch gehandhabt
                }
                
                Button("Löschen", role: .destructive) {
                    tripManager.deleteTrip(trip)
                }
                
                Button("Abbrechen", role: .cancel) { }
            } message: { trip in
                Text("Aktionen für \(trip.formattedTitle)")
            }
        }
        .onAppear {
            viewModel.setTripManager(tripManager)
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
                NavigationLink(
                    destination: TripManagementView(trip: trip)
                        .environmentObject(tripManager)
                        .environmentObject(userManager)
                ) {
                    TripRowView(
                        trip: trip,
                        isActive: trip == tripManager.currentTrip,
                        onTap: {
                            // Navigation wird automatisch durch NavigationLink gehandhabt
                        },
                        onLongPress: {
                            // Quick Actions für aktive Reise
                            if trip == tripManager.currentTrip {
                                showQuickActions(for: trip)
                            }
                        }
                    )
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: deleteTrips)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helper Methods
    private func deleteTrips(offsets: IndexSet) {
        for index in offsets {
            let trip = tripManager.allTrips[index]
            tripManager.deleteTrip(trip)
        }
    }
    
    private func showQuickActions(for trip: Trip) {
        selectedTrip = trip
        showingQuickActions = true
    }
}

/// Einzelne Trip-Row in der Liste
struct TripRowView: View {
    let trip: Trip
    let isActive: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
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
                    
                    // Memories Count
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(trip.memoriesCount) Memories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Dauer
                    Text(trip.formattedDuration)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.green.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onLongPressGesture {
            if isActive {
                onLongPress()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        
        guard let startDate = trip.startDate else { return "Unbekannt" }
        
        if let endDate = trip.endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return "Seit \(formatter.string(from: startDate))"
        }
    }
}

/// ViewModel für TripsListView
@MainActor
class TripsListViewModel: ObservableObject {
    @Published var showDeleteConfirmation = false
    @Published var tripToDelete: Trip?
    
    private var tripManager: TripManager?
    
    func setTripManager(_ manager: TripManager) {
        tripManager = manager
    }
    
    func selectTrip(_ trip: Trip) {
        tripManager?.setActiveTrip(trip)
    }
    
    func deleteTrip(_ trip: Trip) {
        tripToDelete = trip
        showDeleteConfirmation = true
    }
    
    func confirmDelete() {
        guard let trip = tripToDelete else { return }
        tripManager?.deleteTrip(trip)
        tripToDelete = nil
    }
}

// MARK: - Preview
struct TripsListView_Previews: PreviewProvider {
    static var previews: some View {
        TripsListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(TripManager.shared)
            .environmentObject(UserManager.shared)
    }
} 