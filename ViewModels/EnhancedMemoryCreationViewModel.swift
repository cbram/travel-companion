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
    private let geocoder = CLGeocoder()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
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
        
        setupNetworkMonitoring()
        setupLocationMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
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
        if let location = locationManager.currentLocation {
            self.currentLocation = location
            performReverseGeocoding(for: location)
        }
        
        // Listen for location updates
        startLocationUpdates()
    }
    
    private func startLocationUpdates() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            if let location = self?.locationManager.currentLocation,
               location != self?.currentLocation {
                self?.currentLocation = location
                self?.performReverseGeocoding(for: location)
            }
        }
    }
    
    // MARK: - Location Management
    
    func updateLocation() {
        isUpdatingLocation = true
        
        locationManager.requestPermission()
        
        // Force location update
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let location = self.locationManager.currentLocation {
                self.currentLocation = location
                self.performReverseGeocoding(for: location)
            } else {
                self.showError("GPS-Position konnte nicht ermittelt werden")
            }
            self.isUpdatingLocation = false
        }
    }
    
    func useCurrentLocation() {
        manualLocation = nil
        if let location = currentLocation {
            performReverseGeocoding(for: location)
        }
    }
    
    private func performReverseGeocoding(for location: CLLocation) {
        guard isOnline else { return }
        
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🗺️ Reverse Geocoding Fehler: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    let components = [
                        placemark.name,
                        placemark.locality,
                        placemark.country
                    ].compactMap { $0 }
                    
                    self?.locationAddress = components.joined(separator: ", ")
                }
            }
        }
    }
    
    // MARK: - Photo Management
    
    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    
    func clearAllImages() {
        selectedImages.removeAll()
    }
    
    // MARK: - Draft Management
    
    func saveDraft() {
        guard hasUnsavedChanges else { return }
        
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
            print("💾 Draft gespeichert für Trip: \(trip.title ?? "Unknown")")
        } catch {
            print("❌ Draft speichern fehlgeschlagen: \(error)")
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
        
        if let location = draft.location {
            manualLocation = location
            performReverseGeocoding(for: location)
        }
        
        print("📖 Draft geladen für Trip: \(trip.title ?? "Unknown")")
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
    
    // MARK: - Memory Saving
    
    func saveMemory() async {
        guard canSave else {
            showError("Bitte fülle alle erforderlichen Felder aus")
            return
        }
        
        isSaving = true
        
        do {
            // Create Footstep (Memory) in Core Data
            let footstep = try await createFootstep()
            
            // Save photos if available
            if !selectedImages.isEmpty {
                try await savePhotos(for: footstep)
            }
            
            // Save Core Data context
            try coreDataManager.save()
            
            // Clear draft after successful save
            clearDraft()
            
            // Show success
            showingSuccess = true
            
            // Reset form
            resetForm()
            
            print("✅ Memory erfolgreich gespeichert: \(footstep.title ?? "Unknown")")
            
        } catch {
            showError("Fehler beim Speichern: \(error.localizedDescription)")
            print("❌ Memory speichern fehlgeschlagen: \(error)")
        }
        
        isSaving = false
    }
    
    private func createFootstep() async throws -> Footstep {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataManager.backgroundContext.perform {
                do {
                    // Get objects in background context
                    let backgroundTrip = self.coreDataManager.backgroundContext.object(with: self.trip.objectID) as! Trip
                    let backgroundUser = self.coreDataManager.backgroundContext.object(with: self.user.objectID) as! User
                    
                    // Create footstep
                    let footstep = Footstep(context: self.coreDataManager.backgroundContext)
                    footstep.id = UUID()
                    footstep.title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    footstep.content = self.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    footstep.timestamp = self.timestamp
                    footstep.createdAt = Date()
                    footstep.author = backgroundUser
                    footstep.trip = backgroundTrip
                    
                    // Set location
                    if let location = self.effectiveLocation {
                        footstep.latitude = location.coordinate.latitude
                        footstep.longitude = location.coordinate.longitude
                    }
                    
                    try self.coreDataManager.backgroundContext.save()
                    
                    // Get footstep in main context
                    DispatchQueue.main.async {
                        let mainFootstep = self.coreDataManager.viewContext.object(with: footstep.objectID) as! Footstep
                        continuation.resume(returning: mainFootstep)
                    }
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func savePhotos(for footstep: Footstep) async throws {
        for (index, image) in selectedImages.enumerated() {
            try await savePhoto(for: footstep, image: image, index: index)
        }
    }
    
    private func savePhoto(for footstep: Footstep, image: UIImage, index: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            coreDataManager.backgroundContext.perform {
                do {
                    // Get footstep in background context
                    let backgroundFootstep = self.coreDataManager.backgroundContext.object(with: footstep.objectID) as! Footstep
                    
                    // Generate unique filename
                    let filename = "\(UUID().uuidString)_\(index).jpg"
                    
                    // Compress image for storage optimization
                    let compressedImage = self.compressImageForStorage(image)
                    
                    // Save image to local storage
                    let localURL = try self.saveImageToDocuments(image: compressedImage, filename: filename)
                    
                    // Create Photo entity
                    let photo = Photo(context: self.coreDataManager.backgroundContext)
                    photo.id = UUID()
                    photo.filename = filename
                    photo.localURL = localURL
                    photo.createdAt = Date()
                    photo.footstep = backgroundFootstep
                    
                    // Set cloudURL to nil for offline-first approach
                    photo.cloudURL = nil
                    
                    try self.coreDataManager.backgroundContext.save()
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Image Processing
    
    private func compressImageForStorage(_ image: UIImage) -> UIImage {
        // Resize image if too large
        let maxDimension: CGFloat = 1200
        let size = image.size
        
        if max(size.width, size.height) > maxDimension {
            let ratio = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage ?? image
        }
        
        return image
    }
    
    // MARK: - File Management
    
    private func saveImageToDocuments(image: UIImage, filename: String) throws -> String {
        // Use higher compression for storage optimization
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw MemoryCreationError.imageCompressionFailed
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(filename)
        
        try imageData.write(to: imageURL)
        
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

// MARK: - CLLocation Codable Extension

extension CLLocation: Codable {
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy, timestamp
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encode(verticalAccuracy, forKey: .verticalAccuracy)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let altitude = try container.decode(Double.self, forKey: .altitude)
        let horizontalAccuracy = try container.decode(Double.self, forKey: .horizontalAccuracy)
        let verticalAccuracy = try container.decode(Double.self, forKey: .verticalAccuracy)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        self.init(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }
} 