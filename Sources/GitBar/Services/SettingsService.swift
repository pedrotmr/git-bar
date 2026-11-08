import Foundation
import Observation

@Observable
class SettingsService {
    static let legacyBundleIdentifier = "pedrotmr.GitBar"
    static let legacyMigrationCompleteKey = "didMigrateLegacyPreferences"

    private enum Keys {
        static let repoPaths = "repoPaths_v2"
        static let selectedRepoPath = "selectedRepoPath_v2"
        static let preferredTerminal = "preferredTerminal"
        static let preferredEditor = "preferredEditor"
        static let autoFetchEnabled = "autoFetchEnabled"
        static let confirmBranchDeletion = "confirmBranchDeletion"
        static let tabOrder = "tabOrder"

        static var persisted: [String] {
            [
                repoPaths,
                selectedRepoPath,
                preferredTerminal,
                preferredEditor,
                autoFetchEnabled,
                confirmBranchDeletion,
                tabOrder,
            ] + AppTab.allCases.map(\.visibilityDefaultsKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var repoPaths: [String]
    var selectedRepoPath: String?
    var preferredTerminal: SupportedTerminal {
        didSet { defaults.set(preferredTerminal.rawValue, forKey: Keys.preferredTerminal) }
    }
    var preferredEditor: SupportedEditor {
        didSet { defaults.set(preferredEditor.rawValue, forKey: Keys.preferredEditor) }
    }
    private(set) var tabVisibility: [AppTab: Bool]
    var autoFetchEnabled: Bool {
        didSet { defaults.set(autoFetchEnabled, forKey: Keys.autoFetchEnabled) }
    }
    var confirmBranchDeletion: Bool {
        didSet { defaults.set(confirmBranchDeletion, forKey: Keys.confirmBranchDeletion) }
    }
    var tabOrder: [AppTab] {
        didSet { defaults.set(tabOrder.map(\.rawValue), forKey: Keys.tabOrder) }
    }

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: SettingsService.legacyBundleIdentifier)
    ) {
        self.defaults = defaults
        Self.migrateLegacyPreferences(from: legacyDefaults, to: defaults)

        repoPaths = defaults.stringArray(forKey: Keys.repoPaths) ?? []
        selectedRepoPath = defaults.string(forKey: Keys.selectedRepoPath)
        preferredTerminal = SupportedTerminal(
            rawValue: defaults.string(forKey: Keys.preferredTerminal) ?? ""
        ) ?? .terminal
        preferredEditor = SupportedEditor(
            rawValue: defaults.string(forKey: Keys.preferredEditor) ?? ""
        ) ?? .vscode
        tabVisibility = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { tab in
            (
                tab,
                defaults.object(forKey: tab.visibilityDefaultsKey) as? Bool ?? tab.isVisibleByDefault
            )
        })
        autoFetchEnabled = defaults.bool(forKey: Keys.autoFetchEnabled)
        confirmBranchDeletion = defaults.object(forKey: Keys.confirmBranchDeletion) as? Bool ?? true

        let saved = (defaults.stringArray(forKey: Keys.tabOrder) ?? []).compactMap(AppTab.init(rawValue:))
        let missing = AppTab.defaultOrder.filter { !saved.contains($0) }
        tabOrder = saved.isEmpty ? AppTab.defaultOrder : saved + missing
    }

    static func migrateLegacyPreferences(from legacy: UserDefaults?, to current: UserDefaults) {
        guard !current.bool(forKey: legacyMigrationCompleteKey) else { return }
        if let legacy {
            for key in Keys.persisted where current.object(forKey: key) == nil {
                if let value = legacy.object(forKey: key) {
                    current.set(value, forKey: key)
                }
            }
        }
        current.set(true, forKey: legacyMigrationCompleteKey)
    }

    func isTabVisible(_ tab: AppTab) -> Bool {
        tabVisibility[tab] ?? tab.isVisibleByDefault
    }

    func setTabVisible(_ isVisible: Bool, for tab: AppTab) {
        guard tabVisibility[tab] != isVisible else { return }
        tabVisibility[tab] = isVisible
        defaults.set(isVisible, forKey: tab.visibilityDefaultsKey)
    }

    func addRepo(_ path: String) {
        if !repoPaths.contains(path) {
            repoPaths.append(path)
            defaults.set(repoPaths, forKey: Keys.repoPaths)
        }
        selectedRepoPath = path
        defaults.set(path, forKey: Keys.selectedRepoPath)
    }

    func removeRepo(_ path: String) {
        repoPaths.removeAll { $0 == path }
        defaults.set(repoPaths, forKey: Keys.repoPaths)
        if selectedRepoPath == path {
            selectedRepoPath = repoPaths.first
            defaults.set(selectedRepoPath, forKey: Keys.selectedRepoPath)
        }
    }

    func moveRepo(fromOffsets source: IndexSet, toOffset destination: Int) {
        repoPaths = Self.moving(repoPaths, from: source, to: destination)
        defaults.set(repoPaths, forKey: Keys.repoPaths)
    }

    func moveTab(from source: AppTab, onto target: AppTab) {
        guard source != target,
              let fromIndex = tabOrder.firstIndex(of: source),
              let toIndex = tabOrder.firstIndex(of: target)
        else { return }
        tabOrder = Self.moving(
            tabOrder,
            from: IndexSet(integer: fromIndex),
            to: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
    }

    func selectRepo(_ path: String) {
        selectedRepoPath = path
        defaults.set(path, forKey: Keys.selectedRepoPath)
    }

    private static func moving<Element>(_ values: [Element], from offsets: IndexSet, to destination: Int) -> [Element] {
        let elements = offsets.sorted().map { values[$0] }
        var result = values
        for index in offsets.sorted(by: >) {
            result.remove(at: index)
        }
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        result.insert(contentsOf: elements, at: adjustedDestination)
        return result
    }
}
