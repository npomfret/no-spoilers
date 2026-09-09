import SwiftUI

/// What the app shows when it could not do something before it had a screen to say it on.
///
/// **Draws nothing on an ordinary run**, which is every run: `LaunchDiagnostics.problems` is empty
/// unless something on the launch path reported a fault, so this costs one array read per body
/// evaluation and no pixels.
///
/// Styled as a warning rather than as a `NoSpoilersCard`. The card chrome is the vocabulary of
/// *schedule content*, and a fault dressed in it reads as another weekend rather than as the app
/// telling you something is wrong.
public struct LaunchProblemBanner: View {
    @ObservedObject private var diagnostics: LaunchDiagnostics
    @State private var showDetail = false

    /// Takes the recorder rather than reaching for the singleton, so a preview or a test can hand
    /// it a populated one — the real fault is, by design, almost impossible to provoke on demand.
    public init(diagnostics: LaunchDiagnostics = .shared) {
        _diagnostics = ObservedObject(wrappedValue: diagnostics)
    }

    @ViewBuilder
    public var body: some View {
        let problems = diagnostics.problems
        if !problems.isEmpty {
            Button {
                showDetail = true
            } label: {
                HStack(alignment: .top, spacing: Theme.Space.lg) {
                    Image(systemName: Theme.Icon.launchProblem)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.attention)
                    VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                        Text(Strings.Diagnostics.bannerTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        ForEach(problems) { problem in
                            Text(problem.summary)
                                .font(.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: Theme.Icon.disclosure)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .multilineTextAlignment(.leading)
                .padding(Theme.Space.xl)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .fill(Theme.Palette.attention.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.Palette.attention.opacity(0.45), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.Diagnostics.bannerTitle)
            .accessibilityHint(Strings.Diagnostics.bannerAction)
            .sheet(isPresented: $showDetail) {
                LaunchProblemDetail(diagnostics: diagnostics, onDone: { showDetail = false })
            }
        }
    }
}

/// The full text of every recorded fault, and the one thing worth doing with it.
///
/// **The share sheet is the point of the whole feature.** A summary on screen tells the user they
/// are not imagining it; it is the shared text that turns "it doesn't work" into a sentence naming
/// a font, a bundle and a CoreText error. `.textSelection` as well, because a share sheet is not
/// reachable from a screenshot and some people will send one of those instead.
struct LaunchProblemDetail: View {
    @ObservedObject var diagnostics: LaunchDiagnostics
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xxl) {
                    Text(Strings.Diagnostics.detailIntro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(report)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Space.xxl)
            }
            .navigationTitle(Strings.Diagnostics.detailTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: report) {
                        Text(Strings.Diagnostics.shareAction)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Actions.done, action: onDone)
                }
            }
        }
    }

    /// Carries the version and build, because the first question about any report is which build
    /// produced it — the same reason `AppLog.launched` writes them at the top of every trace.
    private var report: String {
        diagnostics.report(version: AppVersion.marketing, build: AppVersion.build)
    }
}
