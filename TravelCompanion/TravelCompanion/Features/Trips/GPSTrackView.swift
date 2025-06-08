import SwiftUI
import MapKit

// MARK: - Photo Extension
extension Photo {
    /// Sicher ein UIImage aus der localURL erstellen
    var uiImage: UIImage? {
        guard let urlString = self.localURL, let url = URL(string: urlString) else {
            return nil
        }
        // In einer produktiven App sollte das Laden im Hintergrund erfolgen
        // und Caching implementiert werden.
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

@available(iOS 17.0, *)
struct GPSTrackView: View {
    let trip: Trip
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var trackCoordinates: [CLLocationCoordinate2D] = []
    @State private var allAnnotations: [MapAnnotationItem] = []

    var body: some View {
        VStack(spacing: 0) {
            if !trackCoordinates.isEmpty {
                Map(position: $cameraPosition) {
                    // 1. Polyline für den Track
                    MapPolyline(coordinates: trackCoordinates)
                        .stroke(.blue, lineWidth: 4)

                    // 2. Annotationen für Start, Ende und Memories
                    ForEach(allAnnotations) { item in
                        Annotation("", coordinate: item.coordinate, anchor: .bottom) {
                            switch item {
                            case .start:
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                    .background(Circle().fill(.white))
                                    .shadow(radius: 2)
                            case .end:
                                Image(systemName: "flag.checkered.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                    .background(Circle().fill(.white))
                                    .shadow(radius: 2)
                            case .memory(let memory):
                                if let image = memory.thumbnail {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 3)
                                } else {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.orange)
                                        .background(Circle().fill(.white))
                                        .shadow(radius: 2)
                                }
                            }
                        }
                    }
                }
                .onAppear(perform: zoomToTrack)
                .frame(height: 350)
                .cornerRadius(16)
                .padding()

                // Info Section
                trackInfoSection

            } else {
                VStack {
                    ProgressView()
                    Text("GPS-Track wird geladen...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("GPS-Track")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }

    private var trackInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPS-Punkte: \(trackCoordinates.count)")
                .font(.subheadline)
            let memoryCount = allAnnotations.filter { if case .memory = $0 { return true } else { return false } }.count
            Text("Memories: \(memoryCount)")
                .font(.subheadline)
        }
        .padding(.horizontal)
    }

    // MARK: - Data Loading
    private func loadData() {
        // Lade Footsteps als Koordinaten
        let footsteps = CoreDataManager.shared.fetchFootsteps(for: trip)
        let coords = footsteps
            .sorted { $0.timestamp ?? .distantPast < $1.timestamp ?? .distantPast }
            .compactMap { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter { CLLocationCoordinate2DIsValid($0) }
        
        self.trackCoordinates = coords

        // Erstelle Annotationen
        var annotations: [MapAnnotationItem] = []
        if let firstCoord = coords.first {
            annotations.append(.start(firstCoord))
        }
        if let lastCoord = coords.last {
            annotations.append(.end(lastCoord))
        }

        let memoryItems = footsteps.compactMap { memory -> MapAnnotationItem? in
            guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)) else { return nil }
            return .memory(
                MemoryAnnotation(
                    id: memory.id ?? UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude),
                    thumbnail: memory.photosArray.first?.uiImage
                )
            )
        }
        annotations.append(contentsOf: memoryItems)
        self.allAnnotations = annotations
        
        // Initial-Zoom
        zoomToTrack()
    }
    
    private func zoomToTrack() {
        guard !trackCoordinates.isEmpty else { return }
        let mapRect = trackCoordinates.reduce(MKMapRect.null) { rect, coord in
            let point = MKMapPoint(coord)
            return rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        self.cameraPosition = .rect(mapRect.insetBy(dx: -mapRect.width * 0.1, dy: -mapRect.height * 0.1))
    }
}


// MARK: - Annotation Models
fileprivate enum MapAnnotationItem: Identifiable {
    case start(CLLocationCoordinate2D)
    case end(CLLocationCoordinate2D)
    case memory(MemoryAnnotation)

    var id: String {
        switch self {
        case .start: "start"
        case .end: "end"
        case .memory(let mem): mem.id.uuidString
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .start(let coord): return coord
        case .end(let coord): return coord
        case .memory(let mem): return mem.coordinate
        }
    }
}

fileprivate struct MemoryAnnotation: Identifiable, Hashable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let thumbnail: UIImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: MemoryAnnotation, rhs: MemoryAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
struct GPSTrackView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GPSTrackView(trip: SampleDataCreator.createSampleTrip())
        }
    }
}
