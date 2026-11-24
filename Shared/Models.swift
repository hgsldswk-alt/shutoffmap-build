import Foundation

enum Launch {
    static func has(_ flag: String, in args: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        args.contains(flag)
    }

    static func value(_ flag: String, in args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

enum SpotKind: String, Codable, CaseIterable, Identifiable {
    case water, power, gas, heater, zone, other

    var id: String { rawValue }
    static let big: [SpotKind] = [.water, .power, .gas]
    static let extras: [SpotKind] = [.heater, .zone]

    var titleKey: String { "kind.\(rawValue)" }
    var actionKey: String { "kind.\(rawValue).action" }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .power: "bolt.fill"
        case .gas: "flame.fill"
        case .heater: "thermometer.medium"
        case .zone: "drop.circle.fill"
        case .other: "mappin.circle.fill"
        }
    }

    var defaultMethod: ShutoffMethod {
        switch self {
        case .power: .pullMain
        case .gas: .leverCross
        default: .clockwise
        }
    }

    var locationTemplates: [String] {
        switch self {
        case .water, .zone: ["place.stairs", "place.sink", "place.garage", "place.meter", "place.laundry", "place.basement"]
        case .power: ["place.garage", "place.hall", "place.basement", "place.closet", "place.outside"]
        case .gas: ["place.kitchen", "place.outside", "place.meter", "place.balcony"]
        case .heater: ["place.balcony", "place.garage", "place.closet", "place.basement"]
        case .other: ["place.hall", "place.closet", "place.outside"]
        }
    }
}

enum ShutoffMethod: String, Codable, CaseIterable, Identifiable {
    case clockwise, quarterTurn, leverCross, pullMain, custom

    var id: String { rawValue }
    var key: String { "method.\(rawValue)" }
}

struct Spot: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: SpotKind
    var name = ""
    var location = ""
    var route: [String] = []
    var method: ShutoffMethod
    var customMethod = ""
    var caution = ""
    var photos: [String] = []

    init(kind: SpotKind, name: String = "", caution: String = "") {
        self.kind = kind
        self.name = name
        self.method = kind.defaultMethod
        self.caution = caution
    }

    var isRecorded: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }

    var steps: [String] {
        route.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static let maxPhotos = 3
}

struct Circuit: Codable, Equatable, Identifiable {
    var id: Int
    var label = ""
    var template: String?
    var isMain = false
    var isGFCI = false
}

struct CircuitTemplate: Equatable {
    let key: String
    let group: String

    static let all: [CircuitTemplate] = [
        .init(key: "room.main", group: "group.main"),
        .init(key: "room.kitchen-outlets", group: "group.kitchen"),
        .init(key: "room.kitchen-lights", group: "group.kitchen"),
        .init(key: "room.fridge", group: "group.kitchen"),
        .init(key: "room.dishwasher", group: "group.kitchen"),
        .init(key: "room.microwave", group: "group.kitchen"),
        .init(key: "room.oven", group: "group.kitchen"),
        .init(key: "room.ac", group: "group.climate"),
        .init(key: "room.heating", group: "group.climate"),
        .init(key: "room.water-heater", group: "group.bath"),
        .init(key: "room.bathroom", group: "group.bath"),
        .init(key: "room.washer", group: "group.laundry"),
        .init(key: "room.dryer", group: "group.laundry"),
        .init(key: "room.living-lights", group: "group.living"),
        .init(key: "room.living-outlets", group: "group.living"),
        .init(key: "room.master-lights", group: "group.bedroom"),
        .init(key: "room.master-outlets", group: "group.bedroom"),
        .init(key: "room.bedroom2", group: "group.bedroom"),
        .init(key: "room.office", group: "group.office"),
        .init(key: "room.garage", group: "group.outside"),
        .init(key: "room.outdoor", group: "group.outside"),
        .init(key: "room.porch", group: "group.outside"),
    ]

    static func find(_ key: String?) -> CircuitTemplate? { all.first { $0.key == key } }
}

struct Panel: Codable, Equatable {
    var location = ""
    var photo: String?
    var columns = 2
    var circuits: [Circuit] = (1...20).map { Circuit(id: $0) }

    static let columnChoices = [1, 2, 3, 4]
    static let maxCircuits = 60

    var isRecorded: Bool {
        photo != nil || circuits.contains { !$0.label.isEmpty }
    }

    var labeledCount: Int { circuits.filter { !$0.label.isEmpty }.count }
    var main: Circuit? { circuits.first { $0.isMain } }

    mutating func resize(to count: Int) {
        let target = min(max(count, 1), Panel.maxCircuits)
        if circuits.count > target {
            circuits.removeLast(circuits.count - target)
        } else {
            circuits += (circuits.count + 1...target).map { Circuit(id: $0) }
        }
    }

    func matches(_ query: String, translate: (String) -> String = L.t) -> Set<Int> {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        var hits = Set<Int>()
        for circuit in circuits where !circuit.label.isEmpty {
            if circuit.label.range(of: q, options: options) != nil {
                hits.insert(circuit.id)
            } else if let template = CircuitTemplate.find(circuit.template),
                      translate(template.group).range(of: q, options: options) != nil {
                hits.insert(circuit.id)
            } else if q.range(of: circuit.label, options: options) != nil, circuit.label.count >= 2 {
                hits.insert(circuit.id)
            }
        }
        return hits
    }
}

struct Milestones: Codable, Equatable {
    var allThreeShown = false
    var sharedOnce = false
}

struct ReviewGate: Codable, Equatable {
    private(set) var requested = false
    private(set) var pending = false

    mutating func arm(allThree: Bool, shared: Bool) {
        if allThree && shared && !requested { pending = true }
    }

    mutating func consumeOnLaunch() -> Bool {
        guard pending, !requested else { return false }
        pending = false
        requested = true
        return true
    }
}

struct HomeData: Codable, Equatable {
    var coreReviewProgress: CoreReviewProgress?
    var spots: [Spot] = []
    var panel = Panel()
    var milestones = Milestones()
    var review = ReviewGate()

    func spot(_ kind: SpotKind) -> Spot? { spots.first { $0.kind == kind } }

    func isRecorded(_ kind: SpotKind) -> Bool {
        kind == .power ? panel.isRecorded : (spot(kind)?.isRecorded ?? false)
    }

    var recordedBig: Int { SpotKind.big.filter(isRecorded).count }
    var allThree: Bool { recordedBig == SpotKind.big.count }

    var extras: [Spot] { spots.filter { $0.kind != .water && $0.kind != .gas && $0.isRecorded } }

    var photoNames: [String] {
        spots.flatMap(\.photos) + (panel.photo.map { [$0] } ?? [])
    }

    mutating func upsert(_ spot: Spot) {
        if let i = spots.firstIndex(where: { $0.id == spot.id }) {
            spots[i] = spot
        } else {
            spots.append(spot)
        }
    }
}
