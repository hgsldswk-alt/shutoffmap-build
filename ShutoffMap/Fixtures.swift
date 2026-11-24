import UIKit

enum Fixtures {
    static func home(_ name: String, photos: PhotoStore) -> HomeData {
        var home = HomeData()
        guard name != "empty" else { return home }
        var water = Spot(kind: .water)
        water.location = L.t("fixture.water.location")
        water.route = [L.t("fixture.water.step1"), L.t("fixture.water.step2"), L.t("fixture.water.step3")]
        water.caution = L.t("fixture.water.caution")
        water.photos = [photo(.water, 0, photos), photo(.water, 1, photos)].compactMap { $0 }
        home.spots.append(water)

        home.panel.location = L.t("fixture.panel.location")
        home.panel.photo = photo(.power, 0, photos)
        home.panel.resize(to: 16)
        let labels = ["room.main", "room.kitchen-outlets", "room.master-lights", "room.ac",
                      "room.water-heater", "room.bathroom", "room.living-lights", "room.washer",
                      "room.bedroom2", "room.fridge", "room.office", "room.porch",
                      "room.dishwasher", "room.garage", "room.living-outlets", "room.outdoor"]
        for (i, key) in labels.enumerated() {
            home.panel.circuits[i].label = L.t(key)
            home.panel.circuits[i].template = key
        }
        home.panel.circuits[0].isMain = true
        home.panel.circuits[5].isGFCI = true

        if name == "full" {
            var gas = Spot(kind: .gas, caution: L.t("caution.gas"))
            gas.location = L.t("fixture.gas.location")
            gas.route = [L.t("fixture.gas.step1")]
            gas.photos = [photo(.gas, 0, photos), photo(.gas, 1, photos)].compactMap { $0 }
            home.spots.append(gas)
            var heater = Spot(kind: .heater)
            heater.location = L.t("fixture.heater.location")
            home.spots.append(heater)
            var zone = Spot(kind: .zone)
            zone.location = L.t("fixture.zone.location")
            home.spots.append(zone)
            home.milestones.allThreeShown = true
        }
        return home
    }

    static func photo(_ kind: SpotKind, _ index: Int, _ store: PhotoStore) -> String? {
        store.save(draw(kind, index))
    }

    static func draw(_ kind: SpotKind, _ index: Int) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let wall = index == 0 ? UIColor(red: 0.80, green: 0.78, blue: 0.73, alpha: 1) : UIColor(red: 0.70, green: 0.72, blue: 0.74, alpha: 1)
            wall.setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0, alpha: 0.08).setFill()
            cg.fill(CGRect(x: 0, y: 960, width: 900, height: 240))
            switch (kind, index) {
            case (.water, 0), (.zone, 0):
                UIColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 250, y: 260, width: 400, height: 700), cornerRadius: 10).fill()
                UIColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1).setStroke()
                let door = UIBezierPath(roundedRect: CGRect(x: 250, y: 260, width: 400, height: 700), cornerRadius: 10)
                door.lineWidth = 14
                door.stroke()
                UIColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 590, y: 600, width: 30, height: 30)).fill()
                stairs(cg)
            case (.water, _), (.zone, _), (.heater, _):
                pipe(cg, color: UIColor(red: 0.72, green: 0.45, blue: 0.25, alpha: 1), vertical: false)
                UIColor(red: 0.80, green: 0.12, blue: 0.12, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 300, y: 330, width: 300, height: 300)).fill()
                UIColor(white: 1, alpha: 0.55).setStroke()
                let spoke = UIBezierPath()
                spoke.lineWidth = 22
                spoke.move(to: CGPoint(x: 450, y: 350)); spoke.addLine(to: CGPoint(x: 450, y: 610))
                spoke.move(to: CGPoint(x: 320, y: 480)); spoke.addLine(to: CGPoint(x: 580, y: 480))
                spoke.stroke()
                UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 405, y: 600, width: 90, height: 120), cornerRadius: 8).fill()
            case (.power, _):
                UIColor(red: 0.62, green: 0.65, blue: 0.68, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 180, y: 150, width: 540, height: 860), cornerRadius: 16).fill()
                UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 360, y: 190, width: 180, height: 90), cornerRadius: 8).fill()
                for row in 0..<8 {
                    for col in 0..<2 {
                        UIColor(white: 0.93, alpha: 1).setFill()
                        UIBezierPath(roundedRect: CGRect(x: 230 + col * 230, y: 320 + row * 82, width: 200, height: 60), cornerRadius: 6).fill()
                        UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1).setFill()
                        UIBezierPath(roundedRect: CGRect(x: 300 + col * 230, y: 332 + row * 82, width: 60, height: 36), cornerRadius: 4).fill()
                    }
                }
            case (.gas, 0):
                UIColor(red: 0.93, green: 0.92, blue: 0.88, alpha: 1).setFill()
                cg.fill(CGRect(x: 120, y: 560, width: 660, height: 400))
                UIColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1).setFill()
                cg.fill(CGRect(x: 120, y: 540, width: 660, height: 30))
                pipe(cg, color: UIColor(red: 0.90, green: 0.72, blue: 0.10, alpha: 1), vertical: true)
            default:
                pipe(cg, color: UIColor(red: 0.90, green: 0.72, blue: 0.10, alpha: 1), vertical: true)
                UIColor(red: 0.85, green: 0.15, blue: 0.12, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 450, y: 440, width: 300, height: 70), cornerRadius: 30).fill()
                UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 405, y: 430, width: 90, height: 90)).fill()
            }
        }
    }

    private static func pipe(_ cg: CGContext, color: UIColor, vertical: Bool) {
        color.setFill()
        if vertical {
            cg.fill(CGRect(x: 410, y: 0, width: 80, height: 1200))
        } else {
            cg.fill(CGRect(x: 0, y: 690, width: 900, height: 80))
        }
        color.withAlphaComponent(0.6).setFill()
        if vertical {
            cg.fill(CGRect(x: 395, y: 300, width: 110, height: 40))
            cg.fill(CGRect(x: 395, y: 800, width: 110, height: 40))
        } else {
            cg.fill(CGRect(x: 150, y: 675, width: 40, height: 110))
            cg.fill(CGRect(x: 710, y: 675, width: 40, height: 110))
        }
    }

    private static func stairs(_ cg: CGContext) {
        UIColor(red: 0.50, green: 0.40, blue: 0.30, alpha: 1).setFill()
        for step in 0..<6 {
            cg.fill(CGRect(x: 660 + step * 40, y: 960 - step * 120, width: 240 - step * 40, height: 24))
        }
    }
}
