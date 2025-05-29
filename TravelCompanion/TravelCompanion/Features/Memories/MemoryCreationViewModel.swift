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
    private let tripManager = TripManager.shared
    
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
        // Aktive Reise und User aus TripManager holen
        self.trip = tripManager.currentTrip
        self.user = getCurrentUser()
    }
    
    func checkActiveTrip() {
        if trip == nil || user == nil {
            showingNoTripAlert = true
        }
    }
    
    private func getCurrentUser() -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try coreDataManager.viewContext.fetch(request)
            return users.first
        } catch {
            print("❌ MemoryCreationViewModel: Fehler beim Laden des Users: \(error)")
            return nil
        }
    }
    
    // MARK: - Location Management
    private func setupLocation() {
        // Get current location from LocationManager
        if let location = locationManager.currentLocation {
            self.currentLocation = location
        } else {
            // Request location update
            updateLocation()
        }
    }
    
    func updateLocation() {
        // Get fresh location from LocationManager
        if let location = locationManager.currentLocation {
            self.currentLocation = location
        } else {
            // If no location available, request permission and wait
            locationManager.requestPermission()
            
            // Use a simple polling approach for demo
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let location = self.locationManager.currentLocation {
                    self.currentLocation = location
                }
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
        guard let trip = trip, let user = user else {
            showError("Keine aktive Reise oder User vorhanden")
            return
        }
        
        guard canSave else {
            showError("Bitte fülle alle erforderlichen Felder aus")
            return
        }
        
        isSaving = true
        
        do {
            // Create Memory using CoreDataManager
            let memory = coreDataManager.createMemory(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: currentLocation?.coordinate.latitude ?? 0.0,
                longitude: currentLocation?.coordinate.longitude ?? 0.0,
                author: user,
                trip: trip
            )
            
            // Save photo if available
            if let image = selectedImage {
                let photo = coreDataManager.createPhoto(
                    filename: "memory_\(UUID().uuidString).jpg",
                    localURL: nil, // In Production hier lokale Speicherung
                    memory: memory
                )
                
                // TODO: In Production hier Foto speichern
                print("📷 MemoryCreationViewModel: Foto würde gespeichert für \(photo.filename ?? "unknown")")
            }
            
            // Save Core Data context
            guard coreDataManager.save() else {
                throw NSError(domain: "MemoryCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fehler beim Speichern in Core Data"])
            }
            
            print("✅ MemoryCreationViewModel: Memory erfolgreich erstellt: \(title)")
            
            // Show success
            showingSuccess = true
            
            // Reset form
            resetForm()
            
        } catch {
            showError("Fehler beim Speichern: \(error.localizedDescription)")
        }
        
        isSaving = false
    }
    
    // MARK: - Helper Methods
    private func resetForm() {
        title = ""
        content = ""
        selectedImage = nil
        photoPickerItem = nil
        // Location bleibt für nächstes Memory
    }
    
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
}

// MARK: - Errors
enum MemoryCreationError: LocalizedError {
    case imageCompressionFailed
    case locationNotAvailable
    case coreDataSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Foto konnte nicht komprimiert werden"
        case .locationNotAvailable:
            return "GPS-Position nicht verfügbar"
        case .coreDataSaveFailed:
            return "Speichern in Core Data fehlgeschlagen"
        }
    }
} 