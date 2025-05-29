import SwiftUI
import CoreLocation

/// Placeholder Settings View
struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "gearshape")
                    .font(.system(size: 60))
                    .foregroundColor(.purple.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Einstellungen")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Hier findest du alle App-Einstellungen, GPS-Status und Cache-Verwaltung.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Einstellungen")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 