import SwiftUI
import PhotosUI
import CoreLocation
import MapKit

/// Erweiterte Memory-Erstellungs-View mit Multiple Photos, GPS-Integration und Offline-Support
struct EnhancedMemoryCreationView: View {
    @StateObject private var viewModel: EnhancedMemoryCreationViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    let trip: Trip
    let user: User
    
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        self._viewModel = StateObject(wrappedValue: EnhancedMemoryCreationViewModel(trip: trip, user: user))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Header Section
                headerSection
                
                // Eingabe Sektion
                inputSection
                
                // GPS & Location Sektion
                locationSection
                
                // Photo Sektion
                photoSection
                
                // Datum & Zeit Sektion
                dateTimeSection
                
                // Save Button
                saveSection
            }
            .navigationTitle("Neue Erinnerung")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        handleCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task {
                            await viewModel.saveMemory()
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $viewModel.showingPhotoPicker) {
                PhotoPicker(
                    selectedImages: $viewModel.selectedImages,
                    isPresented: $viewModel.showingPhotoPicker,
                    maxSelections: 5
                )
            }
            .sheet(isPresented: $viewModel.showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $viewModel.manualLocation,
                    currentLocation: viewModel.currentLocation,
                    isPresented: $viewModel.showingLocationPicker
                )
            }
            .alert("Erfolg", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Erinnerung wurde erfolgreich gespeichert!")
            }
            .alert("Fehler", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    viewModel.saveDraft()
                }
            }
            .onAppear {
                viewModel.loadDraft()
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(spacing: 4) {
                    Text("Neue Erinnerung")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("für \(trip.title ?? "Unbekannte Reise")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Status Indicators
                HStack(spacing: 16) {
                    statusIndicator(
                        icon: "location.fill",
                        label: "GPS",
                        isActive: viewModel.hasValidLocation,
                        color: viewModel.hasValidLocation ? .green : .orange
                    )
                    
                    statusIndicator(
                        icon: "photo.fill",
                        label: "\(viewModel.selectedImages.count) Fotos",
                        isActive: !viewModel.selectedImages.isEmpty,
                        color: .blue
                    )
                    
                    statusIndicator(
                        icon: "wifi",
                        label: viewModel.isOnline ? "Online" : "Offline",
                        isActive: viewModel.isOnline,
                        color: viewModel.isOnline ? .green : .orange
                    )
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    private func statusIndicator(icon: String, label: String, isActive: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(isActive ? color : .gray)
            Text(label)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .font(.caption2)
    }
    
    private var inputSection: some View {
        Section("Details") {
            // Titel (Required)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Titel", systemImage: "textformat")
                    Spacer()
                    Text("Erforderlich")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                
                TextField("Was hast du erlebt?", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
            }
            
            // Beschreibung (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Label("Beschreibung", systemImage: "text.alignleft")
                
                TextField("Erzähle mehr über diesen besonderen Moment...", 
                         text: $viewModel.content, 
                         axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }
        }
    }
    
    private var locationSection: some View {
        Section("Standort") {
            VStack(alignment: .leading, spacing: 12) {
                // Current Location Display
                if let location = viewModel.effectiveLocation {
                    locationDisplayCard(location: location)
                } else {
                    noLocationCard
                }
                
                // Location Actions
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.updateLocation()
                    }) {
                        Label("GPS aktualisieren", systemImage: "location.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isUpdatingLocation)
                    
                    Button(action: {
                        viewModel.showingLocationPicker = true
                    }) {
                        Label("Manuell wählen", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
                
                if viewModel.isUpdatingLocation {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("GPS wird aktualisiert...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func locationDisplayCard(location: CLLocation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text("Aktuelle Position")
                    .fontWeight(.medium)
                Spacer()
                
                if viewModel.manualLocation != nil {
                    Button("GPS verwenden") {
                        viewModel.useCurrentLocation()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("📍 \(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Genauigkeit: ±\(Int(location.horizontalAccuracy))m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Reverse Geocoding Adresse
                if let address = viewModel.locationAddress {
                    Text("📍 \(address)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var noLocationCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Kein GPS-Signal verfügbar")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Standort kann manuell hinzugefügt werden")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
        .cornerRadius(8)
    }
    
    private var photoSection: some View {
        Section("Fotos (\(viewModel.selectedImages.count)/5)") {
            VStack(spacing: 12) {
                // Photo Grid
                if !viewModel.selectedImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                            photoThumbnail(image: image, index: index)
                        }
                    }
                } else {
                    emptyPhotoState
                }
                
                // Add Photo Button
                Button(action: {
                    viewModel.showingPhotoPicker = true
                }) {
                    Label("Fotos hinzufügen", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedImages.count >= 5)
            }
        }
    }
    
    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 80)
                .clipped()
                .cornerRadius(8)
            
            Button(action: {
                viewModel.removeImage(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.red))
                    .font(.system(size: 18))
            }
            .offset(x: 5, y: -5)
        }
    }
    
    private var emptyPhotoState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("Keine Fotos hinzugefügt")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var dateTimeSection: some View {
        Section("Zeitpunkt") {
            DatePicker(
                "Wann ist das passiert?",
                selection: $viewModel.timestamp,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
        }
    }
    
    private var saveSection: some View {
        Section {
            Button(action: {
                Task {
                    await viewModel.saveMemory()
                }
            }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Speichern...")
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Erinnerung speichern")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave || viewModel.isSaving)
            
            // Offline Notice
            if !viewModel.isOnline {
                Text("📱 Offline-Modus: Erinnerung wird lokal gespeichert und später synchronisiert")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            // Save draft before dismissing
            viewModel.saveDraft()
        }
        dismiss()
    }
}

// MARK: - Location Picker View

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocation?
    let currentLocation: CLLocation?
    @Binding var isPresented: Bool
    
    @State private var region: MKCoordinateRegion
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    init(selectedLocation: Binding<CLLocation?>, currentLocation: CLLocation?, isPresented: Binding<Bool>) {
        self._selectedLocation = selectedLocation
        self.currentLocation = currentLocation
        self._isPresented = isPresented
        
        let initialCoordinate = currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050) // Berlin default
        self._region = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: selectedCoordinate != nil ? [MapAnnotation(coordinate: selectedCoordinate!)] : []) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: .red)
                }
                .onTapGesture { location in
                    let coordinate = region.center
                    selectedCoordinate = coordinate
                }
                .overlay(
                    // Crosshair in center
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 30, height: 30))
                        .shadow(radius: 2)
                )
                
                VStack(spacing: 12) {
                    if let coordinate = selectedCoordinate ?? region.center as CLLocationCoordinate2D? {
                        Text("📍 \(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if currentLocation != nil {
                            Button("Aktuelle Position") {
                                region.center = currentLocation!.coordinate
                                selectedCoordinate = currentLocation!.coordinate
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Auswählen") {
                            if let coordinate = selectedCoordinate ?? region.center as CLLocationCoordinate2D? {
                                selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                            }
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Standort wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            selectedCoordinate = region.center
        }
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

struct EnhancedMemoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = "test@example.com"
        user.displayName = "Test User"
        
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Italien Reise"
        trip.startDate = Date()
        trip.owner = user
        
        return EnhancedMemoryCreationView(trip: trip, user: user)
            .environment(\.managedObjectContext, context)
    }
} 