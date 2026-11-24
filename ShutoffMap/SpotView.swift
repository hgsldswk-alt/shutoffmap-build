import SwiftUI

struct SpotView: View {
    @EnvironmentObject private var model: AppModel
    let id: UUID
    @State private var zoom: String?

    var body: some View {
        ScrollView {
            if let spot = model.spot(id) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(spot.kind == .other && !spot.name.isEmpty ? spot.name : L.t(spot.kind.titleKey))
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(D.color(spot.kind))
                        .accessibilityIdentifier("spot.title")
                    if !spot.photos.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(Array(spot.photos.enumerated()), id: \.element) { index, name in
                                Button { zoom = name } label: {
                                    PhotoView(image: model.photos.image(name), placeholder: L.t("photo.\(min(index, 2))"),
                                              height: spot.photos.count == 1 ? 240 : 170)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !spot.location.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel("spot.where")
                            Text(spot.location).font(.title3.weight(.bold))
                        }
                        .cardBox()
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("spot.where")
                    }
                    if !spot.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel("spot.route")
                            ForEach(Array(spot.steps.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)").font(.body)
                            }
                        }
                        .cardBox()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("spot.how")
                        Text(spot.method == .custom ? spot.customMethod : L.t(spot.method.key))
                            .font(.title2.weight(.heavy))
                    }
                    .cardBox(stroke: D.color(spot.kind), width: 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("spot.how")
                    if !spot.caution.isEmpty {
                        Label(spot.caution, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(D.muted)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 24)
            }
        }
        .background(D.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.t("common.edit")) {
                    if let spot = model.spot(id) { model.editing = spot }
                }
                .accessibilityIdentifier("spot.edit")
            }
        }
        .fullScreenCover(item: Binding(get: { zoom.map(ZoomName.init) }, set: { zoom = $0?.id })) { item in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                if let image = model.photos.image(item.id) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button(L.t("common.close")) { zoom = nil }
                    .font(.headline).foregroundStyle(.white).padding(20)
            }
        }
    }
}

private struct ZoomName: Identifiable {
    let id: String
}

struct SpotEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var spot: Spot
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if spot.kind == .other {
                        TextField(L.t("editor.name"), text: $spot.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("editor.name")
                    }
                    SectionLabel("editor.photos")
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(0..<min(spot.photos.count + 1, Spot.maxPhotos), id: \.self) { index in
                            PhotoSlot(title: L.t("photo.\(index)"),
                                      name: index < spot.photos.count ? spot.photos[index] : nil,
                                      identifier: "editor.photo.\(index)",
                                      kind: spot.kind) { name in
                                setPhoto(index, name)
                            }
                        }
                    }
                    SectionLabel("spot.where")
                    TextField(L.t("editor.where.placeholder"), text: $spot.location, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("editor.where")
                    FlowLayout {
                        ForEach(spot.kind.locationTemplates, id: \.self) { key in
                            Button(L.t(key)) { spot.location = L.t(key) }
                                .buttonStyle(ChipButtonStyle(selected: spot.location == L.t(key)))
                                .accessibilityIdentifier("editor.\(key)")
                        }
                    }
                    SectionLabel("spot.route")
                    ForEach(spot.route.indices, id: \.self) { index in
                        TextField(L.f("editor.step", index + 1), text: $spot.route[index])
                            .textFieldStyle(.roundedBorder)
                    }
                    if spot.route.count < 8 {
                        Button(L.t("editor.add-step")) { spot.route.append("") }
                            .buttonStyle(ChipButtonStyle())
                            .accessibilityIdentifier("editor.add-step")
                    }
                    SectionLabel("spot.how")
                    FlowLayout {
                        ForEach(ShutoffMethod.allCases) { method in
                            Button(L.t(method.key + ".short")) { spot.method = method }
                                .buttonStyle(ChipButtonStyle(selected: spot.method == method))
                                .accessibilityIdentifier("editor.method.\(method.rawValue)")
                        }
                    }
                    if spot.method == .custom {
                        TextField(L.t("editor.custom.placeholder"), text: $spot.customMethod)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(L.t(spot.method.key)).font(.footnote).foregroundStyle(D.muted)
                    }
                    SectionLabel("editor.caution")
                    TextField(L.t("editor.caution.placeholder"), text: $spot.caution, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    if model.spot(spot.id) != nil {
                        Button(L.t("editor.delete"), role: .destructive) { confirmDelete = true }
                            .padding(.top, 8)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(D.paper.ignoresSafeArea())
            .navigationTitle(L.t(spot.kind.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("common.done")) { model.save(spot) }
                        .fontWeight(.bold)
                        .accessibilityIdentifier("editor.done")
                }
            }
            .confirmationDialog(L.t("editor.delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L.t("editor.delete"), role: .destructive) { model.delete(spot) }
            }
        }
    }

    private func setPhoto(_ index: Int, _ name: String?) {
        if index < spot.photos.count {
            let old = spot.photos[index]
            if let name { spot.photos[index] = name } else { spot.photos.remove(at: index) }
            if model.spot(spot.id)?.photos.contains(old) != true { model.photos.remove(old) }
        } else if let name {
            spot.photos.append(name)
        }
    }
}
