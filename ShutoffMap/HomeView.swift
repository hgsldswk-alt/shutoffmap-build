import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L.t("home.title")).font(.title2.weight(.heavy))
                    Spacer()
                    Button {
                        model.path = [.card]
                    } label: {
                        Label(L.t("home.card"), systemImage: "person.2.fill")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(ChipButtonStyle())
                    .accessibilityIdentifier("home.card")
                }
                ForEach(SpotKind.big) { kind in
                    BigButton(kind: kind)
                }
                SectionLabel("home.others")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(SpotKind.extras) { kind in
                        let spot = model.home.spot(kind)
                        SmallCard(title: L.t(kind.titleKey),
                                  detail: spot?.isRecorded == true ? spot!.location : L.t("home.not-recorded"),
                                  kind: kind) {
                            if let spot, spot.isRecorded { model.path = [.spot(spot.id)] } else { model.editing = spot ?? model.newSpot(kind) }
                        }
                        .accessibilityIdentifier("home.\(kind.rawValue)")
                    }
                    ForEach(model.home.spots.filter { $0.kind == .other }) { spot in
                        SmallCard(title: spot.name.isEmpty ? L.t("kind.other") : spot.name, detail: spot.location, kind: .other) {
                            model.path = [.spot(spot.id)]
                        }
                    }
                    SmallCard(title: "＋", detail: L.t("home.add"), kind: .other) {
                        model.editing = Spot(kind: .other)
                    }
                    .accessibilityIdentifier("home.add")
                }
                progress
            }
            .padding(.horizontal, 18).padding(.bottom, 24)
        }
        .background(D.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.f("home.progress", model.home.recordedBig)).font(.headline)
            Text(L.t(model.home.allThree ? "home.progress.done" : "home.progress.hint"))
                .font(.footnote).foregroundStyle(D.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(D.pale, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.progress")
    }
}

struct BigButton: View {
    @EnvironmentObject private var model: AppModel
    let kind: SpotKind

    private var recorded: Bool { model.home.isRecorded(kind) }

    private var detail: String {
        if kind == .power {
            let panel = model.home.panel
            guard panel.isRecorded else { return L.t("home.power.empty") }
            let place = panel.location.isEmpty ? L.t("kind.power") : panel.location
            return place + " · " + L.f("home.power.labeled", panel.labeledCount)
        }
        guard let spot = model.home.spot(kind), spot.isRecorded else { return L.t("home.empty") }
        return [spot.location, spot.method == .custom ? spot.customMethod : L.t(spot.method.key)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        Button {
            model.open(kind)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(L.t(kind.actionKey), systemImage: kind.symbol)
                        .font(.system(size: 32, weight: .heavy))
                    Spacer()
                    Text(L.t(recorded ? "home.tap.\(kind.rawValue)" : "home.go-record"))
                        .font(.footnote.weight(.semibold))
                        .opacity(0.92)
                }
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .opacity(0.95)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(D.color(kind).opacity(recorded ? 1 : 0.82), in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.\(kind.rawValue)")
    }
}

struct SmallCard: View {
    let title: String
    let detail: String
    let kind: SpotKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(D.ink).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(D.muted).lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
            .background(D.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line))
        }
        .buttonStyle(.plain)
    }
}
