import SwiftUI
import UIKit
import ImageIO

struct PageImage: View {
    let url: URL
    let pdf: Bool
    let page: Int
    let width: CGFloat
    @State private var image: UIImage?
    @State private var finished = false
    private var key: String { "\(url.path)|\(page)|\(Int(width))" }
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if finished { Label("Page illisible", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary) }
            else { ProgressView().tint(.mint) }
        }
        .task(id: key) {
            image = nil; finished = false
            let file = url, isPDF = pdf, number = page, size = width
            let result = await Task.detached(priority: .userInitiated) {
                PageCache.shared.image(url: file, pdf: isPDF, page: number, width: size)
            }.value
            guard !Task.isCancelled else { return }
            image = result; finished = true
        }
    }
}

struct ReaderView: View {
    let id: UUID
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readingMode") private var mode = "paged"
    @AppStorage("rightToLeft") private var rightToLeft = true
    @State private var page = 0
    @State private var verticalPage: Int?
    @State private var controls = true
    @State private var initialized = false

    var body: some View {
        Group {
            if let book = store.book(id) {
                GeometryReader { geometry in
                    let width = min(1600, max(600, geometry.size.width * UIScreen.main.scale))
                    ZStack {
                        Color.black.ignoresSafeArea()
                        if mode == "vertical" {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(spacing: 4) {
                                        ForEach(0..<book.pageCount, id: \.self) { number in
                                            pageView(book, number: number, width: width)
                                                .frame(minHeight: 150).frame(maxWidth: .infinity).id(number)
                                        }
                                    }.scrollTargetLayout()
                                }
                                .scrollPosition(id: $verticalPage, anchor: .top)
                                .onAppear { proxy.scrollTo(page, anchor: .top) }
                                .onChange(of: verticalPage) { _, value in
                                    if let value { page = value }
                                }
                            }
                        } else {
                            TabView(selection: $page) {
                                ForEach(rightToLeft ? Array((0..<book.pageCount).reversed()) : Array(0..<book.pageCount), id: \.self) { number in
                                    ZoomPage {
                                        pageView(book, number: number, width: width)
                                    }.tag(number)
                                }
                            }.tabViewStyle(.page(indexDisplayMode: .never))
                        }
                        if controls {
                            VStack {
                                HStack {
                                    Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).padding(12) }
                                        .accessibilityLabel("Fermer le lecteur")
                                    Text(book.title).font(.subheadline.bold()).lineLimit(1)
                                    Spacer()
                                    Button {
                                        store.update(id) { $0.bookmark = $0.bookmark == page ? nil : page }
                                    } label: { Image(systemName: book.bookmark == page ? "bookmark.fill" : "bookmark").padding(12) }
                                        .accessibilityLabel("Marquer cette page")
                                    Menu {
                                        Picker("Mode", selection: $mode) {
                                            Text("Page par page").tag("paged")
                                            Text("Vertical / webtoon").tag("vertical")
                                        }
                                        Toggle("Droite vers gauche", isOn: $rightToLeft)
                                        if let bookmark = book.bookmark {
                                            Button("Aller au marque-page") { page = bookmark; verticalPage = bookmark }
                                        }
                                    } label: { Image(systemName: "slider.horizontal.3").padding(12) }
                                        .accessibilityLabel("Réglages du lecteur")
                                }.padding(.horizontal, 8).background(.ultraThinMaterial)
                                Spacer()
                                HStack {
                                    Button { navigate(-1, count: book.pageCount) } label: { Image(systemName: "chevron.left").padding(14) }
                                        .disabled(page == 0).accessibilityLabel("Page précédente")
                                    Spacer()
                                    Text("\(page + 1) / \(book.pageCount)").font(.subheadline.monospacedDigit())
                                    Spacer()
                                    Button { navigate(1, count: book.pageCount) } label: { Image(systemName: "chevron.right").padding(14) }
                                        .disabled(page >= book.pageCount - 1).accessibilityLabel("Page suivante")
                                }.padding(.horizontal, 16).background(.ultraThinMaterial)
                            }
                        }
                        if !controls {
                            VStack { HStack { Spacer(); Button { controls = true } label: {
                                Image(systemName: "ellipsis").padding(12).background(.ultraThinMaterial, in: Circle())
                            }.accessibilityLabel("Afficher les commandes").padding() }; Spacer() }
                        }
                    }.foregroundStyle(.white)
                    .onAppear {
                        guard !initialized else { return }
                        page = min(book.currentPage, max(0, book.pageCount - 1))
                        verticalPage = page
                        initialized = true
                        store.record(id, page: page)
                    }
                    .onChange(of: page) { _, value in if initialized { store.record(id, page: value) } }
                    .onChange(of: mode) { _, _ in verticalPage = page }
                }
            } else { Button("Fermer") { dismiss() } }
        }.preferredColorScheme(.dark)
    }
    private func navigate(_ delta: Int, count: Int) {
        page = min(max(0, page + delta), count - 1)
        verticalPage = page
    }
    private func pageView(_ book: Book, number: Int, width: CGFloat) -> some View {
        PageImage(url: store.url(book, file: book.isPDF ? book.files[0] : book.files[number]),
                  pdf: book.isPDF, page: book.isPDF ? number : 0, width: width)
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { controls.toggle() } }
    }
}

struct ZoomPage<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero
    var body: some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale * magnification)
            .offset(x: offset.width + drag.width, y: offset.height + drag.height)
            .gesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
                .onEnded { value in scale = min(4, max(1, scale * value)); if scale == 1 { offset = .zero } })
            .simultaneousGesture(DragGesture().updating($drag) { value, state, _ in
                if scale > 1 { state = value.translation }
            }.onEnded { value in
                if scale > 1 { offset.width += value.translation.width; offset.height += value.translation.height }
            }, including: scale > 1 ? .all : .none)
            .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2; offset = .zero } }
            .clipped()
    }
}
