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
    
    // PERFORMANCE: State für UI-Updates reduzieren
    @State private var isKeyboardVisible = false
    @State private var isViewInitialized = false
    
    @State private var showPhotoSourceDialog = false
    @State private var photoSource: PhotoSource? = nil
    
    let trip: Trip
    let user: User
    
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        self._viewModel = StateObject(wrappedValue: EnhancedMemoryCreationViewModel(trip: trip, user: user))
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                // PERFORMANCE: Conditional rendering für bessere Performance
                if isViewInitialized {
                    mainContentView(geometry: geometry)
                } else {
                    loadingView
                }
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
            .onAppear {
                setupView()
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
            }
            // PERFORMANCE: Keyboard handling optimiert
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    isKeyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    isKeyboardVisible = false
                }
            }
            // Sheet für PhotoPicker je nach Auswahl
            .sheet(item: $photoSource) { source in
                PhotoPicker(
                    selectedImages: $viewModel.selectedImages,
                    isPresented: Binding(
                        get: { photoSource != nil },
                        set: { if !$0 { photoSource = nil } }
                    ),
                    maxSelections: 5,
                    allowsCamera: source == .camera,
                    compressionQuality: 0.6,
                    startMode: source
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Initialisierung...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func mainContentView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header Section - PERFORMANCE: Lazy Loading
                headerSection
                    .padding()
                
                Divider()
                
                VStack(spacing: 20) {
                    // Eingabe Sektion
                    inputSection
                        .padding(.horizontal)
                    
                    // GPS & Location Sektion - Conditional rendering
                    if viewModel.hasValidLocation || viewModel.isUpdatingLocation {
                        locationSection
                            .padding(.horizontal)
                    }
                    
                    // Photo Sektion
                    photoSection
                        .padding(.horizontal)
                    
                    // Datum & Zeit Sektion
                    dateTimeSection
                        .padding(.horizontal)
                    
                    // Save Button
                    saveSection
                        .padding(.horizontal)
                        .padding(.bottom, isKeyboardVisible ? 0 : geometry.safeAreaInsets.bottom)
                }
                .padding(.vertical)
            }
        }
        // PERFORMANCE: Optimierte Scroll-Indikatoren
        .scrollIndicators(.automatic)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - View Sections

    private var headerSection: some View {
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
            
            // Status Indicators - PERFORMANCE: Conditional rendering
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
        VStack(spacing: 16) {
            // Titel (Required) - PERFORMANCE: Optimierte TextField
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
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
            }
            
            // Beschreibung (Optional) - PERFORMANCE: Lazy rendering
            VStack(alignment: .leading, spacing: 8) {
                Label("Beschreibung", systemImage: "text.alignleft")
                
                TextField("Erzähle mehr über diesen besonderen Moment...", 
                         text: $viewModel.content, 
                         axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Standort", systemImage: "location")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Current Location Display - PERFORMANCE: Conditional rendering
            Group {
                if let location = viewModel.effectiveLocation {
                    locationDisplayCard(location: location)
                } else {
                    noLocationCard
                }
            }
            
            // Location Actions - PERFORMANCE: Reduced button complexity
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.updateLocation()
                }) {
                    Label("GPS aktualisieren", systemImage: "location.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isUpdatingLocation)
                
                Button(action: {
                    viewModel.showingLocationPicker = true
                }) {
                    Label("Manuell wählen", systemImage: "map")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            // PERFORMANCE: Conditional loading indicator
            if viewModel.isUpdatingLocation {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("GPS wird aktualisiert...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                Text("📍 \(location.formattedCoordinates)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Genauigkeit: \(location.formattedAccuracy)")
                    .font(.caption2)
                    .foregroundColor(location.horizontalAccuracy >= 0 ? .secondary : .orange)
                
                // Reverse Geocoding Adresse - PERFORMANCE: Conditional rendering
                if let address = viewModel.locationAddress {
                    Text("📍 \(address)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fotos", systemImage: "photo")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.selectedImages.count)/5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // PERFORMANCE: Lazy photo grid
            if !viewModel.selectedImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                        photoThumbnail(image: image, index: index)
                    }
                }
            } else {
                emptyPhotoState
            }
            
            // Neuer Add Photo Button mit Auswahl
            Button(action: {
                showPhotoSourceDialog = true
            }) {
                Label("Foto hinzufügen", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedImages.count >= 5)
            .confirmationDialog("Foto hinzufügen", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("Kamera") { photoSource = .camera }
                Button("Galerie") { photoSource = .gallery }
                Button("Abbrechen", role: .cancel) { }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.removeImage(at: index)
                }
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
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Zeitpunkt", systemImage: "clock")
                .font(.headline)
            
            DatePicker(
                "Wann ist das passiert?",
                selection: $viewModel.timestamp,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var saveSection: some View {
        VStack(spacing: 12) {
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
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave || viewModel.isSaving)
            
            // Offline Notice - PERFORMANCE: Conditional rendering
            if !viewModel.isOnline {
                Text("📱 Offline-Modus: Erinnerung wird lokal gespeichert und später synchronisiert")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        // PERFORMANCE: Delayed initialization to reduce initial load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                isViewInitialized = true
            }
            viewModel.loadDraft()
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            viewModel.saveDraft()
        case .active:
            // PERFORMANCE: Nur bei Bedarf neu laden
            if !isViewInitialized {
                setupView()
            }
        default:
            break
        }
    }
    
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
    
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isMapReady = false
    
    init(selectedLocation: Binding<CLLocation?>, currentLocation: CLLocation?, isPresented: Binding<Bool>) {
        self._selectedLocation = selectedLocation
        self.currentLocation = currentLocation
        self._isPresented = isPresented
        
        // SICHERE Koordinaten-Validierung für Map-Initialisierung
        let safeCoordinate: CLLocationCoordinate2D
        
        if let currentLocation = currentLocation,
           LocationValidator.isValidLocation(currentLocation) {
            safeCoordinate = currentLocation.coordinate
        } else {
            // Berlin als sicherer Fallback
            safeCoordinate = CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        }
        
        // Zusätzliche Validierung der finalen Koordinaten
        let finalLatitude = safeCoordinate.latitude.isFinite ? safeCoordinate.latitude : 52.5200
        let finalLongitude = safeCoordinate.longitude.isFinite ? safeCoordinate.longitude : 13.4050
        
        let validatedCoordinate = CLLocationCoordinate2D(latitude: finalLatitude, longitude: finalLongitude)
        
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: validatedCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // PERFORMANCE: Conditional map rendering
                if isMapReady {
                    mapView
                } else {
                    mapLoadingView
                }
                
                controlsView
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
            .onAppear {
                // PERFORMANCE: Delayed map loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isMapReady = true
                    }
                }
            }
        }
    }
    
    private var mapLoadingView: some View {
        VStack {
            ProgressView()
            Text("Karte wird geladen...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mapView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // User location
            if let currentLocation = currentLocation, LocationValidator.isValidLocation(currentLocation) {
                UserAnnotation()
            }
            
            // Selected location annotation
            if let coordinate = selectedCoordinate,
               LocationValidator.isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                Annotation("Ausgewählter Standort", coordinate: coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                        .background(Circle().fill(Color.white).frame(width: 30, height: 30))
                        .shadow(radius: 2)
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) {
            // PERFORMANCE: Reduzierte Update-Frequenz
            updateSelectedCoordinate(from: cameraPosition)
        }
        .overlay(
            // Crosshair in center
            Image(systemName: "plus")
                .font(.title)
                .foregroundColor(.red)
                .background(Circle().fill(Color.white).frame(width: 30, height: 30))
                .shadow(radius: 2)
        )
    }
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            if let coordinate = selectedCoordinate {
                // SICHERE Koordinaten-Anzeige
                Text("📍 \(LocationValidator.formatCoordinates(latitude: coordinate.latitude, longitude: coordinate.longitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if let currentLocation = currentLocation, LocationValidator.isValidLocation(currentLocation) {
                    Button("Aktuelle Position") {
                        moveToCurrentLocation(currentLocation)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Auswählen") {
                    selectCurrentCoordinate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidSelection)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func updateSelectedCoordinate(from position: MapCameraPosition) {
        guard let region = position.region else {
            print("⚠️ LocationPickerView: Keine gültige Region verfügbar")
            return
        }
        
        let newCoordinate = region.center
        
        // SICHERE Validierung der Map-Koordinaten
        if LocationValidator.isValidCoordinate(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude) {
            selectedCoordinate = newCoordinate
        } else {
            print("⚠️ LocationPickerView: Ungültige Koordinaten von Map erhalten: \(newCoordinate.latitude), \(newCoordinate.longitude)")
        }
    }
    
    private func moveToCurrentLocation(_ location: CLLocation) {
        let coordinate = location.coordinate
        
        // SICHERE Region-Erstellung
        if LocationValidator.isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(newRegion)
            }
            selectedCoordinate = coordinate
        } else {
            print("⚠️ LocationPickerView: Aktuelle Position hat ungültige Koordinaten")
        }
    }
    
    private func selectCurrentCoordinate() {
        guard let coordinate = selectedCoordinate,
              LocationValidator.isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
            print("⚠️ LocationPickerView: Keine gültigen Koordinaten zum Auswählen")
            return
        }
        
        selectedLocation = LocationValidator.createSafeLocation(
            latitude: coordinate.latitude, 
            longitude: coordinate.longitude
        )
        isPresented = false
    }
    
    private var isValidSelection: Bool {
        guard let coordinate = selectedCoordinate else { return false }
        return LocationValidator.isValidCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
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