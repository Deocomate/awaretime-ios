import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws AwareTime's blocking screen (spec §2.4 / §3.3).
///
/// Everything shown here is prepared by `ShieldController.escalateToShield`
/// and stored in the App Group, so the screen — including the maths question,
/// when enabled — is already final by the time iOS asks for it.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(subject: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(subject: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(subject: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(subject: webDomain.domain ?? category.localizedDisplayName)
    }

    // MARK: - Shared builder

    private func makeConfiguration(subject: String?) -> ShieldConfiguration {
        let presentation = SharedStore.shieldPresentation
        let accent: UIColor = presentation.snoozeQuotaReached ? .awareAlert : .awareCalm

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(brand: BrandPalette.ink, alpha: 0.82),
            icon: UIImage(named: "ShieldIcon"),
            title: ShieldConfiguration.Label(
                text: title(for: presentation, subject: subject),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: presentation.subtitle,
                color: UIColor.white.withAlphaComponent(0.85)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: presentation.primaryButtonTitle,
                color: .white
            ),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: presentation.secondaryButtonTitle.map {
                ShieldConfiguration.Label(text: $0, color: UIColor.white.withAlphaComponent(0.9))
            }
        )
    }

    private func title(for presentation: ShieldPresentation, subject: String?) -> String {
        guard let subject, !subject.isEmpty else { return presentation.title }
        return "\(subject) · \(presentation.title)"
    }
}
