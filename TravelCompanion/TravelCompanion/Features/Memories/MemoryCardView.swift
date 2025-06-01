import SwiftUI
import CoreLocation

/// Kompakte Card-Ansicht für ein Memory in der Timeline
struct MemoryCardView: View {
    let memory: Memory
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail oder Placeholder
            thumbnailView
            
            // Memory Content
            VStack(alignment: .leading, spacing: 6) {
                // Titel
                Text(memory.title ?? "Unbenanntes Memory")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // Timestamp
                Text(memory.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Location (wenn verfügbar)
                if let locationText = formattedLocation {
                    Label(locationText, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Content Preview (wenn vorhanden)
                if memory.hasContent {
                    Text(memory.shortDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Bottom Info Row
                bottomInfoRow
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .onAppear {
            loadThumbnailIfNeeded()
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Thumbnail View
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: 64, height: 64)
            
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoadingThumbnail {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                // Default Icon basierend auf Memory-Typ
                VStack(spacing: 2) {
                    Image(systemName: memory.hasPhotos ? "photo" : "location.circle")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    if memory.hasPhotos {
                        Text("\(memory.photoCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Info Row
    private var bottomInfoRow: some View {
        HStack(spacing: 8) {
            // Photo Count (wenn vorhanden)
            if memory.hasPhotos {
                Label("\(memory.photoCount)", systemImage: "camera.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            // Trip Info
            if let tripTitle = memory.trip?.title {
                Label(tripTitle, systemImage: "suitcase.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Memory Status Indicator
            statusIndicator
        }
    }
    
    // MARK: - Status Indicator
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            // GPS Indicator
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            // Sync Status (für zukünftige CloudKit Integration)
            if memory.hasPhotos {
                Image(systemName: "icloud.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onEdit) {
            Label("Bearbeiten", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive, action: onDelete) {
            Label("Löschen", systemImage: "trash")
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedLocation: String? {
        // Hier könnte man Reverse Geocoding implementieren
        // Für jetzt zeigen wir nur Koordinaten
        let lat = memory.latitude
        let lon = memory.longitude
        
        if lat != 0 || lon != 0 {
            return String(format: "%.4f, %.4f", lat, lon)
        }
        return nil
    }
    
    // MARK: - Methods
    
    private func loadThumbnailIfNeeded() {
        guard thumbnail == nil, !isLoadingThumbnail, memory.hasPhotos else { return }
        
        isLoadingThumbnail = true
        
        Task {
            let loadedThumbnail = await loadThumbnail()
            
            await MainActor.run {
                self.thumbnail = loadedThumbnail
                self.isLoadingThumbnail = false
            }
        }
    }
    
    private func loadThumbnail() async -> UIImage? {
        guard let firstPhoto = memory.firstPhoto() else { return nil }
        
        // Versuche das Foto vom lokalen Pfad zu laden
        if let image = firstPhoto.loadUIImage() {
            // Erzeuge ein Thumbnail für bessere Performance
            let thumbnailSize = CGSize(width: 64, height: 64)
            let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            }
            return thumbnail
        }
        
        // Fallback: Lade Thumbnail falls vorhanden
        if let thumbnail = firstPhoto.loadThumbnail() {
            return thumbnail
        }
        
        print("❌ MemoryCardView: Konnte kein Foto für Memory '\(memory.title ?? "Unknown")' laden")
        return nil
    }
}

// MARK: - Memory Extensions für MemoryCardView

extension Memory {
    /// Prüft, ob das Memory Fotos hat
    var hasPhotos: Bool {
        guard let photos = photos else { return false }
        return photos.count > 0
    }
    
    /// Anzahl der Fotos
    var photoCount: Int {
        return photos?.count ?? 0
    }
    
    /// Prüft, ob das Memory Content hat
    var hasContent: Bool {
        return content != nil && !content!.isEmpty
    }
    
    /// Kurze Beschreibung für Vorschau
    var shortDescription: String {
        guard let content = content else { return "" }
        return String(content.prefix(100))
    }
    
    /// Formatierte Zeit (z.B. "vor 2 Stunden")
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .abbreviated
        
        if let timestamp = timestamp {
            return formatter.localizedString(for: timestamp, relativeTo: Date())
        } else {
            return "Unbekannt"
        }
    }
}

// MARK: - Preview

struct MemoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            // Memory mit Photo
            MemoryCardView(
                memory: createSampleMemory(withPhoto: true),
                onEdit: {},
                onDelete: {}
            )
            
            // Memory ohne Photo
            MemoryCardView(
                memory: createSampleMemory(withPhoto: false),
                onEdit: {},
                onDelete: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
    
    static func createSampleMemory(withPhoto: Bool) -> Memory {
        let context = PersistenceController.preview.container.viewContext
        
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.title = withPhoto ? "Kolosseum in Rom" : "Schöner Sonnenuntergang"
        memory.content = withPhoto ? "Beeindruckende Architektur des antiken Amphitheaters" : nil
        memory.latitude = 41.8902
        memory.longitude = 12.4922
        memory.timestamp = Date().addingTimeInterval(-Double.random(in: 0...86400*7))
        memory.createdAt = Date()
        
        // Trip hinzufügen
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Italien Reise"
        trip.startDate = Date().addingTimeInterval(-86400*3)
        trip.createdAt = Date()
        memory.trip = trip
        
        if withPhoto {
            let photo = Photo(context: context)
            photo.id = UUID()
            photo.filename = "kolosseum.jpg"
            photo.createdAt = Date()
            photo.memory = memory
        }
        
        return memory
    }
} 