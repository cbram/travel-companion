import Foundation
import CoreData
import UIKit

@objc(Photo)
public class Photo: NSManagedObject {
    
    // MARK: - Computed Properties
    
    var fileExtension: String {
        return (filename as NSString).pathExtension.lowercased()
    }
    
    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        return imageExtensions.contains(fileExtension)
    }
    
    var hasLocalFile: Bool {
        guard let localURL = localURL else { return false }
        return FileManager.default.fileExists(atPath: localURL)
    }
    
    var hasCloudFile: Bool {
        return cloudURL != nil && !cloudURL!.isEmpty
    }
    
    var isSynced: Bool {
        return hasLocalFile && hasCloudFile
    }
    
    var needsUpload: Bool {
        return hasLocalFile && !hasCloudFile
    }
    
    var needsDownload: Bool {
        return !hasLocalFile && hasCloudFile
    }
    
    var displayName: String {
        let nameWithoutExtension = (filename as NSString).deletingPathExtension
        return nameWithoutExtension.isEmpty ? "Unbenannt" : nameWithoutExtension
    }
    
    var formattedFileSize: String {
        guard let localURL = localURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: localURL),
              let fileSize = attributes[.size] as? Int64 else {
            return "Unbekannt"
        }
        
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "Gerade eben"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "vor \(minutes) Min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "vor \(hours) Std"
        } else {
            let days = Int(interval / 86400)
            return "vor \(days) Tag\(days == 1 ? "" : "en")"
        }
    }
    
    // MARK: - File Management
    
    func localFileURL() -> URL? {
        guard let localURL = localURL else { return nil }
        return URL(fileURLWithPath: localURL)
    }
    
    func cloudFileURL() -> URL? {
        guard let cloudURL = cloudURL else { return nil }
        return URL(string: cloudURL)
    }
    
    func loadImage() -> UIImage? {
        guard isImage, let url = localFileURL() else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    func loadImageData() -> Data? {
        guard let url = localFileURL() else { return nil }
        return try? Data(contentsOf: url)
    }
    
    func deleteLocalFile() -> Bool {
        guard let url = localFileURL(), hasLocalFile else { return false }
        
        do {
            try FileManager.default.removeItem(at: url)
            localURL = nil
            return true
        } catch {
            print("Fehler beim Löschen der lokalen Datei: \(error)")
            return false
        }
    }
    
    func generateThumbnail(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let image = loadImage() else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Permissions
    
    func canDelete(by user: User) -> Bool {
        return footstep?.author == user || footstep?.trip?.owner == user
    }
    
    func canEdit(by user: User) -> Bool {
        return footstep?.author == user || footstep?.trip?.owner == user
    }
    
    // MARK: - Validation
    
    static func isValidImageFile(_ filename: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        let fileExtension = (filename as NSString).pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
    
    static func generateUniqueFilename(originalName: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        let fileExtension = (originalName as NSString).pathExtension
        let baseName = (originalName as NSString).deletingPathExtension
        
        if fileExtension.isEmpty {
            return "\(baseName)_\(timestamp)_\(uuid)"
        } else {
            return "\(baseName)_\(timestamp)_\(uuid).\(fileExtension)"
        }
    }
} 