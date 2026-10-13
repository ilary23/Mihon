import SwiftUI

@main
struct MihonReaderApp: App {
    @StateObject private var store = LibraryStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView().tabItem { Label("Bibliothèque", systemImage: "books.vertical.fill") }
                RecentView().tabItem { Label("Historique", systemImage: "clock") }
                SettingsView().tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
            }
            .environmentObject(store).tint(.mint).preferredColorScheme(.dark)
            .alert("Une opération a échoué", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: LibraryStore
    @AppStorage("readingMode") private var mode = "paged"
    @AppStorage("rightToLeft") private var rightToLeft = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Lecteur") {
                    Picker("Mode par défaut", selection: $mode) {
                        Text("Page par page").tag("paged")
                        Text("Vertical / webtoon").tag("vertical")
                    }
                    Toggle("Lire de droite vers gauche", isOn: $rightToLeft)
                    Text("En mode paginé : pince pour zoomer, double-tape pour réinitialiser ou agrandir. Glisse l’image agrandie pour la déplacer.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Bibliothèque locale") {
                    LabeledContent("Titres importés", value: "\(store.books.count)")
                    LabeledContent("Formats", value: "PDF et images")
                    Text("Les fichiers sont copiés dans l’application. Leur suppression depuis Fichiers n’efface pas cette copie. Supprimer l’application efface sa bibliothèque ; conserve tes originaux.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Confidentialité") {
                    Label("Aucune télémétrie ajoutée", systemImage: "hand.raised")
                    Label("Aucun compte requis", systemImage: "person.crop.circle")
                    Label("Lecture locale hors ligne", systemImage: "wifi.slash")
                    Text("Les fichiers sélectionnés dans iCloud Drive peuvent être téléchargés par iOS lors de l’import. Le projet n’intègre aucun serveur ni SDK de suivi.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("À propos") {
                    Text("Mihon Reader · prototype indépendant").font(.headline)
                    Text("Version 0.1.0 — SwiftUI · iOS 17 minimum")
                    Text("Ce projet n’est pas une version officielle de Mihon et n’est pas affilié à son équipe. Les extensions APK, archives CBZ/CBR, sources en ligne, trackers et sauvegardes .tachibk ne sont pas pris en charge dans cette première version.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Réglages")
        }
    }
}
