import ExposureNotification
import MessageUI
import UIKit

protocol SettingsViewControllerDelegate: AnyObject {
	typealias Completion = (ExposureNotificationError?) -> Void

	func settingsViewController(
		_ controller: SettingsViewController,
		setExposureManagerEnabled enabled: Bool,
		then completion: @escaping Completion
	)

	func settingsViewControllerUserDidRequestReset(
		_ controller: SettingsViewController
	)
}

final class SettingsViewController: UITableViewController {
	private weak var notificationSettingsController: ExposureNotificationSettingViewController?
	private weak var delegate: SettingsViewControllerDelegate?

	let store: Store
	let appConfigurationProvider: AppConfigurationProviding

	let tracingSegue = "showTracing"
	let notificationsSegue = "showNotifications"
	let resetSegue = "showReset"
	let backgroundAppRefreshSegue = "showBackgroundAppRefresh"

	let settingsViewModel = SettingsViewModel()
	var enState: ENStateHandler.State

	init?(
		coder: NSCoder,
		store: Store,
		initialEnState: ENStateHandler.State,
		appConfigurationProvider: AppConfigurationProviding,
		delegate: SettingsViewControllerDelegate
	) {
		self.store = store
		self.delegate = delegate
		self.enState = initialEnState
		self.appConfigurationProvider = appConfigurationProvider
		super.init(coder: coder)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.separatorColor = .enaColor(for: .hairline)

		navigationItem.title = AppStrings.Settings.navigationBarTitle

		setupView()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		checkTracingStatus()
		checkNotificationSettings()
		checkBackgroundAppRefresh()
	}

	override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
		if segue.identifier == resetSegue, let nc = segue.destination as? UINavigationController, let vc = nc.topViewController as? ResetViewController {
			vc.delegate = self
		}
	}

	@IBSegueAction
	func createExposureNotificationSettingViewController(coder: NSCoder) -> ExposureNotificationSettingViewController? {
		let vc = ExposureNotificationSettingViewController(
			coder: coder,
			initialEnState: enState,
			store: store,
			appConfigurationProvider: appConfigurationProvider,
			delegate: self
		)
		notificationSettingsController = vc
		return vc
	}

	@IBSegueAction
	func createNotificationSettingsViewController(coder: NSCoder) -> NotificationSettingsViewController? {
		NotificationSettingsViewController(coder: coder, store: store)
	}
	
	@IBSegueAction
	func createBackgroundAppRefreshViewController(coder: NSCoder) -> BackgroundAppRefreshViewController? {
		BackgroundAppRefreshViewController(coder: coder)
	}

	@objc
	private func willEnterForeground() {
		checkTracingStatus()
		checkNotificationSettings()
		checkBackgroundAppRefresh()
	}

	private func setupView() {

		checkTracingStatus()
		checkNotificationSettings()
		checkBackgroundAppRefresh()

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(willEnterForeground),
			name: UIApplication.willEnterForegroundNotification,
			object: UIApplication.shared
		)
	}

	private func checkTracingStatus() {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }

			self.settingsViewModel.tracing.state = self.enState == .enabled
					? self.settingsViewModel.tracing.stateActive
					: self.settingsViewModel.tracing.stateInactive

			self.tableView.reloadData()
		}
	}

	private func checkNotificationSettings() {
		let currentCenter = UNUserNotificationCenter.current()

		currentCenter.getNotificationSettings { [weak self] settings in
			guard let self = self else { return }

			if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
				&& (self.store.allowRiskChangesNotification || self.store.allowTestsStatusNotification) {
				self.settingsViewModel.notifications.setState(state: true)
			} else {
				self.settingsViewModel.notifications.setState(state: false)
			}

			DispatchQueue.main.async {
				self.tableView.reloadData()
			}
		}
	}
	
	private func checkBackgroundAppRefresh() {
		self.settingsViewModel.backgroundAppRefresh.setState(
			state: UIApplication.shared.backgroundRefreshStatus == .available
		)
	}

	private func setExposureManagerEnabled(_ enabled: Bool, then: @escaping SettingsViewControllerDelegate.Completion) {
		delegate?.settingsViewController(self, setExposureManagerEnabled: enabled, then: then)
	}
}

