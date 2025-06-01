//
//  Photo+Extensions.swift
//  TravelCompanion
//
//  Created on 2024.
//

import Foundation
import CoreData
import UIKit

// MARK: - Photo Extensions
extension Photo {
    
    // MARK: - Computed Properties
    
    /// Formatiertes Erstellungsdatum
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt ?? Date())
    }
    
    /// Verfügbare URL (lokal oder cloud)
    var availableURL: String? {
        return localURL ?? cloudURL
    }
    
    /// Prüft ob Foto lokal verfügbar ist
    var isLocalAvailable: Bool {
        guard let localURL = localURL else { return false }
        return FileManager.default.fileExists(atPath: localURL)
    }
    
    /// Prüft ob Foto in Cloud verfügbar ist
    var isCloudAvailable: Bool {
        return cloudURL != nil && !cloudURL!.isEmpty
    }
    
    /// Dateiname ohne Extension
    var nameWithoutExtension: String {
        guard let filename = filename else { return "" }
        return URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }
    
    /// Dateierweiterung
    var fileExtension: String {
        guard let filename = filename else { return "" }
        return URL(fileURLWithPath: filename).pathExtension
    }
    
    /// Geschätzte Dateigröße basierend auf Filename
    var estimatedFileSize: String {
        guard let localURL = localURL else { return "Unbekannt" }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localURL)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("❌ Photo: Fehler beim Lesen der Dateigröße: \(error)")
        }
        
        return "Unbekannt"
    }
    
    // MARK: - Convenience Methods
    
    /// Holt Fotos für eine Memory
    static func fetchPhotos(for memory: Memory, in context: NSManagedObjectContext) -> [Photo] {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "memory == %@", memory)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Photo: Fehler beim Laden der Fotos für Memory: \(error)")
            return []
        }
    }
    
    /// Lädt UIImage vom lokalen Pfad
    func loadUIImage() -> UIImage? {
        guard let localURL = localURL else { return nil }
        return UIImage(contentsOfFile: localURL)
    }
    
    /// Speichert UIImage lokal und setzt localURL
    func saveUIImage(_ image: UIImage, to directory: URL) -> Bool {
        let safeFilename = filename ?? "photo_\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = directory.appendingPathComponent(safeFilename)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Photo: Fehler beim Konvertieren des Bildes zu JPEG")
            return false
        }
        
        do {
            try imageData.write(to: fileURL)
            localURL = fileURL.path
            print("✅ Photo: Bild gespeichert unter: \(fileURL.path)")
            return true
        } catch {
            print("❌ Photo: Fehler beim Speichern des Bildes: \(error)")
            return false
        }
    }
    
    /// Löscht lokale Datei
    func deleteLocalFile() -> Bool {
        guard let localURL = localURL else { return true } // Nichts zu löschen
        
        do {
            try FileManager.default.removeItem(atPath: localURL)
            self.localURL = nil
            print("✅ Photo: Lokale Datei gelöscht: \(localURL)")
            return true
        } catch {
            print("❌ Photo: Fehler beim Löschen der lokalen Datei: \(error)")
            return false
        }
    }
    
    /// Erstellt einen eindeutigen Dateinamen
    static func generateUniqueFilename(originalName: String? = nil) -> String {
        let timestamp = DateFormatter.filenameFormatter.string(from: Date())
        let uuid = UUID().uuidString.prefix(8)
        
        if let originalName = originalName, !originalName.isEmpty {
            let url = URL(fileURLWithPath: originalName)
            let nameWithoutExt = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            return "\(nameWithoutExt)_\(timestamp)_\(uuid).\(ext)"
        } else {
            return "photo_\(timestamp)_\(uuid).jpg"
        }
    }
    
    /// Erstellt Thumbnail URL für lokale Datei
    var thumbnailURL: String? {
        guard let localURL = localURL else { return nil }
        let url = URL(fileURLWithPath: localURL)
        let thumbnailURL = url.appendingPathExtension("thumb.jpg")
        return thumbnailURL.path
    }
    
    /// Erstellt und speichert Thumbnail
    func createThumbnail(size: CGSize = CGSize(width: 150, height: 150)) -> Bool {
        guard let image = loadUIImage(),
              let thumbnailURL = thumbnailURL else { return false }
        
        let thumbnail = image.resized(to: size)
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else { return false }
        
        do {
            try thumbnailData.write(to: URL(fileURLWithPath: thumbnailURL))
            return true
        } catch {
            print("❌ Photo: Fehler beim Speichern des Thumbnails: \(error)")
            return false
        }
    }
    
    /// Lädt Thumbnail als UIImage
    func loadThumbnail() -> UIImage? {
        guard let thumbnailURL = thumbnailURL else { return nil }
        return UIImage(contentsOfFile: thumbnailURL)
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

// MARK: - UIImage Extension
private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
} 