import Foundation

enum ShareCode {
    static let prefix = "SHUT1:"
    static let maxLength = 60_000

    struct Payload: Codable, Equatable {
        var spots: [Spot]
        var panel: Panel
    }

    static func make(_ home: HomeData) -> String {
        var spots = home.spots.filter(\.isRecorded)
        for i in spots.indices { spots[i].photos = [] }
        var panel = home.panel
        panel.photo = nil
        let data = (try? JSONEncoder().encode(Payload(spots: spots, panel: panel))) ?? Data()
        return prefix + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ text: String) -> Payload? {
        guard text.count <= maxLength + 200, let start = text.range(of: prefix) else { return nil }
        let body = text[start.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        var b64 = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard !body.isEmpty, body.count <= maxLength, let data = Data(base64Encoded: b64),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        return payload.validated()
    }
}

extension ShareCode.Payload {
    func validated() -> Self? {
        guard spots.count <= 40, panel.circuits.count <= Panel.maxCircuits,
              Panel.columnChoices.contains(panel.columns) else { return nil }
        var copy = self
        for i in copy.spots.indices {
            copy.spots[i].id = UUID()
            copy.spots[i].photos = []
            copy.spots[i].location = String(copy.spots[i].location.prefix(300))
            copy.spots[i].name = String(copy.spots[i].name.prefix(60))
            copy.spots[i].route = copy.spots[i].route.prefix(12).map { String($0.prefix(200)) }
            copy.spots[i].customMethod = String(copy.spots[i].customMethod.prefix(200))
            copy.spots[i].caution = String(copy.spots[i].caution.prefix(300))
        }
        copy.panel.photo = nil
        copy.panel.location = String(copy.panel.location.prefix(300))
        for i in copy.panel.circuits.indices {
            copy.panel.circuits[i].id = i + 1
            copy.panel.circuits[i].label = String(copy.panel.circuits[i].label.prefix(40))
        }
        return copy
    }
}

enum HomeCardFile {
    static let version = 1
    static let fileExtension = "homecard"
    static let maxBytes = 30 * 1024 * 1024
    static let maxPhotos = 40
    static let maxPhotoBytes = 2 * 1024 * 1024

    struct Document: Codable {
        var version: Int
        var spots: [Spot]
        var panel: Panel
        var photos: [String: Data]
    }

    struct Contents: Equatable {
        var payload: ShareCode.Payload
        var photos: [String: Data]
        var photoCount: Int { photos.count }
    }

    enum Failure: Error, Equatable { case tooLarge, badFormat, newerVersion }

    static func encode(home: HomeData, photo: (String) -> Data?) throws -> Data {
        let spots = home.spots.filter(\.isRecorded)
        var photos: [String: Data] = [:]
        for name in spots.flatMap(\.photos) + (home.panel.photo.map { [$0] } ?? []) {
            if let data = photo(name) { photos[name] = data }
        }
        return try JSONEncoder().encode(Document(version: version, spots: spots, panel: home.panel, photos: photos))
    }

    static func decode(_ data: Data) throws -> Contents {
        guard data.count <= maxBytes else { throw Failure.tooLarge }
        guard let doc = try? JSONDecoder().decode(Document.self, from: data) else { throw Failure.badFormat }
        guard doc.version <= version else { throw Failure.newerVersion }
        guard doc.version >= 1, doc.photos.count <= maxPhotos,
              doc.photos.values.allSatisfy({ $0.count <= maxPhotoBytes && isJPEG($0) }),
              var payload = ShareCode.Payload(spots: doc.spots, panel: doc.panel).validated() else { throw Failure.badFormat }
        var photos: [String: Data] = [:]
        for i in payload.spots.indices {
            let old = doc.spots[i].photos.prefix(Spot.maxPhotos)
            payload.spots[i].photos = old.compactMap { name in
                guard let data = doc.photos[name] else { return nil }
                let fresh = UUID().uuidString + ".jpg"
                photos[fresh] = data
                return fresh
            }
        }
        if let name = doc.panel.photo, let data = doc.photos[name] {
            let fresh = UUID().uuidString + ".jpg"
            photos[fresh] = data
            payload.panel.photo = fresh
        }
        return Contents(payload: payload, photos: photos)
    }

    static func isJPEG(_ data: Data) -> Bool {
        data.count > 4 && data.prefix(3) == Data([0xFF, 0xD8, 0xFF])
    }
}
