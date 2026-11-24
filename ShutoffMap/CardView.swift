import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct CardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L.t("card.title")).font(.largeTitle.weight(.heavy))
                EmergencyCard(home: model.home, photos: model.photos)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(D.line))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("card.preview")
                Button {
                    model.shareCard(image: CardExport.image(home: model.home, photos: model.photos))
                } label: {
                    Label(L.t("card.send"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("card.send")
                Text(L.t("card.send.note")).font(.footnote).foregroundStyle(D.muted)
                HStack(spacing: 10) {
                    Button(L.t("card.pdf")) {
                        model.exportPDF(CardExport.pdf(home: model.home, photos: model.photos))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("card.pdf")
                    Button(L.t("card.copy-code")) { model.copyCode() }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("card.copy-code")
                }
                Button(L.t("card.paste-code")) {
                    if model.testing, let text = ProcessInfo.processInfo.environment["UITEST_CODE"] {
                        model.previewCode(text)
                    } else {
                        model.previewCode(UIPasteboard.general.string)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("card.paste-code")
            }
            .padding(.horizontal, 18).padding(.bottom, 24)
        }
        .background(D.paper.ignoresSafeArea())
    }
}

struct EmergencyCard: View {
    let home: HomeData
    let photos: PhotoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.t("card.heading")).font(.title2.weight(.heavy))
                Spacer()
                Image(systemName: "house.fill").font(.title2).foregroundStyle(D.color(.water))
            }
            ForEach(SpotKind.big) { kind in
                row(kind)
            }
            ForEach(home.spots.filter { !SpotKind.big.contains($0.kind) && $0.isRecorded }.prefix(3)) { spot in
                HStack {
                    Text(spot.kind == .other && !spot.name.isEmpty ? spot.name : L.t(spot.kind.titleKey))
                        .font(.footnote.weight(.bold))
                    Text(spot.location).font(.footnote).foregroundStyle(D.muted).lineLimit(1)
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("card.hashtags")).font(.footnote.weight(.bold)).foregroundStyle(D.color(.water))
                    Text(L.t("card.footer")).font(.caption).foregroundStyle(D.muted)
                }
                Spacer()
                if let qr = CardExport.qr() {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 72, height: 72)
                }
            }
        }
        .padding(18)
        .frame(width: 360)
        .background(Color.white)
        .foregroundStyle(D.ink)
    }

    @ViewBuilder
    private func row(_ kind: SpotKind) -> some View {
        let spot = home.spot(kind)
        let photo: UIImage? = kind == .power ? photos.image(home.panel.photo) : photos.image(spot?.photos.last)
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    D.color(kind).opacity(0.15)
                    Image(systemName: kind.symbol).font(.title2).foregroundStyle(D.color(kind))
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(L.t(kind.titleKey)).font(.headline).foregroundStyle(D.color(kind))
                Text(place(kind, spot)).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(how(kind, spot)).font(.footnote).foregroundStyle(D.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func place(_ kind: SpotKind, _ spot: Spot?) -> String {
        if kind == .power {
            return home.panel.location.isEmpty ? (home.panel.isRecorded ? L.t("card.see-panel") : L.t("card.missing")) : home.panel.location
        }
        guard let spot, spot.isRecorded else { return L.t("card.missing") }
        return spot.location.isEmpty ? L.t("card.see-photo") : spot.location
    }

    private func how(_ kind: SpotKind, _ spot: Spot?) -> String {
        if kind == .power {
            guard let main = home.panel.main else { return L.t("method.pullMain") }
            return L.f("card.main-breaker", main.id)
        }
        guard let spot, spot.isRecorded else { return "" }
        return spot.method == .custom ? spot.customMethod : L.t(spot.method.key)
    }
}

enum CardExport {
    static var link: String {
        let id = (Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String ?? "").trimmingCharacters(in: .whitespaces)
        return id.isEmpty || id.hasPrefix("$") ? "https://hgsldswk-alt.github.io/shutoffmap-support/" : "https://apps.apple.com/app/id\(id)"
    }

    static func qr() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    @MainActor
    static func image(home: HomeData, photos: PhotoStore) -> UIImage {
        let renderer = ImageRenderer(content: EmergencyCard(home: home, photos: photos))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    static func pdf(home: HomeData, photos: PhotoStore) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let card = image(home: home, photos: photos)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            let scale = min(512 / card.size.width, 692 / card.size.height)
            let size = CGSize(width: card.size.width * scale, height: card.size.height * scale)
            card.draw(in: CGRect(x: (612 - size.width) / 2, y: 50, width: size.width, height: size.height))

            context.beginPage()
            draw(L.t("pdf.panel.title"), at: CGRect(x: 50, y: 40, width: 512, height: 30), size: 20, bold: true)
            if !home.panel.location.isEmpty {
                draw(home.panel.location, at: CGRect(x: 50, y: 68, width: 512, height: 20), size: 11, bold: false)
            }
            let columns = home.panel.columns
            let rows = Int(ceil(Double(home.panel.circuits.count) / Double(columns)))
            let width = 512 / CGFloat(columns)
            let height = min(56, 640 / CGFloat(max(rows, 1)))
            let top: CGFloat = 100
            UIColor.gray.setStroke()
            let border = UIBezierPath(rect: CGRect(x: 46, y: top - 4, width: 520, height: CGFloat(rows) * height + 8))
            border.setLineDash([6, 4], count: 2, phase: 0)
            border.stroke()
            for (offset, circuit) in home.panel.circuits.enumerated() {
                let rect = CGRect(x: 50 + CGFloat(offset % columns) * width, y: top + CGFloat(offset / columns) * height,
                                  width: width, height: height)
                UIColor.black.setStroke()
                UIBezierPath(rect: rect).stroke()
                draw("\(circuit.id)", at: rect.insetBy(dx: 6, dy: 4), size: 9, bold: true)
                var text = circuit.label.isEmpty ? "" : circuit.label
                if circuit.isMain { text += " · " + L.t("panel.main") }
                if circuit.isGFCI { text += " · " + L.t("panel.gfci") }
                draw(text, at: rect.insetBy(dx: 24, dy: 6), size: 12, bold: true)
            }
            draw(L.t("pdf.panel.cut"), at: CGRect(x: 50, y: top + CGFloat(rows) * height + 14, width: 512, height: 18), size: 9, bold: false)
        }
    }

    private static func draw(_ text: String, at rect: CGRect, size: CGFloat, bold: Bool) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
            .foregroundColor: UIColor.black,
            .paragraphStyle: style,
        ])
    }
}

struct ImportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let preview: ImportPreview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let payload = preview.contents.payload
                    ForEach(payload.spots.filter(\.isRecorded)) { spot in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(spot.kind == .other && !spot.name.isEmpty ? spot.name : L.t(spot.kind.titleKey))
                                .font(.headline).foregroundStyle(D.color(spot.kind))
                            Text(spot.location).font(.subheadline)
                        }
                        .cardBox()
                    }
                    if payload.panel.isRecorded {
                        Text(L.f("import.panel", payload.panel.circuits.filter { !$0.label.isEmpty }.count))
                            .cardBox()
                    }
                    Text(preview.fromFile ? L.f("import.photos", preview.contents.photoCount) : L.t("import.text-only"))
                        .font(.footnote).foregroundStyle(D.muted)
                    if model.home.recordedBig > 0 {
                        Text(L.t("import.replace")).font(.footnote.weight(.semibold)).foregroundStyle(D.color(.gas))
                    }
                    Button(L.t("import.save")) { model.accept(preview) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("import.save")
                }
                .padding(18)
            }
            .background(D.paper.ignoresSafeArea())
            .navigationTitle(L.t("import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("common.cancel")) { dismiss() } }
            }
        }
    }
}
