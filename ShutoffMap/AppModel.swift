import SwiftUI
import UIKit

enum Route: Hashable {
    case spot(UUID)
    case panel
    case card
}

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
    let kind: String
}

struct ImportPreview: Identifiable {
    let id = UUID()
    let contents: HomeCardFile.Contents
    let fromFile: Bool
}

final class PhotoStore {
    let folder: URL

    init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func save(_ image: UIImage) -> String? {
        guard let data = Self.jpeg(image) else { return nil }
        return save(data: data)
    }

    func save(data: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            return name
        } catch { return nil }
    }

    func data(_ name: String) -> Data? {
        guard Self.safe(name) else { return nil }
        return try? Data(contentsOf: folder.appendingPathComponent(name))
    }

    func image(_ name: String?) -> UIImage? {
        guard let name, let data = data(name) else { return nil }
        return UIImage(data: data)
    }

    func remove(_ name: String) {
        guard Self.safe(name) else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }

    func removeAll(except keep: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in files where !keep.contains(file) { remove(file) }
    }

    static func safe(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("..")
    }

    static func jpeg(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > 1600 ? 1600 / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.72, 0.55, 0.4] {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= HomeCardFile.maxPhotoBytes {
                return data
            }
        }
        return nil
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var home = HomeData() { didSet { if home != oldValue { persist() } } }
    @Published var path: [Route] = []
    @Published var editing: Spot?
    @Published var share: ShareItems?
    @Published var importPreview: ImportPreview?
    @Published var showMilestone = false
    @Published var toast: String?
    @Published private(set) var sharedReviewReady = false
    private var savedHome = false

    let testing: Bool
    let photos: PhotoStore
    private let dataURL: URL
    private var toastTask: Task<Void, Never>?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        testing = Launch.has("-ui-testing", in: arguments)
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = testing
            ? base.appendingPathComponent("ui-\(Launch.value("-data-id", in: arguments) ?? "default")", isDirectory: true)
            : base.appendingPathComponent("ShutoffMap", isDirectory: true)
        if testing && Launch.has("-reset", in: arguments) { try? FileManager.default.removeItem(at: folder) }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        dataURL = folder.appendingPathComponent("home.json")
        photos = PhotoStore(folder: folder.appendingPathComponent("photos", isDirectory: true))
        if let data = try? Data(contentsOf: dataURL), let saved = try? JSONDecoder().decode(HomeData.self, from: data) {
            home = saved
        }
        if testing, let fixture = Launch.value("-fixture", in: arguments) {
            home = Fixtures.home(fixture, photos: photos)
        }

    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(home)
            try data.write(to: dataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            savedHome = true
        } catch { savedHome = false }
    }

    func notify(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled { self.toast = nil }
        }
    }


    func open(_ kind: SpotKind) {
        if kind == .power {
            path = [.panel]
            return
        }
        if let spot = home.spot(kind), spot.isRecorded {
            path = [.spot(spot.id)]
        } else {
            editing = home.spot(kind) ?? newSpot(kind)
        }
    }

    func newSpot(_ kind: SpotKind) -> Spot {
        Spot(kind: kind, caution: kind == .gas ? L.t("caution.gas") : "")
    }

    func spot(_ id: UUID) -> Spot? { home.spots.first { $0.id == id } }

    func save(_ spot: Spot) {
        let previous = self.spot(spot.id)
        let wasNew = previous == nil
        let before = home.allThree
        var next = home
        next.upsert(spot)
        let counted = previous != spot && spot.isRecorded && !testing
        if counted { next.coreReviewProgress = .recording(next.coreReviewProgress) }
        home = next
        if counted { registerSavedCoreAction() }
        editing = nil
        if wasNew, path.isEmpty, spot.isRecorded { path = [.spot(spot.id)] }
        checkMilestone(before: before)
    }

    func delete(_ spot: Spot) {
        spot.photos.forEach(photos.remove)
        home.spots.removeAll { $0.id == spot.id }
        editing = nil
        path.removeAll { $0 == .spot(spot.id) }
    }

    func updatePanel(_ change: (inout Panel) -> Void) {
        let before = home.allThree
        var next = home
        change(&next.panel)
        let counted = next.panel != home.panel && !testing
        if counted { next.coreReviewProgress = .recording(next.coreReviewProgress) }
        home = next
        if counted { registerSavedCoreAction() }
        checkMilestone(before: before)
    }

    private func registerSavedCoreAction() {
        guard savedHome else { return }
        CoreReview.shared.record(home.coreReviewProgress)
        if home.review.pending { sharedReviewReady = true }
    }

    private func checkMilestone(before: Bool) {
        if !before, home.allThree, !home.milestones.allThreeShown {
            home.milestones.allThreeShown = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                self.showMilestone = true
            }
        }
    }


    func shareCard(image: UIImage) {
        var items: [Any] = [image]
        if let url = writeHomeCard() { items.append(url) }
        share = ShareItems(items: items, kind: "card")
    }

    func exportPDF(_ data: Data) {
        guard let url = writeTemp(data, name: L.t("file.pdf"), ext: "pdf") else { return notify(L.t("error.export")) }
        share = ShareItems(items: [url], kind: "pdf")
    }

    func copyCode() {
        UIPasteboard.general.string = L.t("code.intro") + "\n" + ShareCode.make(home)
        markShared()
        notify(L.t("code.copied"))
    }

    func shareFinished(completed: Bool) {
        if completed { markShared() }
    }

    func markShared() {
        home.milestones.sharedOnce = true
        home.review.arm(allThree: home.allThree, shared: true)
        sharedReviewReady = home.review.pending
    }

    func requestSharedReview(_ request: () -> Void) {
        var next = home.review
        guard sharedReviewReady, CoreReview.shared.attempt(ifEligible: { next.consumeOnLaunch() }, request) else { return }
        sharedReviewReady = false
        home.review = next
    }

    func writeHomeCard() -> URL? {
        guard let data = try? HomeCardFile.encode(home: home, photo: photos.data) else { return nil }
        return writeTemp(data, name: L.t("file.homecard"), ext: HomeCardFile.fileExtension)
    }

    private func writeTemp(_ data: Data, name: String, ext: String) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name).appendingPathExtension(ext)
            try data.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }


    func openFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= HomeCardFile.maxBytes, let data = try? Data(contentsOf: url) else {
            return notify(L.t("import.too-large"))
        }
        preview(data: data)
    }

    func preview(data: Data) {
        do {
            importPreview = ImportPreview(contents: try HomeCardFile.decode(data), fromFile: true)
        } catch HomeCardFile.Failure.newerVersion {
            notify(L.t("import.newer"))
        } catch HomeCardFile.Failure.tooLarge {
            notify(L.t("import.too-large"))
        } catch {
            notify(L.t("import.invalid"))
        }
    }

    func previewCode(_ text: String?) {
        guard let text, let payload = ShareCode.decode(text) else { return notify(L.t("import.no-code")) }
        importPreview = ImportPreview(contents: .init(payload: payload, photos: [:]), fromFile: false)
    }

    func accept(_ preview: ImportPreview) {
        var saved: [String: String] = [:]
        for (name, data) in preview.contents.photos {
            if let fresh = photos.save(data: data) { saved[name] = fresh }
        }
        var payload = preview.contents.payload
        for i in payload.spots.indices { payload.spots[i].photos = payload.spots[i].photos.compactMap { saved[$0] } }
        payload.panel.photo = payload.panel.photo.flatMap { saved[$0] }
        let old = Set(home.photoNames)
        home.spots = payload.spots
        home.panel = payload.panel
        old.subtracting(home.photoNames).forEach(photos.remove)
        importPreview = nil
        path = []
        notify(L.t("import.saved"))
    }
}
