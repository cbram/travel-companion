import SwiftUI
import PhotosUI
import CoreLocation
import CoreData
import UIKit
import AVFoundation

@MainActor
class MemoryCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var selectedImage: UIImage?
    @Published var currentLocation: CLLocation?
    @Published var trip: Trip?
    @Published var user: User?
    
    // UI State
    @Published var showingImagePicker = false
    @Published var showingPhotoPicker = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var showingNoTripAlert = false
    @Published var isSaving = false
    
    // Error Handling
    @Published var errorMessage = ""
    
    // PHPicker
    @Published var photoPickerItem: PhotosPickerItem?
    
    // Image Picker Type
    var imageSourceType: UIImagePickerController.SourceType = .camera
    
    // MARK: - Dependencies
    private let coreDataManager = CoreDataManager.shared
    private let locationManager = LocationManager.shared
    
    // MARK: - Computed Properties
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        currentLocation != nil &&
        trip != nil &&
        user != nil
    }
    
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    // MARK: - Initialization
    init() {
        setupInitialData()
        setupLocation()
    }
    
    // MARK: - Setup Methods
    func setupInitialData() {
        // Lade ersten verfügbaren User im View Context
        let users = coreDataManager.fetchAllUsers()
        if users.isEmpty {
            // Keine automatische User-Erstellung mehr
            print("📝 MemoryCreationViewModel: Keine User gefunden - User muss manuell erstellt werden")
            self.user = nil
        } else {
            self.user = users.first
        }
        
        // Lade aktive Reise für User
        if let currentUser = user {
            self.trip = coreDataManager.fetchActiveTrip(for: currentUser)
            
            // Falls keine aktive Reise, nimm die erste verfügbare
            if trip == nil {
                let allTrips = coreDataManager.fetchTrips(for: currentUser)
                if let firstTrip = allTrips.first {
                    // Setze erste Reise als aktiv
                    coreDataManager.setTripActive(firstTrip, isActive: true)
                    do {
                        try coreDataManager.viewContext.save()
                        self.trip = firstTrip
                        print("✅ MemoryCreationViewModel: Erste Reise als aktiv gesetzt: \(firstTrip.title ?? "Unbekannt")")
                    } catch {
                        print("❌ MemoryCreationViewModel: Fehler beim Speichern der aktiven Reise: \(error)")
                    }
                } else {
                    // Keine automatische Trip-Erstellung mehr
                    print("📝 MemoryCreationViewModel: Keine Trips gefunden - Trip muss manuell erstellt werden")
                    self.trip = nil
                }
            }
        }
        
        print("✅ MemoryCreationViewModel: Setup abgeschlossen - User: \(user?.displayName ?? "nil"), Trip: \(trip?.title ?? "nil")")
    }
    
    func checkActiveTrip() {
        if trip == nil || user == nil {
            showingNoTripAlert = true
        }
    }
    
    // MARK: - Location Management
    private func setupLocation() {
        // Get current location from LocationManager
        if let location = locationManager.currentLocation {
            self.currentLocation = location
            print("✅ MemoryCreationViewModel: Location bereits verfügbar: \(location.formattedCoordinates)")
        } else {
            // Request location update
            Task { @MainActor in
                await updateLocation()
            }
        }
    }
    
    @Published var isUpdatingLocation = false
    private var locationUpdateTask: Task<Void, Never>?
    
    func updateLocation() async {
        // Verhindere mehrfache gleichzeitige Location-Updates
        guard !isUpdatingLocation else {
            print("⏸️ MemoryCreationViewModel: Location-Update bereits aktiv, überspringe")
            return
        }
        
        // Verwende bereits verfügbare Location falls kürzlich aktualisiert
        if let currentLocation = locationManager.currentLocation {
            let timeSinceLastUpdate = Date().timeIntervalSince(currentLocation.timestamp)
            if timeSinceLastUpdate < 30.0 { // 30 Sekunden Cooldown
                self.currentLocation = currentLocation
                print("✅ MemoryCreationViewModel: Verwende gecachte Location (vor \(Int(timeSinceLastUpdate))s): \(currentLocation.formattedCoordinates)")
                return
            }
        }
        
        // Cancel existing task
        locationUpdateTask?.cancel()
        
        isUpdatingLocation = true
        print("📍 MemoryCreationViewModel: Starte Location-Update...")
        
        // VEREINFACHTE Location-Anfrage ohne Timer oder Retry-Logic
        locationUpdateTask = Task { @MainActor in
            defer {
                isUpdatingLocation = false
            }
            
            // Warte kurz und prüfe nochmal ob Location verfügbar ist
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if let location = locationManager.currentLocation {
                self.currentLocation = location
                print("✅ MemoryCreationViewModel: GPS-Location erhalten: \(location.formattedCoordinates)")
            } else {
                // Fordere einmalig neue Location an
                locationManager.requestCurrentLocation()
                
                // Warte maximal 5 Sekunden auf Update
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if let location = locationManager.currentLocation,
                       Date().timeIntervalSince(location.timestamp) < 10.0 {
                        self.currentLocation = location
                        print("✅ MemoryCreationViewModel: GPS-Location erhalten: \(location.formattedCoordinates)")
                        return
                    }
                }
                
                print("⚠️ MemoryCreationViewModel: Location-Update Timeout - verwende letzte bekannte Position oder Standard")
            }
        }
    }
    
    // MARK: - Photo Selection
    func showCameraPicker() {
        guard isCameraAvailable else {
            showError("Kamera ist nicht verfügbar")
            return
        }
        
        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.imageSourceType = .camera
                    self?.showingImagePicker = true
                } else {
                    self?.showError("Kamera-Berechtigung erforderlich")
                }
            }
        }
    }
    
    func showPhotoPicker() {
        showingPhotoPicker = true
    }
    
    func removeSelectedImage() {
        selectedImage = nil
        photoPickerItem = nil
    }
    
    func loadSelectedPhoto() {
        guard let photoPickerItem = photoPickerItem else { return }
        
        Task {
            do {
                guard let imageData = try await photoPickerItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: imageData) else {
                    await MainActor.run {
                        showError("Foto konnte nicht geladen werden")
                    }
                    return
                }
                
                await MainActor.run {
                    self.selectedImage = uiImage
                }
            } catch {
                await MainActor.run {
                    showError("Fehler beim Laden des Fotos: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Memory Saving
    func saveMemory() async {
        print("🔄 MemoryCreationViewModel: Speicher-Prozess gestartet")
        
        guard let trip = trip, let user = user else {
            print("❌ MemoryCreationViewModel: Trip oder User fehlt - Trip: \(trip?.title ?? "nil"), User: \(user?.displayName ?? "nil")")
            showError("Keine aktive Reise oder User vorhanden. Bitte überprüfen Sie Ihre Daten.")
            return
        }
        
        guard canSave else {
            print("❌ MemoryCreationViewModel: canSave ist false")
            print("   - Titel: '\(title)'")
            print("   - Location: \(currentLocation != nil ? "✅" : "❌")")
            print("   - Trip: \(trip.title ?? "nil")")
            print("   - User: \(user.displayName ?? "nil")")
            showError("Bitte fülle alle erforderlichen Felder aus")
            return
        }
        
        // Validiere Koordinaten bevor Speicherung
        let lat = currentLocation?.coordinate.latitude ?? 0.0
        let lon = currentLocation?.coordinate.longitude ?? 0.0
        
        guard LocationValidator.isValidCoordinate(latitude: lat, longitude: lon) else {
            print("❌ MemoryCreationViewModel: Ungültige Koordinaten - Lat: \(lat), Lon: \(lon)")
            showError("Ungültige GPS-Koordinaten. Bitte aktualisiere deinen Standort.")
            return
        }
        
        isSaving = true
        
        print("📝 MemoryCreationViewModel: Erstelle Memory mit:")
        print("   - Titel: '\(title)'")
        print("   - Inhalt: '\(content)'")
        print("   - Koordinaten: \(lat), \(lon)")
        print("   - Trip: \(trip.title ?? "Unknown")")
        print("   - User: \(user.displayName ?? "Unknown")")
        
        // OPTIMIERTE Memory-Erstellung: Background Context für bessere Performance
        do {
            let memoryResult = try await createMemoryInBackground(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: lat,
                longitude: lon,
                tripID: trip.id!,
                userID: user.id!
            )
            
            print("✅ MemoryCreationViewModel: Memory erfolgreich gespeichert")
            
            // Foto separat speichern falls vorhanden
            if let image = selectedImage {
                await savePhotoOptimized(image: image, memoryID: memoryResult.id!)
            }
            
            isSaving = false
            showingSuccess = true
            
            // Nach kurzer Verzögerung Form zurücksetzen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.resetForm()
            }
            
        } catch {
            print("❌ MemoryCreationViewModel: Memory-Speicherung fehlgeschlagen: \(error.localizedDescription)")
            isSaving = false
            showError("Fehler beim Speichern in der Datenbank: \(error.localizedDescription)")
        }
    }
    
    /// THREAD-SICHERE Background Memory-Erstellung
    private func createMemoryInBackground(title: String, content: String?, latitude: Double, longitude: Double, tripID: UUID, userID: UUID) async throws -> Memory {
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = coreDataManager.backgroundContext
            
            backgroundContext.perform {
                do {
                    // Trip und User im Background Context finden
                    let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                    tripRequest.predicate = NSPredicate(format: "id == %@", tripID as CVarArg)
                    tripRequest.fetchLimit = 1
                    
                    let userRequest: NSFetchRequest<User> = User.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", userID as CVarArg)
                    userRequest.fetchLimit = 1
                    
                    guard let backgroundTrip = try backgroundContext.fetch(tripRequest).first,
                          let backgroundUser = try backgroundContext.fetch(userRequest).first else {
                        throw NSError(domain: "MemoryCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Trip oder User nicht gefunden"])
                    }
                    
                    // Memory erstellen
                    let memory = Memory(context: backgroundContext)
                    memory.id = UUID()
                    memory.title = title
                    memory.content = content
                    memory.latitude = latitude
                    memory.longitude = longitude
                    memory.timestamp = Date()
                    memory.createdAt = Date()
                    memory.author = backgroundUser
                    memory.trip = backgroundTrip
                    
                    // Background Context speichern
                    try backgroundContext.save()
                    
                    // Memory ID für Main Context zurückgeben
                    let memoryID = memory.objectID
                    
                    DispatchQueue.main.async {
                        let mainContextMemory = self.coreDataManager.viewContext.object(with: memoryID) as! Memory
                        continuation.resume(returning: mainContextMemory)
                    }
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Optimierte Foto-Speicherung mit Background Processing
    private func savePhotoOptimized(image: UIImage, memoryID: UUID) async {
        print("📷 MemoryCreationViewModel: Speichere Foto optimiert...")
        
        // Foto-Verarbeitung im Background - FIXED für MainActor Isolation
        let maxDimension: CGFloat = 800
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        
        guard let compressedData = resizedImage.jpegData(compressionQuality: 0.4) else {
            print("❌ MemoryCreationViewModel: Bild-Komprimierung fehlgeschlagen")
            return
        }
        
        let fileSizeKB = compressedData.count / 1024
        print("📷 MemoryCreationViewModel: Bild optimiert - Größe: \(fileSizeKB)KB")
        
        // Dateiname generieren
        let filename = "memory_\(UUID().uuidString.prefix(8)).jpg"
        
        // Speichere in Documents Directory
        guard let localURL = saveToDocuments(data: compressedData, filename: filename) else {
            print("❌ MemoryCreationViewModel: Fehler beim Speichern der Datei")
            return
        }
        
        // Photo-Entity in Background Context erstellen
        await createPhotoEntity(filename: filename, localURL: localURL, memoryID: memoryID)
    }
    
    /// Thread-sichere Photo-Entity Erstellung
    private func createPhotoEntity(filename: String, localURL: String, memoryID: UUID) async {
        await withCheckedContinuation { continuation in
            let backgroundContext = coreDataManager.backgroundContext
            
            backgroundContext.perform {
                do {
                    // Memory im Background Context finden
                    let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                    memoryRequest.predicate = NSPredicate(format: "id == %@", memoryID as CVarArg)
                    memoryRequest.fetchLimit = 1
                    
                    guard let backgroundMemory = try backgroundContext.fetch(memoryRequest).first else {
                        print("❌ MemoryCreationViewModel: Memory nicht im Background Context gefunden")
                        continuation.resume()
                        return
                    }
                    
                    // Photo-Entity erstellen
                    let photo = Photo(context: backgroundContext)
                    photo.id = UUID()
                    photo.filename = filename
                    photo.localURL = localURL
                    photo.createdAt = Date()
                    photo.memory = backgroundMemory
                    
                    try backgroundContext.save()
                    print("✅ MemoryCreationViewModel: Photo-Entity erfolgreich erstellt und verknüpft")
                    continuation.resume()
                    
                } catch {
                    print("❌ MemoryCreationViewModel: Fehler beim Speichern der Photo-Entity: \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    /// Einfache Bild-Resize-Funktion
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)
        
        guard maxCurrentDimension > maxDimension else { return image }
        
        let ratio = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Einfache Datei-Speicherung
    private func saveToDocuments(data: Data, filename: String) -> String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ MemoryCreationViewModel: Documents Directory nicht verfügbar")
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            print("✅ MemoryCreationViewModel: Bild gespeichert: \(fileURL.lastPathComponent)")
            return fileURL.path  // String-Pfad für Core Data zurückgeben
        } catch {
            print("❌ MemoryCreationViewModel: Fehler beim Speichern: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Form Reset
    func resetForm() {
        title = ""
        content = ""
        selectedImage = nil
        photoPickerItem = nil
        Task { @MainActor in
            await updateLocation()
        }
    }
} 