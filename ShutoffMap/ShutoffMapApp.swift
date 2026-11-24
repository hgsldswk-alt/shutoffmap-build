import StoreKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let homeCard = UTType(exportedAs: "com.hgsldswk.shutoffmap.homecard")
}

@main
struct ShutoffMapApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(D.color(.water))
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var phase

    private var reviewHome: Bool {
        model.path.isEmpty && model.editing == nil && model.share == nil && model.importPreview == nil
            && !model.showMilestone && model.toast == nil && !model.testing
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .spot(let id): SpotView(id: id)
                    case .panel: PanelView()
                    case .card: CardView()
                    }
                }
        }
        .foregroundStyle(D.ink)
        .onOpenURL { url in
            if url.isFileURL { model.openFile(url) }
        }
        .onAppear {
            if model.testing, let text = ProcessInfo.processInfo.environment["UITEST_HOMECARD"],
               let data = Data(base64Encoded: text) {
                model.preview(data: data)
            }
        }
        .reviewAfterCoreAction(when: reviewHome) { requestReview() }
        .task(id: reviewHome && model.sharedReviewReady && phase == .active) {
            guard reviewHome, model.sharedReviewReady, phase == .active else { return }
            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
            guard !Task.isCancelled, reviewHome else { return }
            model.requestSharedReview { requestReview() }
        }
        .sheet(item: $model.editing) { spot in
            SpotEditor(spot: spot)
        }
        .sheet(item: $model.share) { share in
            ActivitySheet(items: share.items) { model.shareFinished(completed: $0) }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $model.importPreview) { preview in
            ImportView(preview: preview)
        }
        .overlay {
            if model.showMilestone {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.35).ignoresSafeArea()
                        .onTapGesture { model.showMilestone = false }
                    MilestoneView()
                        .background(D.card, in: RoundedRectangle(cornerRadius: 26))
                        .padding(12)
                }
                .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let toast = model.toast {
                Text(toast)
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 10).padding(.horizontal, 16)
                    .background(D.ink.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(10)
                    .accessibilityIdentifier("toast")
            }
        }
    }
}

struct MilestoneView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ForEach(SpotKind.big) { kind in
                    Image(systemName: kind.symbol)
                        .font(.title)
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.white)
                        .background(D.color(kind), in: Circle())
                }
            }
            Text(L.t("milestone.title")).font(.title2.bold()).multilineTextAlignment(.center)
            Text(L.t("milestone.body")).foregroundStyle(D.muted).multilineTextAlignment(.center)
            Button(L.t("milestone.send")) {
                model.showMilestone = false
                model.path = [.card]
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("milestone.send")
        }
        .padding(24)
    }
}
