import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import ImageIO
import UIKit

struct Book: Identifiable, Codable {
    var id = UUID()
    var title: String
    var files: [String]
    var isPDF: Bool
    var pageCount: Int
    var currentPage = 0
    var category = "Non classé"
    var favorite = false
    var bookmark: Int?
    var lastRead: Date?
    var addedAt = Date()
    var progress: Double { Double(currentPage + 1) / Double(max(1, pageCount)) }
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published var error: String?
    @Published private(set) var importing = false
    private let root: URL
    private var index: URL { root.appendingPathComponent("library.json") }

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: index.path) {
                books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: index))
            }
        } catch { self.error = "Impossible de charger la bibliothèque : \(error.localizedDescription)" }
    }

    func book(_ id: UUID) -> Book? { books.first { $0.id == id } }
    func url(_ book: Book, file: String) -> URL {
        root.appendingPathComponent(book.id.uuidString, isDirectory: true).appendingPathComponent(file)
    }
    func update(_ id: UUID, _ change: (inout Book) -> Void) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        change(&books[i]); save()
    }
    func record(_ id: UUID, page: Int) {
        update(id) { book in
            book.currentPage = min(max(0, page), max(0, book.pageCount - 1))
            book.lastRead = Date()
        }
    }
    func delete(_ id: UUID) {
        do {
            let directory = root.appendingPathComponent(id.uuidString)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            books.removeAll { $0.id == id }; save()
        } catch { self.error = "Suppression impossible : \(error.localizedDescription)" }
    }
    private func save() {
        do { try JSONEncoder().encode(books).write(to: index, options: .atomic) }
        catch { self.error = "Sauvegarde impossible : \(error.localizedDescription)" }
    }

    /// PDFs become individual books; selected images become one naturally sorted book.
    /// Copying runs off the main thread, with scoped access only for the duration of each copy.
    func importFiles(_ urls: [URL]) async {
        guard !importing else { return }
        importing = true
        defer { importing = false }
        let root = self.root
        let result = await Task.detached(priority: .userInitiated) { () -> ([Book], [String]) in
            var imported: [Book] = []
            var failures: [String] = []
            var images: [URL] = []
            for url in urls {
                if url.pathExtension.lowercased() == "pdf" {
                    let bookID = UUID()
                    let folder = root.appendingPathComponent(bookID.uuidString, isDirectory: true)
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let target = folder.appendingPathComponent("document.pdf")
                        try FileManager.default.copyItem(at: url, to: target)
                        guard let pdf = PDFDocument(url: target), !pdf.isLocked, pdf.pageCount > 0 else {
                            throw ImportFailure.invalidPDF
                        }
                        imported.append(Book(id: bookID, title: url.deletingPathExtension().lastPathComponent,
                                             files: ["document.pdf"], isPDF: true, pageCount: pdf.pageCount))
                    } catch {
                        try? FileManager.default.removeItem(at: folder)
                        failures.append("\(url.lastPathComponent) : \(error.localizedDescription)")
                    }
                } else { images.append(url) }
            }
            if !images.isEmpty {
                let bookID = UUID()
                let folder = root.appendingPathComponent(bookID.uuidString, isDirectory: true)
                var files: [String] = []
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    for (i, url) in images.sorted(by: {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                    }).enumerated() {
                        let granted = url.startAccessingSecurityScopedResource()
                        defer { if granted { url.stopAccessingSecurityScopedResource() } }
                        do {
                            let name = String(format: "%05d", i) + "." + url.pathExtension
                            let destination = folder.appendingPathComponent(name)
                            try FileManager.default.copyItem(at: url, to: destination)
                            guard UIImage(contentsOfFile: destination.path) != nil else {
                                try? FileManager.default.removeItem(at: destination)
                                throw ImportFailure.invalidImage
                            }
                            files.append(name)
                        } catch { failures.append("\(url.lastPathComponent) : \(error.localizedDescription)") }
                    }
                    if files.isEmpty { try? FileManager.default.removeItem(at: folder) }
                    else {
                        imported.append(Book(id: bookID, title: images[0].deletingPathExtension().lastPathComponent,
                                             files: files, isPDF: false, pageCount: files.count))
                    }
                } catch { failures.append(error.localizedDescription) }
            }
            return (imported, failures)
        }.value
        books.insert(contentsOf: result.0, at: 0)
        save()
        if !result.1.isEmpty { error = result.1.joined(separator: "\n") }
    }
}

enum ImportFailure: LocalizedError {
    case invalidPDF, invalidImage
    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "PDF vide, protégé ou illisible."
        case .invalidImage: return "Image non prise en charge."
        }
    }
}

/// A bounded thumbnail cache; books and full-size pages stay on disk.
final class PageCache: @unchecked Sendable {
    static let shared = PageCache()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.totalCostLimit = 48 * 1024 * 1024 }
    func image(url: URL, pdf: Bool, page: Int, width: CGFloat) -> UIImage? {
        let key = "\(url.path)-\(page)-\(Int(width))" as NSString
        if let image = cache.object(forKey: key) { return image }
        let image: UIImage?
        if pdf {
            guard let document = PDFDocument(url: url), let sheet = document.page(at: page) else { return nil }
            let bounds = sheet.bounds(for: .mediaBox)
            let height = width * bounds.height / max(1, bounds.width)
            image = sheet.thumbnail(of: CGSize(width: width, height: min(height, 4096)), for: .mediaBox)
        } else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(width * 2),
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
        }
        if let image {
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        }
        return image
    }
}
