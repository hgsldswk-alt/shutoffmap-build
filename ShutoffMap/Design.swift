import PhotosUI
import SwiftUI
import UIKit

enum D {
    static let paper = Color(red: 0.965, green: 0.973, blue: 0.980)
    static let card = Color.white
    static let ink = Color(red: 0.078, green: 0.125, blue: 0.169)
    static let muted = Color(red: 0.365, green: 0.420, blue: 0.471)
    static let line = Color(red: 0.851, green: 0.878, blue: 0.902)
    static let pale = Color(red: 0.902, green: 0.933, blue: 0.965)
    static let highlight = Color(red: 1.0, green: 0.886, blue: 0.416)

    static func color(_ kind: SpotKind) -> Color {
        switch kind {
        case .water, .zone: Color(red: 0.122, green: 0.455, blue: 0.788)
        case .power: Color(red: 0.760, green: 0.455, blue: 0.0)
        case .gas: Color(red: 0.784, green: 0.271, blue: 0.227)
        case .heater: Color(red: 0.55, green: 0.33, blue: 0.70)
        case .other: Color(red: 0.30, green: 0.42, blue: 0.40)
        }
    }

    static func uiColor(_ kind: SpotKind) -> UIColor { UIColor(color(kind)) }
}

struct CardBox: ViewModifier {
    var stroke: Color = D.line
    var width: CGFloat = 1
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(D.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(stroke, lineWidth: width))
    }
}

extension View {
    func cardBox(stroke: Color = D.line, width: CGFloat = 1) -> some View { modifier(CardBox(stroke: stroke, width: width)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = D.color(.water)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(D.ink)
            .background(D.pale.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ChipButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8).padding(.horizontal, 12)
            .foregroundStyle(selected ? .white : D.ink)
            .background(selected ? D.color(.water) : D.pale, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ key: String) { text = L.t(key) }
    var body: some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(D.muted)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

struct PhotoView: View {
    let image: UIImage?
    let placeholder: String
    var height: CGFloat = 170

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                D.pale
                Image(systemName: "camera.fill").font(.title).foregroundStyle(D.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(placeholder)
                .font(.caption.weight(.semibold))
                .foregroundStyle(image == nil ? D.muted : .white)
                .shadow(color: image == nil ? .clear : .black.opacity(0.6), radius: 3)
                .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    let done: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in done(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void

    static var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = Self.hasCamera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

struct PhotoSlot: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let name: String?
    let identifier: String
    var kind: SpotKind = .water
    let picked: (String?) -> Void
    @State private var camera = false
    @State private var library: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if model.testing {
                    picked(Fixtures.photo(kind, identifier.hasSuffix("0") ? 0 : 1, model.photos))
                } else {
                    camera = true
                }
            } label: {
                PhotoView(image: model.photos.image(name), placeholder: title, height: 130)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
            HStack(spacing: 12) {
                PhotosPicker(selection: $library, matching: .images) {
                    if name == nil {
                        Label(L.t("photo.library"), systemImage: "photo").font(.caption.weight(.semibold)).lineLimit(1)
                    } else {
                        Image(systemName: "photo").font(.subheadline.weight(.semibold))
                            .accessibilityLabel(L.t("photo.library"))
                    }
                }
                if name != nil {
                    Spacer(minLength: 0)
                    Button(role: .destructive) { picked(nil) } label: {
                        Image(systemName: "trash").font(.subheadline.weight(.semibold))
                            .accessibilityLabel(L.t("photo.remove"))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { image in
                camera = false
                if let image { picked(model.photos.save(image)) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: library) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    picked(model.photos.save(image))
                }
                library = nil
            }
        }
    }
}
