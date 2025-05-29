import SwiftUI
import CoreLocation

/// Kompakte Card-Ansicht für ein Memory (Footstep) in der Timeline
struct MemoryCardView: View {
    let footstep: Footstep
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
                Text(footstep.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // Timestamp
                Text(footstep.timeAgo)
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
                if footstep.hasContent {
                    Text(footstep.shortDescription)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete Action
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            
            // Edit Action
            Button {
                onEdit()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }
    
    // MARK: - Thumbnail View
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
            
            if isLoadingThumbnail {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                // Placeholder Icon
                Image(systemName: footstep.hasPhotos ? "photo" : "location.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Bottom Info Row
    @ViewBuilder
    private var bottomInfoRow: some View {
        HStack(spacing: 8) {
            // Photo Count (wenn vorhanden)
            if footstep.hasPhotos {
                Label("\(footstep.photoCount)", systemImage: "camera.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            // Trip Info
            if let tripTitle = footstep.trip?.title {
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
            if footstep.hasPhotos {
                Image(systemName: "icloud.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedLocation: String? {
        // Hier könnte man Reverse Geocoding implementieren
        // Für jetzt zeigen wir nur Koordinaten
        let lat = footstep.latitude
        let lon = footstep.longitude
        
        if lat != 0 || lon != 0 {
            return String(format: "%.4f, %.4f", lat, lon)
        }
        return nil
    }
    
    // MARK: - Methods
    
    private func loadThumbnailIfNeeded() {
        guard thumbnail == nil, !isLoadingThumbnail, footstep.hasPhotos else { return }
        
        isLoadingThumbnail = true
        
        // Asynchrones Laden des Thumbnails
        Task {
            let loadedThumbnail = await loadThumbnail()
            await MainActor.run {
                self.thumbnail = loadedThumbnail
                self.isLoadingThumbnail = false
            }
        }
    }
    
    @MainActor
    private func loadThumbnail() async -> UIImage? {
        guard let firstPhoto = footstep.firstPhoto() else { return nil }
        
        // Versuche zuerst ein kleines Thumbnail zu generieren
        if let thumbnail = firstPhoto.generateThumbnail(size: CGSize(width: 120, height: 120)) {
            return thumbnail
        }
        
        // Fallback: Original Image laden und verkleinern
        return firstPhoto.loadImage()
    }
}

// MARK: - Preview
struct MemoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            // Memory mit Photo
            MemoryCardView(
                footstep: createSampleFootstep(withPhoto: true),
                onEdit: {},
                onDelete: {}
            )
            
            // Memory ohne Photo
            MemoryCardView(
                footstep: createSampleFootstep(withPhoto: false),
                onEdit: {},
                onDelete: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
    
    static func createSampleFootstep(withPhoto: Bool) -> Footstep {
        let context = PersistenceController.preview.container.viewContext
        
        let footstep = Footstep(context: context)
        footstep.id = UUID()
        footstep.title = withPhoto ? "Kolosseum in Rom" : "Schöner Sonnenuntergang"
        footstep.content = withPhoto ? "Beeindruckende Architektur des antiken Amphitheaters" : nil
        footstep.latitude = 41.8902
        footstep.longitude = 12.4922
        footstep.timestamp = Date().addingTimeInterval(-Double.random(in: 0...86400*7))
        footstep.createdAt = Date()
        
        // Trip hinzufügen
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Italien Reise"
        trip.startDate = Date().addingTimeInterval(-86400*3)
        trip.createdAt = Date()
        footstep.trip = trip
        
        if withPhoto {
            let photo = Photo(context: context)
            photo.id = UUID()
            photo.filename = "kolosseum.jpg"
            photo.createdAt = Date()
            photo.footstep = footstep
        }
        
        return footstep
    }
} 