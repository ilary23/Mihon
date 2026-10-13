import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var search = ""
    @State private var selectedCategory = "Tous"
    @State private var showImport = false
    @State private var favoriteOnly = false
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]
    private var categories: [String] { ["Tous"] + Set(store.books.map(\.category)).sorted() }
    private var visible: [Book] {
        store.books.filter {
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) &&
            (selectedCategory == "Tous" || selectedCategory == $0.category) &&
            (!favoriteOnly || $0.favorite)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TON UNIVERS, À LIRE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.mint)
                            Text("Bibliothèque").font(.largeTitle.bold())
                            Text("\(store.books.count) titre\(store.books.count == 1 ? "" : "s") · fichiers sur cet iPhone")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showImport = true } label: {
                            Image(systemName: "plus").font(.title2.bold()).frame(width: 48, height: 48)
                        }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                            .accessibilityLabel("Importer des PDF ou des images").disabled(store.importing)
                    }
                    if store.importing { HStack { ProgressView(); Text("Import en cours…") }.font(.callout) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button(category) { selectedCategory = category }
                                    .buttonStyle(.bordered).tint(selectedCategory == category ? .mint : .gray)
                            }
                        }
                    }
                    if visible.isEmpty {
                        ContentUnavailableView {
                            Label(store.books.isEmpty ? "Ta prochaine lecture t’attend" : "Aucun résultat", systemImage: "books.vertical")
                        } description: {
                            Text(store.books.isEmpty ? "Importe un PDF ou plusieurs images depuis Fichiers. Les images sélectionnées forment un seul titre." : "Essaie un autre filtre ou une autre recherche.")
                        } actions: {
                            if store.books.isEmpty {
                                Button("Importer ma première lecture") { showImport = true }
                                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                            }
                        }.padding(.top, 36)
                    } else {
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(visible) { book in
                                NavigationLink { BookDetailView(id: book.id) } label: { BookCard(book: book) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Lecteur indépendant · aucune source Android intégrée")
                        .font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.top)
                }.padding(20)
            }
            .background(Color.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { favoriteOnly.toggle() } label: {
                        Image(systemName: favoriteOnly ? "heart.fill" : "heart")
                    }.tint(.mint).accessibilityLabel("Filtrer les favoris")
                }
            }
            .searchable(text: $search, prompt: "Rechercher un titre")
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await store.importFiles(urls) }
                case .failure(let error): store.error = error.localizedDescription
                }
            }
        }
    }
}

struct BookCard: View {
    let book: Book
    @EnvironmentObject private var store: LibraryStore
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PageImage(url: store.url(book, file: book.files[0]), pdf: book.isPDF, page: 0, width: 360)
                .frame(height: 210).frame(maxWidth: .infinity)
                .background(Color.panel).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .topTrailing) {
                    if book.favorite { Image(systemName: "heart.fill").foregroundStyle(.mint).padding(10).background(.black.opacity(0.5), in: Circle()).padding(8) }
                }
            Text(book.title).font(.headline).lineLimit(2)
            HStack {
                Text(book.isPDF ? "PDF" : "IMAGES").font(.caption2.bold()).foregroundStyle(.mint)
                Spacer()
                Text("\(book.pageCount) pages").font(.caption).foregroundStyle(.secondary)
            }
            if book.lastRead != nil { ProgressView(value: book.progress).tint(.mint) }
        }
    }
}

struct BookDetailView: View {
    let id: UUID
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showReader = false
    @State private var showDelete = false
    @State private var title = ""
    @State private var category = ""
    var body: some View {
        Group {
            if let book = store.book(id) {
                Form {
                    Section {
                        PageImage(url: store.url(book, file: book.files[0]), pdf: book.isPDF, page: 0, width: 600)
                            .frame(maxWidth: .infinity).frame(height: 260)
                            .listRowBackground(Color.panel)
                        Button { showReader = true } label: {
                            Label(book.lastRead == nil ? "Commencer la lecture" : "Reprendre · page \(book.currentPage + 1)", systemImage: "play.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding(6)
                        }.tint(.mint)
                    }
                    Section("Organisation") {
                        TextField("Titre", text: $title)
                        TextField("Catégorie", text: $category)
                        Button("Enregistrer les informations") {
                            store.update(id) {
                                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { $0.title = title }
                                $0.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Non classé" : category
                            }
                        }
                        Toggle("Favori", isOn: Binding(get: { store.book(id)?.favorite ?? false }, set: { value in store.update(id) { $0.favorite = value } }))
                    }
                    Section("Progression") {
                        LabeledContent("Pages", value: "\(book.pageCount)")
                        if let bookmark = book.bookmark { LabeledContent("Marque-page", value: "Page \(bookmark + 1)") }
                        Button("Recommencer à la première page") { store.update(id) { $0.currentPage = 0; $0.lastRead = nil } }
                    }
                    Section { Button("Supprimer les fichiers et le titre", role: .destructive) { showDelete = true } }
                }
                .navigationTitle(book.title).navigationBarTitleDisplayMode(.inline)
                .onAppear { title = book.title; category = book.category }
                .fullScreenCover(isPresented: $showReader) { ReaderView(id: id) }
                .confirmationDialog("Supprimer ce titre ? Ses fichiers importés seront effacés de l’application.", isPresented: $showDelete, titleVisibility: .visible) {
                    Button("Supprimer", role: .destructive) { store.delete(id); dismiss() }
                }
            } else { ContentUnavailableView("Titre introuvable", systemImage: "book.closed") }
        }
    }
}

struct RecentView: View {
    @EnvironmentObject private var store: LibraryStore
    var body: some View {
        NavigationStack {
            let recent = store.books.filter { $0.lastRead != nil }.sorted { ($0.lastRead ?? .distantPast) > ($1.lastRead ?? .distantPast) }
            List {
                if recent.isEmpty { ContentUnavailableView("Pas encore de lecture", systemImage: "clock", description: Text("Les titres ouverts apparaîtront ici.")) }
                ForEach(recent) { book in
                    NavigationLink { BookDetailView(id: book.id) } label: {
                        HStack(spacing: 14) {
                            PageImage(url: store.url(book, file: book.files[0]), pdf: book.isPDF, page: 0, width: 140)
                                .frame(width: 52, height: 75).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(book.title).font(.headline)
                                Text("Page \(book.currentPage + 1) sur \(book.pageCount)").font(.caption).foregroundStyle(.secondary)
                                ProgressView(value: book.progress).tint(.mint)
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }.navigationTitle("Lectures récentes")
        }
    }
}

extension Color {
    static let canvas = Color(red: 0.045, green: 0.065, blue: 0.08)
    static let panel = Color(red: 0.095, green: 0.12, blue: 0.14)
}
