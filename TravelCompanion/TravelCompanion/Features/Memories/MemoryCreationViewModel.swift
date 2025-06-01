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
    private func setupInitialData() {
        // Hole aktive Reise und User direkt aus der Core Data mit korrektem Context Management
        
        // Lade ersten verfügbaren User im View Context
        let users = coreDataManager.fetchAllUsers()
        if users.isEmpty {
            // Erstelle Sample Data falls leer
            print("📝 MemoryCreationViewModel: Keine User gefunden, erstelle Sample Data")
            SampleDataCreator.createSampleData(in: coreDataManager.viewContext)
            
            // Speichere sofort nach Sample Data Erstellung
            do {
                try coreDataManager.viewContext.save()
                print("✅ MemoryCreationViewModel: Sample Data gespeichert")
            } catch {
                print("❌ MemoryCreationViewModel: Sample Data Speicherfehler: \(error)")
            }
            
            let newUsers = coreDataManager.fetchAllUsers()
            self.user = newUsers.first
        } else {
            self.user = users.first
        }
        
        // Lade aktive Reise für User - wichtig: User muss aus viewContext kommen
        if let currentUser = user {
            self.trip = coreDataManager.fetchActiveTrip(for: currentUser)
            
            // Falls keine aktive Reise, nimm die erste verfügbare oder erstelle eine
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
                    // Erstelle neue Standard-Reise direkt im viewContext
                    let newTrip = coreDataManager.createTrip(
                        title: "Meine erste Reise",
                        description: "Willkommen bei TravelCompanion!",
                        startDate: Date(),
                        owner: currentUser
                    )
                    coreDataManager.setTripActive(newTrip, isActive: true)
                    do {
                        try coreDataManager.viewContext.save()
                        self.trip = newTrip
                        print("✅ MemoryCreationViewModel: Neue Standard-Reise erstellt")
                    } catch {
                        print("❌ MemoryCreationViewModel: Fehler beim Speichern der neuen Reise: \(error)")
                    }
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
            updateLocation()
        }
    }
    
    @Published var isUpdatingLocation = false
    private var locationUpdateTask: Task<Void, Never>?
    
    func updateLocation() {
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
        
        locationUpdateTask = Task {
            // Single location request mit Timeout
            locationManager.requestCurrentLocation()
            
            // Warten auf Update mit Timeout
            for attempt in 1...3 {
                if Task.isCancelled { return }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 Sekunden
                
                if let location = locationManager.currentLocation {
                    await MainActor.run {
                        self.currentLocation = location
                        self.isUpdatingLocation = false
                        print("✅ MemoryCreationViewModel: GPS-Location erhalten: \(location.formattedCoordinates)")
                    }
                    return
                }
                
                print("📍 MemoryCreationViewModel: GPS-Versuch \(attempt)/3...")
            }
            
            // Fallback nach Timeout
            await MainActor.run {
                if self.currentLocation == nil {
                    self.currentLocation = CLLocation(latitude: 48.1351, longitude: 11.5820)
                    print("📍 MemoryCreationViewModel: Verwende München als Fallback-Location")
                }
                self.isUpdatingLocation = false
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
        
        // Direkte Memory-Erstellung im Main Context für Context-Kompatibilität
        do {
            // Memory direkt im viewContext erstellen - alle Objekte sind aus dem gleichen Context
            let memory = coreDataManager.createMemory(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: lat,
                longitude: lon,
                author: user, // user ist aus viewContext
                trip: trip    // trip ist aus viewContext
            )
            
            // Context speichern
            try coreDataManager.viewContext.save()
            
            print("✅ MemoryCreationViewModel: Memory erfolgreich gespeichert")
            
            // Foto separat speichern falls vorhanden und mit Memory verknüpfen
            if let image = selectedImage {
                await savePhotoOptimized(image: image, for: memory)
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
    
    /// Optimierte Foto-Speicherung mit Core Data Verknüpfung
    private func savePhotoOptimized(image: UIImage, for memory: Memory) async {
        print("📷 MemoryCreationViewModel: Speichere Foto optimiert...")
        
        // Vereinfachte synchrone Verarbeitung
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
        
        // Photo-Entity in Core Data erstellen und mit Memory verknüpfen
        let photo = coreDataManager.createPhoto(
            filename: filename,
            localURL: localURL,
            memory: memory
        )
        
        do {
            // Context erneut speichern für die Photo-Entity
            try coreDataManager.viewContext.save()
            print("✅ MemoryCreationViewModel: Photo-Entity erfolgreich erstellt und verknüpft")
        } catch {
            print("❌ MemoryCreationViewModel: Fehler beim Speichern der Photo-Entity: \(error)")
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
        updateLocation()
    }
} 