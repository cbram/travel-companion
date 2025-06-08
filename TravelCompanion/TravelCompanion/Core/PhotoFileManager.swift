//
//  PhotoFileManager.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import Foundation
import UIKit
import CoreData
import Compression
import SwiftUI

/// Zentrale Klasse für Photo File Management mit Offline-Support und Compression
@MainActor
class PhotoFileManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PhotoFileManager()
    
    // MARK: - Published Properties
    @Published var storageUsed: Int64 = 0
    @Published var totalPhotos: Int = 0
    @Published var offlineQueueSize: Int = 0
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let persistenceController = PersistenceController.shared
    
    // Directory Paths
    public lazy var documentsDirectory: URL = {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()
    
    public lazy var photosDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("Photos")
        createDirectoryIfNeeded(url)
        return url
    }()
    
    private lazy var thumbnailsDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("Thumbnails")
        createDirectoryIfNeeded(url)
        return url
    }()
    
    private lazy var tempDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("Temp")
        createDirectoryIfNeeded(url)
        return url
    }()
    
    // Compression Settings
    private let standardCompressionQuality: CGFloat = 0.8
    private let thumbnailCompressionQuality: CGFloat = 0.7
    private let maxImageDimension: CGFloat = 2048
    private let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    
    // Offline Queue
    private var offlineQueue: [OfflinePhotoItem] = []
    private let offlineQueueKey = "photoOfflineQueue"
    
    // MARK: - Offline Photo Item
    struct OfflinePhotoItem: Codable {
        let id: UUID
        let memoryID: UUID
        let originalFilename: String
        let localURL: String
        let thumbnailURL: String?
        let timestamp: Date
        let compressionApplied: Bool
        let fileSize: Int64
    }
    
    // MARK: - Photo Storage Result
    enum PhotoSaveResult {
        case success(localURL: String, thumbnailURL: String?, fileSize: Int64)
        case failure(Error)
    }
    
    // MARK: - Initialization
    private init() {
        loadOfflineQueue()
        calculateStorageUsage()
        DebugLogger.shared.log("📁 PhotoFileManager initialisiert")
    }
    
    // MARK: - Directory Management
    
    private func createDirectoryIfNeeded(_ url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            DebugLogger.shared.log("📁 Directory erstellt: \(url.lastPathComponent)")
        } catch {
            DebugLogger.shared.log("❌ Directory Creation Fehler: \(error.localizedDescription)")
        }
    }
    
    private func createDirectoriesIfNeeded() {
        createDirectoryIfNeeded(photosDirectory)
        createDirectoryIfNeeded(thumbnailsDirectory)
        createDirectoryIfNeeded(tempDirectory)
        
        // Storage Usage neu berechnen
        calculateStorageUsage()
        
        DebugLogger.shared.info("✅ PhotoFileManager: Directories erstellt/validiert")
    }
    
    func validateFileSystem() async {
        DebugLogger.shared.info("🔍 PhotoFileManager: File System Validation gestartet")
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
        
        // Clean up temporary files
        await cleanupTempDirectory()
    }
    
    // MARK: - Photo Saving
    
    func savePhoto(_ image: UIImage, for memoryID: UUID, originalFilename: String? = nil) async -> PhotoSaveResult {
        let photoID = UUID()
        let filename = originalFilename ?? "photo_\(photoID.uuidString)"
        let localFilename = generateUniqueFilename(for: photoID, originalFilename: filename)
        
        do {
            // Haupt-Photo komprimieren und speichern
            let compressedImage = compressImage(image, maxDimension: maxImageDimension, quality: standardCompressionQuality)
            let photoURL = photosDirectory.appendingPathComponent(localFilename)
            
            guard let imageData = compressedImage.jpegData(compressionQuality: standardCompressionQuality) else {
                throw PhotoFileError.compressionFailed
            }
            
            try imageData.write(to: photoURL)
            
            // Thumbnail erstellen und speichern
            let thumbnailURL = try await createThumbnail(from: compressedImage, photoID: photoID)
            
            // File Size berechnen
            let fileSize = try getFileSize(at: photoURL)
            
            // Zur Offline Queue hinzufügen
            let offlineItem = OfflinePhotoItem(
                id: photoID,
                memoryID: memoryID,
                originalFilename: filename,
                localURL: photoURL.path,
                thumbnailURL: thumbnailURL?.path,
                timestamp: Date(),
                compressionApplied: true,
                fileSize: fileSize
            )
            
            await addToOfflineQueue(offlineItem)
            
            DebugLogger.shared.log("📸 Photo gespeichert: \(localFilename) (\(fileSize) bytes)")
            
            return .success(
                localURL: photoURL.path,
                thumbnailURL: thumbnailURL?.path,
                fileSize: fileSize
            )
            
        } catch {
            DebugLogger.shared.log("❌ Photo Save Fehler: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Photo Loading
    
    func loadPhoto(from localURL: String) -> UIImage? {
        let url = URL(fileURLWithPath: localURL)
        
        guard fileManager.fileExists(atPath: url.path) else {
            DebugLogger.shared.log("⚠️ Photo nicht gefunden: \(url.lastPathComponent)")
            return loadFallbackImage()
        }
        
        guard let image = UIImage(contentsOfFile: url.path) else {
            DebugLogger.shared.log("❌ Photo Loading Fehler: \(url.lastPathComponent)")
            return loadFallbackImage()
        }
        
        return image
    }
    
    func loadThumbnail(from thumbnailURL: String?) -> UIImage? {
        guard let thumbnailURL = thumbnailURL else { return nil }
        
        let url = URL(fileURLWithPath: thumbnailURL)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        return UIImage(contentsOfFile: url.path)
    }
    
    private func loadFallbackImage() -> UIImage? {
        // Fallback Image aus App Bundle laden
        return UIImage(systemName: "photo.fill")
    }
    
    // MARK: - Photo Deletion
    
    func deletePhotoFile(at localURL: String) {
        let url = URL(fileURLWithPath: localURL)
        
        do {
            try fileManager.removeItem(at: url)
            
            // Zugehöriges Thumbnail löschen
            if let thumbnailURL = getThumbnailURL(for: url) {
                try? fileManager.removeItem(at: thumbnailURL)
            }
            
            DebugLogger.shared.log("🗑️ Photo gelöscht: \(url.lastPathComponent)")
        } catch {
            DebugLogger.shared.log("❌ Photo Delete Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Image Compression
    
    private func compressImage(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> UIImage {
        let size = image.size
        
        // Prüfen ob Resize nötig
        guard max(size.width, size.height) > maxDimension else {
            return image
        }
        
        // Neue Größe berechnen
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Image resizen
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    private func createThumbnail(from image: UIImage, photoID: UUID) async throws -> URL? {
        let thumbnailImage = compressImage(image, maxDimension: max(thumbnailSize.width, thumbnailSize.height), quality: thumbnailCompressionQuality)
        
        let thumbnailFilename = "thumb_\(photoID.uuidString).jpg"
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFilename)
        
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: thumbnailCompressionQuality) else {
            throw PhotoFileError.thumbnailCreationFailed
        }
        
        try thumbnailData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    // MARK: - Filename Generation
    
    private func generateUniqueFilename(for photoID: UUID, originalFilename: String) -> String {
        let fileExtension = URL(fileURLWithPath: originalFilename).pathExtension.lowercased()
        let validExtension = ["jpg", "jpeg", "png", "heic"].contains(fileExtension) ? fileExtension : "jpg"
        
        return "\(photoID.uuidString).\(validExtension)"
    }
    
    private func getThumbnailURL(for photoURL: URL) -> URL? {
        let photoID = photoURL.deletingPathExtension().lastPathComponent
        let thumbnailFilename = "thumb_\(photoID).jpg"
        return thumbnailsDirectory.appendingPathComponent(thumbnailFilename)
    }
    
    // MARK: - Storage Management
    
    private func calculateStorageUsage() {
        Task {
            let photosSize = await calculateDirectorySize(photosDirectory)
            let thumbnailsSize = await calculateDirectorySize(thumbnailsDirectory)
            
            await MainActor.run {
                storageUsed = photosSize + thumbnailsSize
                totalPhotos = countFilesInDirectory(photosDirectory)
                DebugLogger.shared.log("💾 Storage Usage: \(formatBytes(storageUsed)) (\(totalPhotos) photos)")
            }
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var totalSize: Int64 = 0
                
                let localFileManager = FileManager.default
                guard let enumerator = localFileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
                    continuation.resume(returning: 0)
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch {
                        // Ignoriere Fehler und fahre fort
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    private func countFilesInDirectory(_ directory: URL) -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.count
        } catch {
            return 0
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Offline Queue Management
    
    private func loadOfflineQueue() {
        guard let data = UserDefaults.standard.data(forKey: offlineQueueKey) else {
            offlineQueue = []
            return
        }
        
        do {
            offlineQueue = try JSONDecoder().decode([OfflinePhotoItem].self, from: data)
            offlineQueueSize = offlineQueue.count
            DebugLogger.shared.log("📂 Offline Queue geladen: \(offlineQueue.count) items")
        } catch {
            DebugLogger.shared.log("❌ Offline Queue Load Fehler: \(error.localizedDescription)")
            offlineQueue = []
        }
    }
    
    func saveOfflineQueue() {
        do {
            let data = try JSONEncoder().encode(offlineQueue)
            UserDefaults.standard.set(data, forKey: offlineQueueKey)
            DebugLogger.shared.log("💾 Offline Queue gespeichert: \(offlineQueue.count) items")
        } catch {
            DebugLogger.shared.log("❌ Offline Queue Save Fehler: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func addToOfflineQueue(_ item: OfflinePhotoItem) async {
        offlineQueue.append(item)
        offlineQueueSize = offlineQueue.count
        saveOfflineQueue()
    }
    
    func processOfflineQueue() {
        guard !offlineQueue.isEmpty else { return }
        
        DebugLogger.shared.log("⚙️ Processing Offline Queue: \(offlineQueue.count) items")
        
        Task {
            for item in offlineQueue {
                await processOfflinePhotoItem(item)
            }
            
            await MainActor.run {
                offlineQueue.removeAll()
                offlineQueueSize = 0
                saveOfflineQueue()
            }
        }
    }
    
    private func processOfflinePhotoItem(_ item: OfflinePhotoItem) async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            do {
                // Memory finden
                let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                memoryRequest.predicate = NSPredicate(format: "id == %@", item.memoryID as CVarArg)
                
                guard let memory = try context.fetch(memoryRequest).first else {
                    DebugLogger.shared.log("⚠️ Memory nicht gefunden für Photo: \(item.id)")
                    return
                }
                
                // Core Data Photo erstellen
                let photo = Photo(context: context)
                photo.id = item.id
                photo.filename = item.originalFilename
                photo.localURL = item.localURL
                photo.createdAt = item.timestamp
                photo.memory = memory
                
                try context.save()
                DebugLogger.shared.log("✅ Offline Photo verarbeitet: \(item.originalFilename)")
                
            } catch {
                DebugLogger.shared.log("❌ Offline Photo Processing Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - File System Optimization
    
    func optimizeFileSystem() async {
        DebugLogger.shared.log("🔧 File System Optimization gestartet")
        
        await cleanupOrphanedFiles()
        await cleanupTempDirectory()
        await optimizePhotoCache()
        
        calculateStorageUsage()
        
        DebugLogger.shared.log("✅ File System Optimization abgeschlossen")
    }
    
    func optimizePhotoCache() async {
        // Implementierung für Photo Cache Optimization
        DebugLogger.shared.log("🧹 Photo Cache optimiert")
    }
    
    private func cleanupOrphanedFiles() async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            do {
                // Alle Photo Entities holen
                let photosRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                let savedPhotos = try context.fetch(photosRequest)
                let savedPhotoURLs = Set(savedPhotos.compactMap { $0.localURL })
                
                // Alle Dateien im Photos Directory
                let localFileManager = FileManager.default
                let photoFiles = try localFileManager.contentsOfDirectory(at: self.photosDirectory, includingPropertiesForKeys: nil)
                
                // Orphaned Files finden und löschen
                for fileURL in photoFiles {
                    if !savedPhotoURLs.contains(fileURL.path) {
                        try localFileManager.removeItem(at: fileURL)
                        DebugLogger.shared.log("🗑️ Orphaned Photo gelöscht: \(fileURL.lastPathComponent)")
                    }
                }
                
            } catch {
                DebugLogger.shared.log("❌ Orphaned Files Cleanup Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    private func cleanupTempDirectory() async {
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in tempFiles {
                try fileManager.removeItem(at: fileURL)
            }
            
            if !tempFiles.isEmpty {
                DebugLogger.shared.log("🧹 Temp Directory bereinigt: \(tempFiles.count) files")
            }
        } catch {
            DebugLogger.shared.log("❌ Temp Directory Cleanup Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug & Development Support
    
    func getStorageInfo() -> [String: Any] {
        return [
            "storageUsed": storageUsed,
            "totalPhotos": totalPhotos,
            "offlineQueueSize": offlineQueueSize,
            "photosDirectory": photosDirectory.path,
            "thumbnailsDirectory": thumbnailsDirectory.path
        ]
    }
    
    func resetFileSystem() async {
        DebugLogger.shared.log("🔄 File System Reset gestartet")
        
        do {
            // Alle Directories löschen
            try fileManager.removeItem(at: photosDirectory)
            try fileManager.removeItem(at: thumbnailsDirectory)
            try fileManager.removeItem(at: tempDirectory)
            
            // Directories neu erstellen
            await validateFileSystem()
            
            // Offline Queue leeren
            offlineQueue.removeAll()
            saveOfflineQueue()
            
            calculateStorageUsage()
            
            DebugLogger.shared.log("✅ File System Reset abgeschlossen")
        } catch {
            DebugLogger.shared.log("❌ File System Reset Fehler: \(error.localizedDescription)")
        }
    }
}

// MARK: - Photo File Errors

enum PhotoFileError: LocalizedError {
    case compressionFailed
    case thumbnailCreationFailed
    case fileNotFound
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Image compression failed"
        case .thumbnailCreationFailed:
            return "Thumbnail creation failed"
        case .fileNotFound:
            return "Photo file not found"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Image Cache

class ImageCache: ObservableObject {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        cache.totalCostLimit = maxCacheSize
    }
    
    func getImage(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough memory estimate
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        DebugLogger.shared.log("🧹 Image Cache geleert")
    }
} 