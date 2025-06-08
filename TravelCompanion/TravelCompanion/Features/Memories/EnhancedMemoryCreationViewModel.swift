import SwiftUI
import PhotosUI
import CoreLocation
import CoreData
import UIKit
import AVFoundation
import Network

@MainActor
class EnhancedMemoryCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var timestamp: Date = Date()
    @Published var selectedImages: [UIImage] = []
    @Published var currentLocation: CLLocation?
    @Published var manualLocation: CLLocation?
    @Published var locationAddress: String?
    
    // UI State
    @Published var showingPhotoPicker = false
    @Published var showingLocationPicker = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var isSaving = false
    @Published var isUpdatingLocation = false
    @Published var isOnline = true
    
    // Error Handling
    @Published var errorMessage = ""
    
    // MARK: - Dependencies
    private let trip: Trip
    private let user: User
    private let coreDataManager = CoreDataManager.shared
    private let locationManager = LocationManager.shared
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // PERFORMANCE: Optimierte Timer-Verwaltung
    private var locationUpdateTimer: Timer?
    private var geocodingTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    
    // PERFORMANCE: Debouncing für Updates
    private var lastLocationUpdate: Date = Date.distantPast
    private var lastGeocodingRequest: Date = Date.distantPast
    private let minimumUpdateInterval: TimeInterval = 2.0 // Von 5.0 auf 2.0 reduziert
    private let minimumGeocodingInterval: TimeInterval = 5.0
    
    // MARK: - Private Properties
    private var draftKey: String {
        "memory_draft_\(trip.id?.uuidString ?? "unknown")_\(user.id?.uuidString ?? "unknown")"
    }
    
    // MARK: - Computed Properties
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasValidLocation
    }
    
    var hasValidLocation: Bool {
        effectiveLocation != nil
    }
    
    var effectiveLocation: CLLocation? {
        manualLocation ?? currentLocation
    }
    
    var hasUnsavedChanges: Bool {
        !title.isEmpty || !content.isEmpty || !selectedImages.isEmpty
    }
    
    // MARK: - Initialization
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        print("🔧 EnhancedMemoryCreationViewModel: Setup gestartet - User: \(user.displayName ?? "Unknown"), Trip: \(trip.title ?? "Unknown")")
        
        setupNetworkMonitoring()
        setupLocationMonitoring()
        
        print("✅ EnhancedMemoryCreationViewModel: Setup abgeschlossen")
    }
    
    deinit {
        print("🗑️ EnhancedMemoryCreationViewModel: Cleanup gestartet")
        
        // Synchrone Tasks canceln (sicher im deinit)
        geocodingTask?.cancel()
        saveTask?.cancel()
        locationUpdateTimer?.invalidate()
        networkMonitor.cancel()
        
        print("✅ EnhancedMemoryCreationViewModel: Cleanup abgeschlossen")
    }
    
    // MARK: - Setup Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupLocationMonitoring() {
        // Initial location from LocationManager
        if let location = locationManager.currentLocation,
           LocationValidator.isValidLocation(location) {
            self.currentLocation = location
            print("✅ EnhancedMemoryCreationViewModel: Location bereits verfügbar: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            performReverseGeocodingIfNeeded(for: location)
        }
        
        // PERFORMANCE: Optimierter Timer mit längeren Intervallen
        startLocationUpdates()
    }
    
    private func startLocationUpdates() {
        // PERFORMANCE: Timer-Intervall von 5.0 auf 10.0 erhöht für weniger Updates
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkLocationUpdate()
            }
        }
    }
    
    @MainActor
    private func checkLocationUpdate() async {
        guard let newLocation = locationManager.currentLocation,
              LocationValidator.isValidLocation(newLocation) else {
            return
        }
        
        // PERFORMANCE: Debouncing - nur bei signifikanten Änderungen updaten
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= minimumUpdateInterval else {
            return
        }
        
        // Prüfe ob Location wirklich geändert hat (mindestens 10m Unterschied)
        if let currentLoc = currentLocation {
            let distance = newLocation.distance(from: currentLoc)
            if distance < 10.0 { // Weniger als 10m Unterschied
                return
            }
        }
        
        lastLocationUpdate = now
        currentLocation = newLocation
        print("📍 EnhancedMemoryCreationViewModel: Location aktualisiert: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        
        // PERFORMANCE: Geocoding nur bei Bedarf
        performReverseGeocodingIfNeeded(for: newLocation)
    }
    
    // MARK: - Location Methods
    
    func updateLocation() {
        guard !isUpdatingLocation else { return }
        
        print("📍 EnhancedMemoryCreationViewModel: Starte Location-Update...")
        isUpdatingLocation = true
        
        // PERFORMANCE: Timeout für Location-Update
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            await MainActor.run {
                if isUpdatingLocation {
                    isUpdatingLocation = false
                    print("⚠️ EnhancedMemoryCreationViewModel: Location-Update Timeout")
                }
            }
        }
        
        Task { @MainActor in
            defer {
                timeoutTask.cancel()
                isUpdatingLocation = false
            }
            
            // Forciere Location-Update vom LocationManager
            locationManager.requestLocationUpdate()
            
            // Warte kurz auf neuen Location
            try? await Task.sleep(for: .milliseconds(500))
            
            if let location = locationManager.currentLocation,
               LocationValidator.isValidLocation(location) {
                currentLocation = location
                lastLocationUpdate = Date()
                print("✅ EnhancedMemoryCreationViewModel: GPS-Location erhalten: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                performReverseGeocodingIfNeeded(for: location)
            } else {
                print("⚠️ EnhancedMemoryCreationViewModel: Keine gültige Location erhalten")
            }
        }
    }
    
    func useCurrentLocation() {
        manualLocation = nil
        if let location = currentLocation {
            performReverseGeocodingIfNeeded(for: location)
        }
    }
    
    // PERFORMANCE: Optimierte Reverse Geocoding mit Debouncing
    private func performReverseGeocodingIfNeeded(for location: CLLocation) {
        let now = Date()
        guard now.timeIntervalSince(lastGeocodingRequest) >= minimumGeocodingInterval else {
            return
        }
        
        lastGeocodingRequest = now
        
        // Cancel previous geocoding task
        geocodingTask?.cancel()
        
        geocodingTask = Task { @MainActor in
            do {
                let geocoder = CLGeocoder()
                
                let result = try await withThrowingTaskGroup(of: [CLPlacemark].self) { group in
                    group.addTask {
                        return try await geocoder.reverseGeocodeLocation(location)
                    }
                    
                    group.addTask {
                        try await Task.sleep(for: .seconds(5))
                        throw CancellationError()
                    }
                    
                    let placemarks = try await group.next()!
                    group.cancelAll()
                    return placemarks
                }
                
                if let placemark = result.first {
                    let addressComponents = [
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.country
                    ].compactMap { $0 }
                    
                    locationAddress = addressComponents.joined(separator: ", ")
                    print("📍 EnhancedMemoryCreationViewModel: Adresse gefunden: \(locationAddress ?? "Unknown")")
                }
                
            } catch {
                if !(error is CancellationError) {
                    print("⚠️ EnhancedMemoryCreationViewModel: Geocoding fehlgeschlagen: \(error)")
                }
            }
        }
    }
    
    // MARK: - Image Management
    
    func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    
    // MARK: - Draft Management
    
    func saveDraft() {
        let draft = MemoryDraft(
            title: title,
            content: content,
            timestamp: timestamp,
            location: effectiveLocation,
            imageCount: selectedImages.count
        )
        
        do {
            let data = try JSONEncoder().encode(draft)
            UserDefaults.standard.set(data, forKey: draftKey)
            print("💾 EnhancedMemoryCreationViewModel: Draft gespeichert")
        } catch {
            print("❌ EnhancedMemoryCreationViewModel: Draft speichern fehlgeschlagen: \(error)")
        }
    }
    
    func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(MemoryDraft.self, from: data) else {
            return
        }
        
        title = draft.title
        content = draft.content
        timestamp = draft.timestamp
        
        if let location = draft.location,
           LocationValidator.isValidLocation(location) {
            manualLocation = location
            performReverseGeocodingIfNeeded(for: location)
        }
        
        print("📖 EnhancedMemoryCreationViewModel: Draft geladen für Trip: \(trip.title ?? "Unknown")")
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
    
    // MARK: - Memory Saving - PERFORMANCE OPTIMIZED
    
    func saveMemory() async {
        guard canSave else {
            showError("Bitte fülle alle erforderlichen Felder aus")
            return
        }
        
        // PERFORMANCE: Cancel any existing save operation
        saveTask?.cancel()
        
        isSaving = true
        print("🔄 EnhancedMemoryCreationViewModel: Speicher-Prozess gestartet")
        
        saveTask = Task { @MainActor in
            do {
                // Create Memory in Core Data - PERFORMANCE OPTIMIZED
                let memory = try await createMemoryOptimized()
                
                // Save photos if available - PARALLEL PROCESSING
                if !selectedImages.isEmpty {
                    await savePhotosOptimized(for: memory)
                }
                
                // Save Core Data context
                coreDataManager.save()
                
                // Clear draft after successful save
                clearDraft()
                
                // Show success
                showingSuccess = true
                
                // Reset form
                resetForm()
                
                print("✅ EnhancedMemoryCreationViewModel: Memory erfolgreich gespeichert")
                
            } catch {
                showError("Fehler beim Speichern: \(error.localizedDescription)")
                print("❌ EnhancedMemoryCreationViewModel: Memory speichern fehlgeschlagen: \(error)")
            }
            
            isSaving = false
        }
    }
    
    // PERFORMANCE: Optimierte Memory-Erstellung
    private func createMemoryOptimized() async throws -> Memory {
        print("📝 EnhancedMemoryCreationViewModel: Erstelle Memory mit:")
        print("   - Titel: '\(title)'")
        print("   - Inhalt: '\(content)'")
        
        if let location = effectiveLocation {
            print("   - Koordinaten: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
        print("   - Trip: \(trip.title ?? "Unknown")")
        print("   - User: \(user.displayName ?? "Unknown")")
        
        // DIRECT Main Context Operation für bessere Performance
        let memory = Memory(context: coreDataManager.viewContext)
        memory.id = UUID()
        memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.content = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.timestamp = timestamp
        memory.createdAt = Date()
        memory.author = user
        memory.trip = trip
        
        // Set location
        if let location = effectiveLocation {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            
            guard LocationValidator.isValidCoordinate(latitude: lat, longitude: lon) else {
                print("❌ EnhancedMemoryCreationViewModel: Ungültige Koordinaten - Lat: \(lat), Lon: \(lon)")
                throw EnhancedMemoryCreationError.locationNotAvailable
            }
            
            memory.latitude = lat
            memory.longitude = lon
        } else {
            print("⚠️ EnhancedMemoryCreationViewModel: Keine Location verfügbar, setze Standard-Koordinaten")
            memory.latitude = 0.0
            memory.longitude = 0.0
        }
        
        print("✅ EnhancedMemoryCreationViewModel: Memory erfolgreich gespeichert")
        return memory
    }
    
    // PERFORMANCE: Parallel Photo Processing
    private func savePhotosOptimized(for memory: Memory) async {
        print("📷 EnhancedMemoryCreationViewModel: Speichere \(selectedImages.count) Fotos...")
        
        // PARALLEL photo processing mit TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for (index, image) in selectedImages.enumerated() {
                group.addTask { [weak self] in
                    await self?.savePhotoOptimized(for: memory, image: image, index: index)
                }
            }
        }
        
        print("✅ EnhancedMemoryCreationViewModel: Alle Fotos gespeichert")
    }
    
    private func savePhotoOptimized(for memory: Memory, image: UIImage, index: Int) async {
        do {
            // Generate unique filename
            let filename = "memory_\(memory.id?.uuidString.prefix(8) ?? "unknown")_\(index).jpg"
            
            // PERFORMANCE: Compress image more aggressively
            let compressedImage = compressImageForStorage(image)
            
            // Save image to local storage
            let localURL = try saveImageToDocuments(image: compressedImage, filename: filename)
            
            // Create Photo entity in main context
            await MainActor.run {
                let photo = Photo(context: coreDataManager.viewContext)
                photo.id = UUID()
                photo.filename = filename
                photo.localURL = localURL
                photo.createdAt = Date()
                photo.memory = memory
                photo.cloudURL = nil // Offline-first approach
                
                print("✅ EnhancedMemoryCreationViewModel: Photo-Entity erfolgreich erstellt: \(filename)")
            }
            
        } catch {
            print("❌ EnhancedMemoryCreationViewModel: Photo speichern fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - Image Processing - PERFORMANCE OPTIMIZED
    
    private func compressImageForStorage(_ image: UIImage) -> UIImage {
        // DEUTLICH reduzierte maximale Größe für bessere Performance
        let maxDimension: CGFloat = 600 // Von 800 auf 600 reduziert
        let size = image.size
        
        // Validiere die ursprüngliche Bildgröße
        guard size.width.isFinite && size.height.isFinite && 
              size.width > 0 && size.height > 0 else {
            print("⚠️ EnhancedMemoryCreationViewModel: Ungültige Bildgröße - Width: \(size.width), Height: \(size.height)")
            return image
        }
        
        let maxCurrentDimension = max(size.width, size.height)
        guard maxCurrentDimension.isFinite && maxCurrentDimension > 0 else {
            print("⚠️ EnhancedMemoryCreationViewModel: Ungültige maximale Dimension: \(maxCurrentDimension)")
            return image
        }
        
        if maxCurrentDimension > maxDimension {
            let ratio = maxDimension / maxCurrentDimension
            guard ratio.isFinite && ratio > 0 else {
                print("⚠️ EnhancedMemoryCreationViewModel: Ungültiges Verhältnis: \(ratio)")
                return image
            }
            
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            // Validiere die neue Größe bevor CoreGraphics verwendet wird
            guard newSize.width.isFinite && newSize.height.isFinite &&
                  newSize.width > 0 && newSize.height > 0 else {
                print("⚠️ EnhancedMemoryCreationViewModel: Ungültige neue Bildgröße - Width: \(newSize.width), Height: \(newSize.height)")
                return image
            }
            
            // PERFORMANCE: Optimierte Renderer-Konfiguration
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // Verhindere High-DPI Scaling
            format.opaque = true // Bessere Performance für JPEG
            format.preferredRange = .standard // Reduzierter Color Range
            
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        return image
    }
    
    // MARK: - File Management
    
    private func saveImageToDocuments(image: UIImage, filename: String) throws -> String {
        // SEHR aggressive Komprimierung für kleinste Dateien
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { // Von 0.4 auf 0.3 reduziert
            throw EnhancedMemoryCreationError.imageCompressionFailed
        }
        
        let fileSizeKB = imageData.count / 1024
        print("📷 EnhancedMemoryCreationViewModel: Bild komprimiert - \(fileSizeKB)KB")
        
        // ✅ KRITISCHER FIX: Verwende konsistentes Photos-Verzeichnis
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("Photos")
        
        // ✅ WICHTIG: Directory erstellen falls es nicht existiert
        if !FileManager.default.fileExists(atPath: photosDirectory.path) {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
            print("✅ EnhancedMemoryCreationViewModel: Photos Directory erstellt")
        }
        
        let imageURL = photosDirectory.appendingPathComponent(filename)
        
        try imageData.write(to: imageURL)
        print("✅ EnhancedMemoryCreationViewModel: Bild gespeichert in: \(imageURL.path)")
        
        return imageURL.path
    }
    
    // MARK: - Helper Methods
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func resetForm() {
        title = ""
        content = ""
        timestamp = Date()
        selectedImages.removeAll()
        manualLocation = nil
        locationAddress = nil
    }
}

// MARK: - Memory Draft Model

struct MemoryDraft: Codable {
    let title: String
    let content: String
    let timestamp: Date
    let location: CLLocation?
    let imageCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case title, content, timestamp, latitude, longitude, imageCount
    }
    
    init(title: String, content: String, timestamp: Date, location: CLLocation?, imageCount: Int) {
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.location = location
        self.imageCount = imageCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageCount = try container.decode(Int.self, forKey: .imageCount)
        
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocation(latitude: latitude, longitude: longitude)
        } else {
            location = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(imageCount, forKey: .imageCount)
        
        if let location = location {
            try container.encode(location.coordinate.latitude, forKey: .latitude)
            try container.encode(location.coordinate.longitude, forKey: .longitude)
        }
    }
}

// MARK: - Enhanced Errors

enum EnhancedMemoryCreationError: LocalizedError {
    case imageCompressionFailed
    case locationNotAvailable
    case coreDataSaveFailed
    case networkUnavailable
    case geocodingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Foto konnte nicht komprimiert werden"
        case .locationNotAvailable:
            return "GPS-Position nicht verfügbar"
        case .coreDataSaveFailed:
            return "Speichern in Core Data fehlgeschlagen"
        case .networkUnavailable:
            return "Netzwerk nicht verfügbar"
        case .geocodingFailed:
            return "Adresse konnte nicht ermittelt werden"
        case .permissionDenied:
            return "Berechtigung verweigert"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .imageCompressionFailed:
            return "Versuche ein anderes Foto oder verkleinere die Dateigröße"
        case .locationNotAvailable:
            return "Prüfe die GPS-Einstellungen oder wähle einen Standort manuell"
        case .coreDataSaveFailed:
            return "Starte die App neu und versuche es erneut"
        case .networkUnavailable:
            return "Die Erinnerung wird offline gespeichert und später synchronisiert"
        case .geocodingFailed:
            return "GPS-Koordinaten werden ohne Adresse gespeichert"
        case .permissionDenied:
            return "Erlaube der App den Zugriff in den Einstellungen"
        }
    }
} 