// MARK: UITableViewDataSource, UITableViewDelegate

extension SettingsViewController {
	override func numberOfSections(in _: UITableView) -> Int {
		Sections.allCases.count
	}

	override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		switch Sections.allCases[section] {
		case .tracing: return 32
		case .reset: return 48
		default: return UITableView.automaticDimension
		}
	}

	override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
		let section = Sections.allCases[section]

		switch section {
		case .tracing:
			return AppStrings.Settings.tracingDescription
		case .notifications:
			return AppStrings.Settings.notificationDescription
		case .reset:
			return AppStrings.Settings.resetDescription
		case .backgroundAppRefresh:
			return AppStrings.Settings.backgroundAppRefreshDescription
		}
	}

	override func tableView(_: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
		guard let footerView = view as? UITableViewHeaderFooterView else { return }

		let section = Sections.allCases[section]

		switch section {
		case .reset:
			footerView.textLabel?.textAlignment = .center
		case .tracing, .notifications, .backgroundAppRefresh:
			footerView.textLabel?.textAlignment = .left
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = Sections.allCases[indexPath.section]

		let cell: UITableViewCell

		switch section {
		case .tracing:
			cell = configureMainCell(indexPath: indexPath, model: settingsViewModel.tracing)
		case .notifications:
			cell = configureMainCell(indexPath: indexPath, model: settingsViewModel.notifications)
		case .backgroundAppRefresh:
			cell = configureMainCell(indexPath: indexPath, model: settingsViewModel.backgroundAppRefresh)
		case .reset:
			guard let labelCell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.reset.rawValue, for: indexPath) as? LabelTableViewCell else {
				fatalError("No cell for reuse identifier.")
			}

			labelCell.titleLabel.text = settingsViewModel.reset

			cell = labelCell
			cell.accessibilityIdentifier = AccessibilityIdentifiers.Settings.resetLabel
		}

		cell.isAccessibilityElement = true
		cell.accessibilityTraits = .button

		return cell
	}

	func configureMainCell(indexPath: IndexPath, model: SettingsViewModel.CellModel) -> MainSettingsTableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.main.rawValue, for: indexPath) as? MainSettingsTableViewCell else {
			fatalError("No cell for reuse identifier.")
		}

		cell.configure(model: model)

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let section = Sections.allCases[indexPath.section]

		switch section {
		case .tracing:
			performSegue(withIdentifier: tracingSegue, sender: nil)
		case .notifications:
			performSegue(withIdentifier: notificationsSegue, sender: nil)
		case .reset:
			performSegue(withIdentifier: resetSegue, sender: nil)
		case .backgroundAppRefresh:
			performSegue(withIdentifier: backgroundAppRefreshSegue, sender: nil)
		}

		tableView.deselectRow(at: indexPath, animated: false)
	}
}

private extension SettingsViewController {
	enum Sections: CaseIterable {
		case tracing
		case notifications
		case backgroundAppRefresh
		case reset
	}

	enum ReuseIdentifier: String {
		case main = "mainSettings"
		case reset = "resetSettings"
	}
}

extension SettingsViewController: ResetDelegate {
	func reset() {
		delegate?.settingsViewControllerUserDidRequestReset(self)
	}
}

extension SettingsViewController: ExposureNotificationSettingViewControllerDelegate {
	func exposureNotificationSettingViewController(_: ExposureNotificationSettingViewController, setExposureManagerEnabled enabled: Bool, then completion: @escaping (ExposureNotificationError?) -> Void) {
		setExposureManagerEnabled(enabled, then: completion)
	}
}

extension SettingsViewController: ExposureStateUpdating {
	func updateExposureState(_ state: ExposureManagerState) {
		checkTracingStatus()
	}
}

extension SettingsViewController: ENStateHandlerUpdating {
	func updateEnState(_ state: ENStateHandler.State) {
		enState = state
		checkTracingStatus()
		notificationSettingsController?.updateEnState(state)
	}
}

extension SettingsViewController: NavigationBarOpacityDelegate {
	var preferredLargeTitleBackgroundColor: UIColor? { .enaColor(for: .background) }
}
