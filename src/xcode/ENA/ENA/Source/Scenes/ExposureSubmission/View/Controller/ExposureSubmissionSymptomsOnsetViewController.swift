//
// 🦠 Corona-Warn-App
//

import UIKit
import Combine

class ExposureSubmissionSymptomsOnsetViewController: DynamicTableViewController, ENANavigationControllerWithFooterChild, DismissHandling {

	// MARK: - Init

	init(
		onPrimaryButtonTap: @escaping (SymptomsOnsetOption) -> Void,
		presentCancelAlert: @escaping () -> Void
	) {
		self.onPrimaryButtonTap = onPrimaryButtonTap
		self.presentCancelAlert = presentCancelAlert
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Overrides

	override func viewDidLoad() {
		super.viewDidLoad()

		setupView()
	}

	override var navigationItem: UINavigationItem {
		navigationFooterItem
	}

	// MARK: - Protocol ENANavigationControllerWithFooterChild

	func navigationController(_ navigationController: ENANavigationControllerWithFooter, didTapPrimaryButton button: UIButton) {
		guard let selectedSymptomsOnsetSelectionOption = selectedSymptomsOnsetOption else {
			fatalError("Primary button must not be enabled before the user has selected an option")
		}

		onPrimaryButtonTap(selectedSymptomsOnsetSelectionOption)
	}
	
	// MARK: - Protocol DismissHandling

	func presentDismiss(dismiss: @escaping () -> Void) {
		presentCancelAlert()
	}
	
	// MARK: - Internal
	
	enum SymptomsOnsetOption {
		case exactDate(Date)
		case lastSevenDays
		case oneToTwoWeeksAgo
		case moreThanTwoWeeksAgo
		case preferNotToSay
	}

	// MARK: - Private

	private let onPrimaryButtonTap: (SymptomsOnsetOption) -> Void
	private let presentCancelAlert: () -> Void
	
	private var symptomsOnsetButtonStateSubscription: AnyCancellable?
	private var optionGroupSelectionSubscription: AnyCancellable?

	@Published private var selectedSymptomsOnsetOption: SymptomsOnsetOption?

	private lazy var navigationFooterItem: ENANavigationFooterItem = {
		let item = ENANavigationFooterItem()
		item.primaryButtonTitle = AppStrings.ExposureSubmissionTestresultAvailable.primaryButtonTitle
		item.isPrimaryButtonEnabled = true
		item.isSecondaryButtonHidden = true
		item.title = AppStrings.ExposureSubmissionTestresultAvailable.title
		return item
	}()

	private var optionGroupSelection: OptionGroupViewModel.Selection? {
		didSet {
			switch optionGroupSelection {
			case .datePickerOption(index: 0, selectedDate: let date):
				selectedSymptomsOnsetOption = .exactDate(date)
			case .option(index: 1):
				selectedSymptomsOnsetOption = .lastSevenDays
			case .option(index: 2):
				selectedSymptomsOnsetOption = .oneToTwoWeeksAgo
			case .option(index: 3):
				selectedSymptomsOnsetOption = .moreThanTwoWeeksAgo
			case .option(index: 4):
				selectedSymptomsOnsetOption = .preferNotToSay
			case .none:
				selectedSymptomsOnsetOption = nil
			default:
				fatalError("This selection has not yet been handled.")
			}
		}
	}

	private func setupView() {
		navigationItem.title = AppStrings.ExposureSubmissionSymptomsOnset.title
		navigationFooterItem?.primaryButtonTitle = AppStrings.ExposureSubmissionSymptomsOnset.continueButton

		setupTableView()

		symptomsOnsetButtonStateSubscription = $selectedSymptomsOnsetOption.receive(on: RunLoop.main).sink {
			self.navigationFooterItem?.isPrimaryButtonEnabled = $0 != nil
		}
	}

	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self

		tableView.register(
			DynamicTableViewOptionGroupCell.self,
			forCellReuseIdentifier: CustomCellReuseIdentifiers.optionGroupCell.rawValue
		)

		dynamicTableViewModel = dynamicTableViewModel()
	}

	private func dynamicTableViewModel() -> DynamicTableViewModel {
		DynamicTableViewModel.with {
			$0.add(
				.section(
					header: .none,
					cells: [
						.headline(
							text: AppStrings.ExposureSubmissionSymptomsOnset.subtitle,
							accessibilityIdentifier: nil
						),
						.body(
							text: AppStrings.ExposureSubmissionSymptomsOnset.description,
							accessibilityIdentifier: nil
						),
						.custom(
							withIdentifier: CustomCellReuseIdentifiers.optionGroupCell,
							configure: { [weak self] _, cell, _ in
								guard let self = self, let cell = cell as? DynamicTableViewOptionGroupCell else { return }

								cell.configure(
									options: [
										.datePickerOption(
											title: AppStrings.ExposureSubmissionSymptomsOnset.datePickerTitle,
											accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptomsOnset.answerOptionExactDate
										),
										.option(
											title: AppStrings.ExposureSubmissionSymptomsOnset.answerOptionLastSevenDays,
											accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptomsOnset.answerOptionLastSevenDays
										),
										.option(
											title: AppStrings.ExposureSubmissionSymptomsOnset.answerOptionOneToTwoWeeksAgo,
											accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptomsOnset.answerOptionOneToTwoWeeksAgo
										),
										.option(
											title: AppStrings.ExposureSubmissionSymptomsOnset.answerOptionMoreThanTwoWeeksAgo,
											accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptomsOnset.answerOptionMoreThanTwoWeeksAgo
										),
										.option(
											title: AppStrings.ExposureSubmissionSymptomsOnset.answerOptionPreferNotToSay,
											accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptomsOnset.answerOptionPreferNotToSay
										)
									],
									// The current selection needs to be provided in case the cell is recreated after leaving and reentering the screen
									initialSelection: self.optionGroupSelection
								)

								self.optionGroupSelectionSubscription = cell.$selection.sink {
									self.optionGroupSelection = $0
								}
							}
						)
					]
				)
			)
		}
	}

}

// MARK: - Cell reuse identifiers.

extension ExposureSubmissionSymptomsOnsetViewController {
	enum CustomCellReuseIdentifiers: String, TableViewCellReuseIdentifiers {
		case optionGroupCell
	}
}
