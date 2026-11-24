import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var labeling: Int?
    @State private var setup = false

    private var panel: Panel { model.home.panel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("kind.power")).font(.largeTitle.weight(.heavy)).foregroundStyle(D.color(.power))
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(D.muted)
                    TextField(L.t("panel.search"), text: $query)
                        .submitLabel(.search)
                        .accessibilityIdentifier("panel.search")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(D.muted) }
                    }
                }
                .padding(12)
                .background(D.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(D.line))
                if !panel.isRecorded {
                    Text(L.t("panel.empty")).font(.subheadline).foregroundStyle(D.muted)
                }
                PhotoSlot(title: panel.location.isEmpty ? L.t("panel.photo") : panel.location,
                          name: panel.photo, identifier: "panel.photo.0", kind: .power) { name in
                    let old = panel.photo
                    model.updatePanel { $0.photo = name }
                    if let old, old != name { model.photos.remove(old) }
                }
                let hits = panel.matches(query)
                if !query.isEmpty {
                    Text(hits.isEmpty ? L.t("panel.no-hit")
                         : L.f("panel.hits", hits.count, hits.sorted().map(String.init).joined(separator: "、")))
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("panel.hits")
                }
                VStack(spacing: 8) {
                    ForEach(Array(stride(from: 0, to: panel.circuits.count, by: panel.columns)), id: \.self) { start in
                        HStack(spacing: 8) {
                            ForEach(start..<start + panel.columns, id: \.self) { index in
                                if index < panel.circuits.count {
                                    let circuit = panel.circuits[index]
                                    CircuitCell(circuit: circuit, hit: hits.contains(circuit.id)) { labeling = circuit.id }
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 58)
                                }
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button(L.t("panel.setup")) { setup = true }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("panel.setup")
                    Button(L.t("panel.print")) { model.path = [.card] }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Text(L.t("panel.tip")).font(.footnote).foregroundStyle(D.muted)
            }
            .padding(.horizontal, 18).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(D.paper.ignoresSafeArea())
        .onAppear {
            if model.testing, let q = Launch.value("-search") { query = q }
        }
        .sheet(item: Binding(get: { labeling.map(CircuitID.init) }, set: { labeling = $0?.id })) { item in
            LabelSheet(start: item.id)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $setup) {
            PanelSetup().presentationDetents([.medium])
        }
    }
}

private struct CircuitID: Identifiable { let id: Int }

struct CircuitCell: View {
    let circuit: Circuit
    let hit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(circuit.id)").font(.caption2.weight(.bold)).foregroundStyle(D.muted)
                Text(circuit.label.isEmpty ? "—" : circuit.label)
                    .font(.footnote.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                if circuit.isMain || circuit.isGFCI {
                    Text(L.t(circuit.isMain ? "panel.main" : "panel.gfci"))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(D.color(.gas))
                }
            }
            .foregroundStyle(D.ink)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(4)
            .background(hit ? D.highlight : D.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(hit ? D.color(.power) : D.line, lineWidth: hit ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("panel.cell.\(circuit.id)")
        .accessibilityValue(hit ? "hit" : "")
    }
}

struct LabelSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var custom = ""

    init(start: Int) { _index = State(initialValue: start) }

    private var circuit: Circuit? { model.home.panel.circuits.first { $0.id == index } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let circuit {
                        Text(circuit.label.isEmpty ? L.t("panel.unlabeled") : circuit.label)
                            .font(.title3.weight(.bold))
                    }
                    FlowLayout {
                        ForEach(CircuitTemplate.all, id: \.key) { template in
                            Button(L.t(template.key)) { assign(L.t(template.key), template: template.key) }
                                .buttonStyle(ChipButtonStyle(selected: circuit?.template == template.key))
                                .accessibilityIdentifier("label.\(template.key)")
                        }
                    }
                    HStack {
                        TextField(L.t("label.custom"), text: $custom)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { if !custom.isEmpty { assign(custom, template: nil) } }
                        Button(L.t("label.use")) { assign(custom, template: nil) }
                            .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Toggle(L.t("panel.main"), isOn: flag(\.isMain))
                    Toggle(L.t("panel.gfci"), isOn: flag(\.isGFCI))
                    Button(L.t("label.clear"), role: .destructive) { assign("", template: nil) }
                }
                .padding(18)
            }
            .navigationTitle(L.f("label.title", index))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("common.done")) { dismiss() }.accessibilityIdentifier("label.done")
                }
            }
        }
    }

    private func assign(_ label: String, template: String?) {
        let text = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        model.updatePanel { panel in
            guard let i = panel.circuits.firstIndex(where: { $0.id == index }) else { return }
            panel.circuits[i].label = text
            panel.circuits[i].template = template
            if template == "room.main" { panel.circuits[i].isMain = true }
        }
        custom = ""
        if index < model.home.panel.circuits.count, !text.isEmpty {
            index += 1
        } else {
            dismiss()
        }
    }

    private func flag(_ path: WritableKeyPath<Circuit, Bool>) -> Binding<Bool> {
        Binding(get: { circuit?[keyPath: path] ?? false }, set: { value in
            model.updatePanel { panel in
                if let i = panel.circuits.firstIndex(where: { $0.id == index }) { panel.circuits[i][keyPath: path] = value }
            }
        })
    }
}

struct PanelSetup: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField(L.t("panel.location"), text: Binding(get: { model.home.panel.location },
                                                                set: { value in model.updatePanel { $0.location = value } }))
                    .accessibilityIdentifier("setup.location")
                Picker(L.t("panel.columns"), selection: Binding(get: { model.home.panel.columns },
                                                                 set: { value in model.updatePanel { $0.columns = value } })) {
                    ForEach(Panel.columnChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper(L.f("panel.count", model.home.panel.circuits.count),
                        value: Binding(get: { model.home.panel.circuits.count },
                                       set: { value in model.updatePanel { $0.resize(to: value) } }),
                        in: 1...Panel.maxCircuits, step: 2)
            }
            .navigationTitle(L.t("panel.setup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.t("common.done")) { dismiss() } }
            }
        }
    }
}
