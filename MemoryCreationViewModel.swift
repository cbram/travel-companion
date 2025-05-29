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
    
    // UI State
    @Published var showingImagePicker = false
    @Published var showingPhotoPicker = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var isSaving = false
    
    // Error Handling
    @Published var errorMessage = ""
    
    // PHPicker
    @Published var photoPickerItem: PhotosPickerItem?
    
    // Image Picker Type
    var imageSourceType: UIImagePickerController.SourceType = .camera
    
    // MARK: - Dependencies
    private let trip: Trip
    private let user: User
    private let coreDataManager = CoreDataManager.shared
    private let locationManager = LocationManager.shared
    
    // MARK: - Computed Properties
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        currentLocation != nil
    }
    
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    // MARK: - Initialization
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        
        // Initial location setup
        setupLocation()
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
        guard canSave else {
            showError("Bitte fülle alle erforderlichen Felder aus")
            return
        }
        
        isSaving = true
        
        do {
            // Create Footstep (Memory) in Core Data
            let footstep = try await createFootstep()
            
            // Save photo if available
            if let image = selectedImage {
                try await savePhoto(for: footstep, image: image)
            }
            
            // Save Core Data context
            try coreDataManager.save()
            
            // Show success
            showingSuccess = true
            
            // Reset form
            resetForm()
            
        } catch {
            showError("Fehler beim Speichern: \(error.localizedDescription)")
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
                    footstep.timestamp = Date()
                    footstep.createdAt = Date()
                    footstep.author = backgroundUser
                    footstep.trip = backgroundTrip
                    
                    // Set location
                    if let location = self.currentLocation {
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
    
    private func savePhoto(for footstep: Footstep, image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            coreDataManager.backgroundContext.perform {
                do {
                    // Get footstep in background context
                    let backgroundFootstep = self.coreDataManager.backgroundContext.object(with: footstep.objectID) as! Footstep
                    
                    // Generate unique filename
                    let filename = "\(UUID().uuidString).jpg"
                    
                    // Save image to local storage
                    let localURL = try self.saveImageToDocuments(image: image, filename: filename)
                    
                    // Create Photo entity
                    let photo = Photo(context: self.coreDataManager.backgroundContext)
                    photo.id = UUID()
                    photo.filename = filename
                    photo.localURL = localURL
                    photo.createdAt = Date()
                    photo.footstep = backgroundFootstep
                    
                    try self.coreDataManager.backgroundContext.save()
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - File Management
    private func saveImageToDocuments(image: UIImage, filename: String) throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw MemoryCreationError.imageCompressionFailed
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(filename)
        
        try imageData.write(to: imageURL)
        
        return imageURL.path
    }
    
    // MARK: - Permission Checking
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
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func resetForm() {
        title = ""
        content = ""
        selectedImage = nil
        photoPickerItem = nil
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