import SwiftUI
import PhotosUI
import CoreLocation

/// View für die Erstellung neuer Memories
/// Bietet vollständiges Interface mit Location, Photos und Text-Input
struct MemoryCreationView: View {
    @StateObject private var viewModel = MemoryCreationViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    
    // UI State
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    @State private var showingTripCreation = false
    @State private var showingUserCreation = false // Neue State für User-Erstellung
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    
                    // Trip Info (falls vorhanden)
                    if let trip = viewModel.trip {
                        tripInfoSection(for: trip)
                    }
                    
                    VStack(spacing: 16) {
                        titleSection
                        descriptionSection
                        locationSection
                        photoSection
                    }
                    .padding(.horizontal)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Memory erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task {
                            await viewModel.saveMemory()
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: viewModel.photoPickerItem) { _, _ in
                viewModel.loadSelectedPhoto()
            }
            .alert("Fehler", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Erfolg", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Memory wurde erfolgreich gespeichert!")
            }
            .alert("Keine aktive Reise", isPresented: $viewModel.showingNoTripAlert) {
                Button("Reise erstellen") {
                    // Prüfe erst, ob ein User vorhanden ist
                    if userManager.currentUser == nil {
                        showingUserCreation = true
                    } else {
                        showingTripCreation = true
                    }
                }
                Button("Abbrechen") {
                    dismiss()
                }
            } message: {
                Text(userManager.currentUser == nil 
                     ? "Um Memories zu erstellen, benötigst du zunächst ein Benutzerprofil und eine aktive Reise. Möchtest du jetzt einen Benutzer erstellen?"
                     : "Sie benötigen eine aktive Reise um Memories zu erstellen. Möchten Sie jetzt eine neue Reise erstellen?")
            }
            .sheet(isPresented: $showingUserCreation) {
                UserCreationView {
                    // Nach User-Erstellung automatisch TripCreation öffnen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingTripCreation = true
                    }
                }
                .environmentObject(userManager)
            }
            .sheet(isPresented: $showingTripCreation) {
                TripCreationView()
                    .environmentObject(TripManager.shared)
                    .environmentObject(userManager)
                    .onDisappear {
                        // Nach Reise-Erstellung prüfen ob jetzt eine Reise verfügbar ist
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            viewModel.setupInitialData()
                        }
                    }
            }
        }
        .onAppear {
            viewModel.checkActiveTrip()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Neue Erinnerung erstellen")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Halte deine Reisemomente fest")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private func tripInfoSection(for trip: Trip) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "suitcase.fill")
                    .foregroundColor(.blue)
                Text("Für: \(trip.title ?? "Aktuelle Reise")")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("AKTIV")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let description = trip.tripDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Titel", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Was hast du erlebt?", text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.next)
                .focused($titleFieldFocused)
                .onSubmit {
                    descriptionFieldFocused = true
                }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beschreibung", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Erzähle mehr über diesen Moment...", 
                     text: $viewModel.content, 
                     axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
                .focused($descriptionFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    hideKeyboard()
                }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Standort", systemImage: "location.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let location = viewModel.currentLocation {
                        Text("📍 \(location.formattedCoordinates)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Genauigkeit: \(location.formattedAccuracy)")
                            .font(.caption2)
                            .foregroundColor(location.horizontalAccuracy >= 0 ? .secondary : .orange)
                    } else {
                        Text("GPS-Position wird ermittelt...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button("Aktualisieren") {
                    if !viewModel.isUpdatingLocation {
                        Task {
                            await viewModel.updateLocation()
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(viewModel.isUpdatingLocation)
                .overlay(
                    Group {
                        if viewModel.isUpdatingLocation {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Foto", systemImage: "camera")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let selectedImage = viewModel.selectedImage {
                // Selected Image Preview
                VStack(spacing: 8) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                    
                    Button("Foto entfernen") {
                        viewModel.removeSelectedImage()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            } else {
                // Photo Selection Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.showCameraPicker()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Kamera")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isCameraAvailable)
                    
                    Button(action: {
                        viewModel.showPhotoPicker()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("Galerie")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        titleFieldFocused = false
        descriptionFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
struct MemoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        return MemoryCreationView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 