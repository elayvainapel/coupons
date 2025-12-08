import Combine
import SwiftUI
import UniformTypeIdentifiers
import StoreKit

struct ProPaywallView: View {
    @Binding var isPresented: Bool
    var onUpgrade: () -> Void
    @EnvironmentObject private var viewModel: DiscountViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding()

                Text("Unlock Pro Features")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Upgrade to Pro to enjoy:")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                        Text("More than 6 coupons")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Manage multiple smart lists")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Customize categories and types")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Access all app features")
                    }
                }
                .font(.title3)
                .padding(.horizontal)

                Button {
                    // Temporary immediate unlock for development
                    viewModel.isProUnlocked = true
                    onUpgrade()
                    isPresented = false
                } label: {
                    Text("Upgrade to Pro")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.black)
                        .cornerRadius(16)
                        .padding(.horizontal)
                }
// Removed the "Restore Purchases" Button here as per instructions
                
                if let message = viewModel.purchaseMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Pro Upgrade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

extension Image {
    static func systemSymbolPreferringFill(_ baseName: String) -> Image {
        #if canImport(UIKit)
        let filled = baseName + ".fill"
        if UIImage(systemName: filled) != nil {
            return Image(systemName: filled)
        }
        #endif
        return Image(systemName: baseName)
    }
}

// MARK: - Lists support

struct ListInfo: Identifiable, Codable, Equatable {
    enum BuiltIn: String, Codable, CaseIterable { case coupons, giftCards, discounts }
    let id: UUID
    var name: String
    var colorHex: String // store color as hex for persistence
    var iconName: String // SF Symbol name
    var isDefault: Bool

    var isSmart: Bool = false
    var smartMatchAll: Bool = true
    var smartConditions: [SmartCondition] = []

    init(id: UUID = UUID(), name: String, color: Color, iconName: String, isDefault: Bool = false, isSmart: Bool = false, smartMatchAll: Bool = true, smartConditions: [SmartCondition] = []) {
        self.id = id
        self.name = name
        self.colorHex = color.toHexString()
        self.iconName = iconName
        self.isDefault = isDefault
        self.isSmart = isSmart
        self.smartMatchAll = smartMatchAll
        self.smartConditions = smartConditions
    }

    var color: Color { Color.fromHexString(colorHex) ?? .blue }

    enum ConditionKey: String, Codable, CaseIterable {
        case type
        case amount
        case hasMoney
        case expirationDate
        case hasDescription
        case hasExpirationDate
        case list
    }

    struct SmartCondition: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var key: ConditionKey
        // For keys that require a value
        var stringValue: String? = nil
        var doubleValue: Double? = nil
        var comparison: Comparison = .equals

        enum Comparison: String, Codable, CaseIterable { case equals, notEquals, greaterThan, lessThan, greaterOrEqual, lessOrEqual }
    }

    func matches(discount: Discount, listName: String) -> Bool {
        guard isSmart else { return true }
        let evals: [Bool] = smartConditions.map { cond in
            switch cond.key {
            case .type:
                let v = (discount.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let target = (cond.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return cond.comparison == .equals ? v.caseInsensitiveCompare(target) == .orderedSame : v.caseInsensitiveCompare(target) != .orderedSame
            case .amount:
                let amt = discount.amountLeft ?? 0
                let target = cond.doubleValue ?? 0
                switch cond.comparison {
                case .equals: return amt == target
                case .notEquals: return amt != target
                case .greaterThan: return amt > target
                case .lessThan: return amt < target
                case .greaterOrEqual: return amt >= target
                case .lessOrEqual: return amt <= target
                }
            case .hasMoney:
                let has = (discount.amountLeft ?? 0) > 0
                return cond.comparison == .equals ? has : !has
            case .expirationDate:
                guard let d = discount.expirationDate, let target = cond.doubleValue else { return false }
                let t = Date(timeIntervalSince1970: target)
                switch cond.comparison {
                case .equals: return Calendar.current.isDate(d, inSameDayAs: t)
                case .notEquals: return !Calendar.current.isDate(d, inSameDayAs: t)
                case .greaterThan: return d > t
                case .lessThan: return d < t
                case .greaterOrEqual: return d >= t
                case .lessOrEqual: return d <= t
                }
            case .hasDescription:
                let has = !(discount.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                return cond.comparison == .equals ? has : !has
            case .hasExpirationDate:
                let has = discount.expirationDate != nil
                return cond.comparison == .equals ? has : !has
            case .list:
                // Match by list name string value
                let target = (cond.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return cond.comparison == .equals ? listName.caseInsensitiveCompare(target) == .orderedSame : listName.caseInsensitiveCompare(target) != .orderedSame
            }
        }
        return smartMatchAll ? evals.allSatisfy { $0 } : evals.contains(true)
    }
}

final class ListsViewModel: ObservableObject {
    static let recentlyDeletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    @Published var lists: [ListInfo] = [] { didSet { save() } }
    @Published var selectedListID: UUID? { didSet { saveSelected() } }
    @Published var showingListsSheet: Bool = false

    var recentlyDeletedList: ListInfo {
        ListInfo(
            id: Self.recentlyDeletedID,
            name: "Recently Deleted",
            color: .gray,
            iconName: "trash",
            isDefault: true,
            isSmart: false
        )
    }

    private let listsKey = "lists.info"
    private let selectedKey = "lists.selected"

    init() {
        load()
        if lists.isEmpty {
            // Defaults: Coupons (blue), Gift Cards (green), Discounts (red)
            let defaults: [ListInfo] = [
                ListInfo(name: "Coupons", color: .blue,  iconName: "tag", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Coupons", comparison: .equals)]),
                ListInfo(name: "Gift Cards", color: .green, iconName: "gift", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Gift Cards", comparison: .equals)]),
                ListInfo(name: "Discounts", color: .red, iconName: "bag", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Discounts", comparison: .equals)])
            ]
            lists = defaults
            selectedListID = defaults.first?.id
        }
        if selectedListID == nil {
            selectedListID = lists.first?.id ?? Self.recentlyDeletedID
        }
    }

    var selectedList: ListInfo? {
        if let sel = selectedListID, sel == Self.recentlyDeletedID {
            return recentlyDeletedList
        }
        return lists.first { $0.id == selectedListID }
    }

    func addList(name: String, color: Color, icon: String) {
        let info = ListInfo(name: name, color: color, iconName: icon, isDefault: false)
        lists.append(info)
    }

    func updateList(_ list: ListInfo) {
        if let idx = lists.firstIndex(where: { $0.id == list.id }) { lists[idx] = list }
    }

    func delete(at offsets: IndexSet) {
        let filtered = offsets.filter { lists[$0].id != Self.recentlyDeletedID }
        let idsToDelete = filtered.map { lists[$0].id }
        lists.remove(atOffsets: IndexSet(filtered))
        if let sel = selectedListID, idsToDelete.contains(sel) {
            selectedListID = lists.first?.id ?? Self.recentlyDeletedID
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: listsKey),
           let decoded = try? JSONDecoder().decode([ListInfo].self, from: data) {
            lists = decoded
        }
        if let sid = UserDefaults.standard.string(forKey: selectedKey), let uuid = UUID(uuidString: sid) {
            selectedListID = uuid
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: listsKey)
        }
    }

    private func saveSelected() {
        if let id = selectedListID { UserDefaults.standard.set(id.uuidString, forKey: selectedKey) }
    }
}

// MARK: - Color <-> Hex helpers
extension Color {
    func toHexString() -> String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
        #else
        return "#000000"
        #endif
    }

    static func fromHexString(_ hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}


struct Discount: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var number: String
    var amountLeft: Double?
    var currency: String
    var descriptionText: String? = nil
    var createdAt: Date
    var expirationDate: Date? = nil
    var category: String? = nil
    var type: String? = nil
}

struct DeletedDiscount: Identifiable, Codable, Equatable {
    let id: UUID
    var original: Discount
    var deletedAt: Date
}

struct CurrencyInfo: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let symbol: String
    let name: String
}

final class DiscountViewModel: ObservableObject {
    @Published var purchaseMessage: String? = nil

    @Published var discounts: [Discount] = [] {
        didSet { saveDiscounts() }
    }
    
    @Published var recentlyDeleted: [DeletedDiscount] = [] { didSet { saveRecentlyDeleted() } }
    
    @Published var defaultCurrency: String = "USD" {
        didSet { saveCurrency() }
    }
    
    @Published var editingDiscount: Discount? = nil
    
    @Published var categories: [String] = [] {
        didSet { saveCategories() }
    }
    @Published var showCategoriesSettings: Bool = false
    
    @Published var types: [String] = [] { didSet { saveTypes() } }
    @Published var showTypesSettings: Bool = false

    @Published var isProUnlocked: Bool = true { didSet { savePro() } }

    let currencies: [CurrencyInfo] = [
        CurrencyInfo(code: "USD", symbol: "$",  name: "US Dollar"),
        CurrencyInfo(code: "EUR", symbol: "€",  name: "Euro"),
        CurrencyInfo(code: "GBP", symbol: "£",  name: "British Pound"),
        CurrencyInfo(code: "JPY", symbol: "¥",  name: "Japanese Yen"),
        CurrencyInfo(code: "CAD", symbol: "C$", name: "Canadian Dollar"),
        CurrencyInfo(code: "AUD", symbol: "A$", name: "Australian Dollar"),
        CurrencyInfo(code: "CHF", symbol: "CHF", name: "Swiss Franc"),
        CurrencyInfo(code: "CNY", symbol: "¥",  name: "Chinese Yuan"),
        CurrencyInfo(code: "INR", symbol: "₹",  name: "Indian Rupee"),
        CurrencyInfo(code: "ILS", symbol: "₪",  name: "Israeli Shekel")
    ]

    // Appearance settings
    @Published var followSystemAppearance: Bool = true { didSet { saveAppearanceSettings() } }
    @Published var forceDarkMode: Bool = false { didSet { saveAppearanceSettings() } }

    private let discountsKey = "discounts"
    private let currencyKey = "defaultCurrency"
    private let categoriesKey = "categories"
    private let typesKey = "types"
    private let recentlyDeletedKey = "recentlyDeleted"
    private let proKey = "pro.unlocked"
    
    private let followSystemKey = "appearance.followSystem"
    private let forceDarkKey = "appearance.forceDark"

    // iCloud KVS store
    private let kvs = NSUbiquitousKeyValueStore.default

    private var cancellables: Set<AnyCancellable> = []

    // MARK: - StoreKit (Pro Purchase)
    private let proProductID = "pro.unlock"
    @MainActor private var proProduct: Product? = nil

    @MainActor func loadProducts() async {
        do {
            let products = try await Product.products(for: [proProductID])
            self.proProduct = products.first
        } catch {
            self.purchaseMessage = "Failed to load products. Please try again later."
        }
    }

    @MainActor func purchasePro() async {
        if proProduct == nil { await loadProducts() }
        guard let product = proProduct else {
            self.purchaseMessage = "Product unavailable."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .unverified:
                    self.purchaseMessage = "Purchase could not be verified."
                case .verified(let transaction):
                    // Unlock and finish
                    self.isProUnlocked = true
                    await transaction.finish()
                    self.purchaseMessage = nil
                }
            case .userCancelled:
                self.purchaseMessage = "Purchase cancelled."
            case .pending:
                self.purchaseMessage = "Purchase pending approval."
            @unknown default:
                self.purchaseMessage = "Unknown purchase result."
            }
        } catch {
            self.purchaseMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    @MainActor func restorePurchases() async {
        do {
            try await AppStore.sync()
            // Check current entitlements for our product
            for await result in Transaction.currentEntitlements {
                if case .verified(let t) = result, t.productID == proProductID {
                    self.isProUnlocked = true
                    self.purchaseMessage = "Purchases restored."
                    return
                }
            }
            self.purchaseMessage = "No purchases to restore."
        } catch {
            self.purchaseMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    // Current list context; when changed, reload data for that list
    @Published var currentListID: UUID? {
        didSet {
            if oldValue != currentListID {
                loadAllForCurrentList()
            }
        }
    }

    private func key(_ base: String) -> String {
        guard let id = currentListID?.uuidString else { return base }
        return base + "." + id
    }
    
    init() {
        loadPro()
        // Defer loading until a list is assigned
        // Observe iCloud changes
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.handleKVSChange(notification: notification)
        }

        // Keep KVS active
        kvs.synchronize()

        // Load global types once on init
        loadTypes()

        loadAppearanceSettings()
        
        loadRecentlyDeleted()
        purgeExpiredDeleted()

        // Also observe app becoming active to refresh
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.kvs.synchronize()
            self?.pullFromCloud()
            self?.purgeExpiredDeleted()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func currencySymbol(for code: String) -> String {
        currencies.first(where: { $0.code == code })?.symbol ?? code
    }
    
    var totalsByCurrency: [(code: String, total: Double)] {
        var dict: [String: Double] = [:]
        for d in discounts {
            let c = d.currency
            dict[c, default: 0] += (d.amountLeft ?? 0)
        }
        return dict.map { ($0.key, $0.value) }
            .sorted { $0.code < $1.code }
    }
    
    // MARK: - Cross-list aggregation helpers
    /// Count discounts belonging to a specific list id
    func countForList(_ listID: UUID) -> Int {
        return loadDiscounts(for: listID).count
    }

    /// Load discounts for a specific list id without mutating current state
    func loadDiscounts(for listID: UUID) -> [Discount] {
        let baseKey = discountsKey
        let scopedKey = baseKey + "." + listID.uuidString
        if let data = UserDefaults.standard.data(forKey: scopedKey),
           let decoded = try? JSONDecoder().decode([Discount].self, from: data) {
            return decoded
        }
        return []
    }

    /// Aggregate discounts across all given list ids
    func aggregatedDiscounts(for listIDs: [UUID]) -> [Discount] {
        var all: [Discount] = []
        for id in listIDs {
            let items = loadDiscounts(for: id)
            all.append(contentsOf: items)
        }
        return all
    }
    
    // MARK: - Cross-list write helpers
    /// Save a provided discounts array for a specific list id
    private func saveDiscounts(_ items: [Discount], for listID: UUID) {
        let baseKey = discountsKey
        let scopedKey = baseKey + "." + listID.uuidString
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: scopedKey)
            kvs.set(data, forKey: scopedKey)
            kvs.synchronize()
        }
    }

    /// Update an existing discount in a specific list by id
    func updateDiscount(_ discount: Discount, in listID: UUID) {
        var items = loadDiscounts(for: listID)
        if let idx = items.firstIndex(where: { $0.id == discount.id }) {
            items[idx] = discount
            saveDiscounts(items, for: listID)
            // If this list is the current one, also reflect in-memory state
            if currentListID == listID {
                self.discounts = items
            }
        }
    }

    /// Delete a discount from a specific list by id (and add to recentlyDeleted)
    func delete(_ discount: Discount, in listID: UUID) {
        var items = loadDiscounts(for: listID)
        if let idx = items.firstIndex(where: { $0.id == discount.id }) {
            let removed = items.remove(at: idx)
            saveDiscounts(items, for: listID)
            if currentListID == listID {
                self.discounts = items
            }
            if !recentlyDeleted.contains(where: { $0.original.id == removed.id }) {
                recentlyDeleted.insert(DeletedDiscount(id: removed.id, original: removed, deletedAt: Date()), at: 0)
            }
        }
    }

    /// Use amount against a discount in a specific list
    func useAmount(_ amount: Double, for discount: Discount, in listID: UUID) {
        guard amount > 0 else { return }
        var items = loadDiscounts(for: listID)
        if let idx = items.firstIndex(where: { $0.id == discount.id }) {
            var existing = items[idx]
            let current = existing.amountLeft ?? 0
            existing.amountLeft = max(0, current - amount)
            items[idx] = existing
            saveDiscounts(items, for: listID)
            if currentListID == listID { self.discounts = items }
        }
    }

    /// Add a discount directly into a specific list
    func addDiscount(_ discount: Discount, to listID: UUID) {
        var items = loadDiscounts(for: listID)
        items.append(discount)
        saveDiscounts(items, for: listID)
        if currentListID == listID { self.discounts = items }
    }

    /// Move (or copy) a discount id between lists (remove from source, add to dest)
    func moveDiscount(_ discount: Discount, from sourceListID: UUID, to destListID: UUID) {
        if sourceListID == destListID {
            updateDiscount(discount, in: sourceListID)
            return
        }
        // Remove from source
        var sourceItems = loadDiscounts(for: sourceListID)
        sourceItems.removeAll { $0.id == discount.id }
        saveDiscounts(sourceItems, for: sourceListID)
        if currentListID == sourceListID { self.discounts = sourceItems }
        // Add/update in destination
        var destItems = loadDiscounts(for: destListID)
        if let idx = destItems.firstIndex(where: { $0.id == discount.id }) {
            destItems[idx] = discount
        } else {
            destItems.append(discount)
        }
        saveDiscounts(destItems, for: destListID)
        if currentListID == destListID { self.discounts = destItems }
    }
    
    // MARK: - CRUD
    
    func addDiscount(name: String, number: String, amountLeft: Double?, currency: String, descriptionText: String?, expirationDate: Date?, category: String?, type: String?) {
        if !isProUnlocked && discounts.count >= 6 {
            // Do not add, limit reached
            return
        }
        let new = Discount(
            id: UUID(),
            name: name,
            number: number,
            amountLeft: amountLeft,
            currency: currency,
            descriptionText: descriptionText,
            createdAt: Date(),
            expirationDate: expirationDate,
            category: category,
            type: type
        )
        discounts.append(new)
    }
    
    func updateDiscount(_ discount: Discount) {
        if let index = discounts.firstIndex(where: { $0.id == discount.id }) {
            discounts[index] = discount
        }
    }
    
    func delete(at offsets: IndexSet) {
        let items = offsets.map { discounts[$0] }
        discounts.remove(atOffsets: offsets)
        for d in items {
            if !recentlyDeleted.contains(where: { $0.original.id == d.id }) {
                recentlyDeleted.insert(DeletedDiscount(id: d.id, original: d, deletedAt: Date()), at: 0)
            }
        }
    }
    
    func delete(_ discount: Discount) {
        // Remove from active
        discounts.removeAll { $0.id == discount.id }
        // Add to recently deleted if not already there
        if !recentlyDeleted.contains(where: { $0.original.id == discount.id }) {
            recentlyDeleted.insert(DeletedDiscount(id: discount.id, original: discount, deletedAt: Date()), at: 0)
        }
    }
    
    func permanentlyDeleteFromRecentlyDeleted(_ id: UUID) {
        recentlyDeleted.removeAll { $0.id == id }
    }
    
    func useAmount(_ amount: Double, for discount: Discount) {
        guard amount > 0 else { return }
        if var existing = discounts.first(where: { $0.id == discount.id }) {
            let current = existing.amountLeft ?? 0
            let newAmount = max(0, current - amount)
            existing.amountLeft = newAmount
            updateDiscount(existing)
        }
    }
    
    // MARK: - Persistence (Local + iCloud)
    
    private func loadDiscounts() {
        if let data = UserDefaults.standard.data(forKey: key(discountsKey)),
           let decoded = try? JSONDecoder().decode([Discount].self, from: data) {
            discounts = decoded
        } else {
            discounts = []
        }
    }
    
    private func saveDiscounts() {
        if let data = try? JSONEncoder().encode(discounts) {
            UserDefaults.standard.set(data, forKey: key(discountsKey))
            kvs.set(data, forKey: key(discountsKey))
            kvs.synchronize()
        }
    }
    
    private func loadRecentlyDeleted() {
        if let data = UserDefaults.standard.data(forKey: recentlyDeletedKey),
           let decoded = try? JSONDecoder().decode([DeletedDiscount].self, from: data) {
            recentlyDeleted = decoded
        }
    }
    private func saveRecentlyDeleted() {
        if let data = try? JSONEncoder().encode(recentlyDeleted) {
            UserDefaults.standard.set(data, forKey: recentlyDeletedKey)
            kvs.set(data, forKey: recentlyDeletedKey)
            kvs.synchronize()
        }
    }
    
    private func loadCurrency() {
        if let value = UserDefaults.standard.string(forKey: key(currencyKey)) {
            defaultCurrency = value
        }
    }
    
    private func saveCurrency() {
        UserDefaults.standard.set(defaultCurrency, forKey: key(currencyKey))
        kvs.set(defaultCurrency, forKey: key(currencyKey))
        kvs.synchronize()
    }
    
    private func loadCategories() {
        if let saved = UserDefaults.standard.array(forKey: key(categoriesKey)) as? [String] {
            categories = saved
        } else {
            categories = ["Grocery", "Dining", "Fuel", "Online", "Other"]
        }
    }
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: key(categoriesKey))
        kvs.set(categories, forKey: key(categoriesKey))
        kvs.synchronize()
    }
    
    private func loadTypes() {
        if let saved = UserDefaults.standard.array(forKey: typesKey) as? [String] {
            types = saved
        } else {
            types = ["Coupons", "Gift Cards", "Discounts"]
        }
        // Also try to pull initial value from iCloud if available
        if let cloudTypes = kvs.array(forKey: typesKey) as? [String], cloudTypes != types {
            types = cloudTypes
        }
    }
    private func saveTypes() {
        UserDefaults.standard.set(types, forKey: typesKey)
        kvs.set(types, forKey: typesKey)
        kvs.synchronize()
    }

    private func loadPro() {
        // Force Pro enabled for development
        isProUnlocked = true
    }
    private func savePro() {
        UserDefaults.standard.set(isProUnlocked, forKey: proKey)
    }

    // MARK: - Appearance Persistence
    private func loadAppearanceSettings() {
        if UserDefaults.standard.object(forKey: followSystemKey) != nil {
            followSystemAppearance = UserDefaults.standard.bool(forKey: followSystemKey)
        } else {
            followSystemAppearance = true
        }
        if UserDefaults.standard.object(forKey: forceDarkKey) != nil {
            forceDarkMode = UserDefaults.standard.bool(forKey: forceDarkKey)
        } else {
            forceDarkMode = false
        }
    }

    private func saveAppearanceSettings() {
        UserDefaults.standard.set(followSystemAppearance, forKey: followSystemKey)
        UserDefaults.standard.set(forceDarkMode, forKey: forceDarkKey)
    }

    // MARK: - iCloud KVS helpers
    private func synchronizeFromCloud() {
        kvs.synchronize()
        pullFromCloud()
    }

    private func pullFromCloud() {
        // Discounts
        if let cloudData = kvs.data(forKey: key(discountsKey)),
           let cloudDiscounts = try? JSONDecoder().decode([Discount].self, from: cloudData) {
            if cloudDiscounts != self.discounts {
                self.discounts = cloudDiscounts
            }
        }
        // Currency
        if let cloudCurrency = kvs.string(forKey: key(currencyKey)), cloudCurrency != self.defaultCurrency {
            self.defaultCurrency = cloudCurrency
        }
        // Categories
        if let cloudCategories = kvs.array(forKey: key(categoriesKey)) as? [String], cloudCategories != self.categories {
            self.categories = cloudCategories
        }
        // Types (use global key, not per list)
        if let cloudTypes = kvs.array(forKey: typesKey) as? [String], cloudTypes != self.types {
            self.types = cloudTypes
        }
        // Recently Deleted
        if let cloudDeleted = kvs.data(forKey: recentlyDeletedKey),
           let decoded = try? JSONDecoder().decode([DeletedDiscount].self, from: cloudDeleted),
           decoded != self.recentlyDeleted {
            self.recentlyDeleted = decoded
        }
    }

    private func handleKVSChange(notification: Notification) {
        // When changes arrive from iCloud, pull and merge
        pullFromCloud()
    }
    
    private func loadAllForCurrentList() {
        loadCurrency()
        loadCategories()
        loadDiscounts()
        synchronizeFromCloud()
    }
    
    private func purgeExpiredDeleted() {
        let cutoff = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        let before = recentlyDeleted.count
        recentlyDeleted.removeAll { $0.deletedAt < cutoff }
        if recentlyDeleted.count != before { saveRecentlyDeleted() }
    }
    
    // Added public method resetAllData as per instructions
    func resetAllData(listsVM: ListsViewModel) {
        // Remove per-list keys from UserDefaults and KVS
        for list in listsVM.lists {
            let listIDString = list.id.uuidString
            let discountsKeyForList = discountsKey + "." + listIDString
            let currencyKeyForList = currencyKey + "." + listIDString
            let categoriesKeyForList = categoriesKey + "." + listIDString
            UserDefaults.standard.removeObject(forKey: discountsKeyForList)
            UserDefaults.standard.removeObject(forKey: currencyKeyForList)
            UserDefaults.standard.removeObject(forKey: categoriesKeyForList)
            kvs.removeObject(forKey: discountsKeyForList)
            kvs.removeObject(forKey: currencyKeyForList)
            kvs.removeObject(forKey: categoriesKeyForList)
        }
        // Remove global keys
        UserDefaults.standard.removeObject(forKey: typesKey)
        UserDefaults.standard.removeObject(forKey: recentlyDeletedKey)
        UserDefaults.standard.removeObject(forKey: followSystemKey)
        UserDefaults.standard.removeObject(forKey: forceDarkKey)
        UserDefaults.standard.removeObject(forKey: "lists.info")
        UserDefaults.standard.removeObject(forKey: "lists.selected")
        UserDefaults.standard.removeObject(forKey: proKey)
        kvs.removeObject(forKey: typesKey)
        kvs.removeObject(forKey: recentlyDeletedKey)
        kvs.removeObject(forKey: followSystemKey)
        kvs.removeObject(forKey: forceDarkKey)
        kvs.removeObject(forKey: "lists.info")
        kvs.removeObject(forKey: "lists.selected")
        kvs.removeObject(forKey: proKey)
        kvs.synchronize()
        
        // Reset in-memory state
        discounts = []
        recentlyDeleted = []
        categories = []
        types = ["Coupons", "Gift Cards", "Discounts"]
        defaultCurrency = "USD"
        followSystemAppearance = true
        forceDarkMode = false
        isProUnlocked = true
        
        // Reset default lists
        let defaultLists: [ListInfo] = [
            ListInfo(name: "Coupons", color: .blue,  iconName: "tag", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Coupons", comparison: .equals)]),
            ListInfo(name: "Gift Cards", color: .green, iconName: "gift", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Gift Cards", comparison: .equals)]),
            ListInfo(name: "Discounts", color: .red, iconName: "bag", isDefault: true, isSmart: true, smartMatchAll: true, smartConditions: [ListInfo.SmartCondition(key: .type, stringValue: "Discounts", comparison: .equals)])
        ]
        listsVM.lists = defaultLists
        listsVM.selectedListID = defaultLists.first?.id
        
        // Reload data for current list
        loadAllForCurrentList()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DiscountViewModel()
    @StateObject private var listsVM = ListsViewModel()
    @State private var showingPro: Bool = false
    private var themeColor: Color { listsVM.selectedList?.color ?? .blue }
    private var isPro: Bool { viewModel.isProUnlocked }
    
    @State private var showingForm = false
    @State private var discountToEdit: Discount? = nil
    @State private var editTargetListID: UUID? = nil

    @State private var showingUseSheet = false
    @State private var discountToUse: Discount? = nil
    @State private var pendingUseSourceListID: UUID? = nil

    @State private var discountToShowNumber: Discount? = nil

    @State private var showSettings: Bool = false
    
    private var listOrderVersion: Int {
        var hash = 5381
        for d in filteredDiscounts {
            hash = (hash &* 33) &+ d.id.hashValue
        }
        return hash
    }
    
    private var filteredDiscounts: [Discount] {
        guard let list = listsVM.selectedList else {
            return viewModel.discounts
        }
        if list.id == ListsViewModel.recentlyDeletedID {
            return viewModel.recentlyDeleted.map { $0.original }
        }
        if list.isSmart {
            // Aggregate across all lists for smart lists
            let allIDs: [UUID] = listsVM.lists.map { $0.id }
            // Build a map from discount id to its source list name
            var idToListName: [UUID: String] = [:]
            for l in listsVM.lists {
                let items: [Discount] = viewModel.loadDiscounts(for: l.id)
                for it in items { idToListName[it.id] = l.name }
            }
            let allDiscounts: [Discount] = viewModel.aggregatedDiscounts(for: allIDs)
            let result: [Discount] = allDiscounts.filter { d in
                let sourceListName = idToListName[d.id] ?? ""
                return list.matches(discount: d, listName: sourceListName)
            }
            return result
        } else {
            // Regular list shows only its own items
            let current: [Discount] = viewModel.discounts
            return current
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                List {
                    // Top section: header + totals + (optional) empty state
                    Section {
                        totalsCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                        if filteredDiscounts.isEmpty {
                            emptyState
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .textCase(nil)

                    // Groups sections
                    let groups: [(title: String, items: [Discount])] = computeGroups()
                    ForEach(groups, id: \.title) { group in
                        GroupSectionView(
                            group: group,
                            sectionID: sectionVersion(for: group.title),
                            currencySymbol: { viewModel.currencySymbol(for: $0) },
                            onEdit: { discount in
                                if let sel = listsVM.selectedList, sel.isSmart, let lid = sourceListID(for: discount.id) {
                                    editTargetListID = lid
                                } else {
                                    editTargetListID = viewModel.currentListID
                                }
                                discountToEdit = discount
                            },
                            onDelete: { discount in
                                if listsVM.selectedList?.id == ListsViewModel.recentlyDeletedID {
                                    viewModel.permanentlyDeleteFromRecentlyDeleted(discount.id)
                                } else if let sel = listsVM.selectedList, sel.isSmart, let lid = sourceListID(for: discount.id) {
                                    viewModel.delete(discount, in: lid)
                                } else {
                                    viewModel.delete(discount)
                                }
                            },
                            onUse: { discount in
                                if let sel = listsVM.selectedList, sel.isSmart, let lid = sourceListID(for: discount.id) {
                                    discountToUse = discount
                                    // Stash the id in a temp for use sheet handling
                                    pendingUseSourceListID = lid
                                } else {
                                    discountToUse = discount
                                    pendingUseSourceListID = viewModel.currentListID
                                }
                                showingUseSheet = true
                            },
                            onShowLarge: { discount in
                                discountToShowNumber = discount
                            },
                            onDropToGroup: { sourceIDString, destinationTitle in
                                handleDrop(from: sourceIDString, to: destinationTitle)
                            },
                            onDropToGroupAtIndex: { destinationTitle, index, sourceIDString in
                                handleDropIntoGroup(sourceIDString: sourceIDString, destinationTitle: destinationTitle, destinationIndex: index)
                            },
                            onMoveInGroup: { title, source, dest in
                                moveInCategory(title: title, from: source, to: dest)
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .animation(.snappy, value: filteredDiscounts)
            }
            .overlay(alignment: .bottom) {
                if listsVM.selectedList?.id != ListsViewModel.recentlyDeletedID {
                    addButton
                        .padding(.bottom, 10)
                        .shadow(radius: 6)
                }
            }
            .navigationTitle(listsVM.selectedList?.name ?? "Coupons")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if let list = listsVM.selectedList {
                            Image.systemSymbolPreferringFill(list.iconName)
                                .foregroundStyle(list.color)
                            Text(list.name)
                                .font(.headline)
                        } else {
                            Text("Coupons").font(.headline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(listsVM.selectedList?.name ?? "Coupons")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isPro {
                            withAnimation { listsVM.showingListsSheet.toggle() }
                        } else {
                            showingPro = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Label("Lists", systemImage: "list.bullet")
                            if !isPro {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isPro {
                            viewModel.showCategoriesSettings.toggle()
                        } else {
                            showingPro = true
                        }
                    } label: {
                        Label("Categories", systemImage: "calendar.day.timeline.trailing")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isPro {
                            viewModel.showTypesSettings.toggle()
                        } else {
                            showingPro = true
                        }
                    } label: {
                        Label("Types", systemImage: "tag")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            // Categories settings sheet
            .sheet(isPresented: $viewModel.showCategoriesSettings) {
                CategoriesSettingsView(viewModel: viewModel)
            }
            // Types settings sheet
            .sheet(isPresented: $viewModel.showTypesSettings) {
                TypesSettingsView(viewModel: viewModel)
            }
            // Add form sheet
            .sheet(isPresented: $showingForm) {
                DiscountFormView(
                    viewModel: viewModel,
                    existingDiscount: discountToEdit,
                    targetListID: nil,
                    onClose: {
                        discountToEdit = nil
                    }
                )
                .environmentObject(listsVM)
            }
            // Edit form sheet as item
            .sheet(item: $discountToEdit) { discount in
                DiscountFormView(
                    viewModel: viewModel,
                    existingDiscount: discount,
                    targetListID: editTargetListID,
                    onClose: {
                        discountToEdit = nil
                        editTargetListID = nil
                    }
                )
                .environmentObject(listsVM)
            }
            // Use amount sheet
            .sheet(isPresented: $showingUseSheet) {
                UseAmountView(
                    discount: discountToUse,
                    onCancel: {
                        discountToUse = nil
                    },
                    onUse: { amount in
                        if let d = discountToUse {
                            if let lid = pendingUseSourceListID {
                                viewModel.useAmount(amount, for: d, in: lid)
                            } else {
                                viewModel.useAmount(amount, for: d)
                            }
                        }
                        discountToUse = nil
                        pendingUseSourceListID = nil
                    }
                )
            }
            // Large number display sheet as item
            .sheet(item: $discountToShowNumber) { discount in
                LargeNumberView(
                    discount: discount,
                    onClose: {
                        discountToShowNumber = nil
                    }
                )
            }
            // Settings sheet
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
                    .environmentObject(listsVM)
            }
            // Pro paywall sheet
            .sheet(isPresented: $showingPro) {
                ProPaywallView(isPresented: $showingPro) {
                    // onUpgrade will be called after verified purchase
                }
                .environmentObject(viewModel)
            }
        }
        .overlay(alignment: .leading) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Dim background
                    Color.black.opacity(listsVM.showingListsSheet ? 0.2 : 0.0)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeOut) { listsVM.showingListsSheet = false } }
                        .allowsHitTesting(listsVM.showingListsSheet)

                    // Panel
                    ListsManagerView(listsVM: listsVM)
                        .frame(maxWidth: min(proxy.size.width * 0.85, 420))
                        .frame(maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .shadow(radius: 8)
                        .offset(x: listsVM.showingListsSheet ? 0 : -min(proxy.size.width * 0.9, 460))
                }
                .animation(.easeOut(duration: 0.25), value: listsVM.showingListsSheet)
            }
        }
        .environmentObject(viewModel)
        .environmentObject(listsVM)
        .onAppear {
            if let sel = listsVM.selectedList, sel.id != ListsViewModel.recentlyDeletedID {
                viewModel.currentListID = sel.id
            } else {
                viewModel.currentListID = listsVM.lists.first?.id
            }
        }
        .onChange(of: listsVM.selectedListID) { _, newValue in
            guard let id = newValue else { return }
            if !isPro {
                // Allow only first default list selection when not pro
                let firstDefaultList = listsVM.lists.first(where: { $0.isDefault })
                if id != firstDefaultList?.id {
                    // Reset to first default list and show paywall
                    if let defaultID = firstDefaultList?.id {
                        listsVM.selectedListID = defaultID
                    }
                    showingPro = true
                    return
                }
            }
            if id != ListsViewModel.recentlyDeletedID {
                viewModel.currentListID = id
            }
        }
        .preferredColorScheme(viewModel.followSystemAppearance ? nil : (viewModel.forceDarkMode ? .dark : .light))
    }

    private func computeGroups() -> [(title: String, items: [Discount])] {
        if let selected = listsVM.selectedList, selected.id == ListsViewModel.recentlyDeletedID {
            return buildGroups(discounts: filteredDiscounts, categories: [])
        }
        if let selected = listsVM.selectedList, selected.isSmart {
            // Build a map from discount id to source list name
            var idToListName: [UUID: String] = [:]
            for l in listsVM.lists {
                let items: [Discount] = viewModel.loadDiscounts(for: l.id)
                for it in items { idToListName[it.id] = l.name }
            }
            // Prepare a set of categories defined for the selected list
            let managedCats: Set<String> = Set(viewModel.categories)
            // Transformer: if discount's category isn't in managedCats, label as "Category (ListName)"
            let transformer: (Discount) -> String = { d in
                let raw = (d.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                let base = raw.isEmpty ? "Uncategorized" : raw
                if base == "Uncategorized" { return base }
                if managedCats.contains(base) { return base }
                let listName = idToListName[d.id] ?? "Other"
                return "\(base) (\(listName))"
            }
            return buildGroups(discounts: filteredDiscounts, categories: viewModel.categories, categoryNameTransform: transformer)
        } else {
            return buildGroups(discounts: filteredDiscounts, categories: viewModel.categories)
        }
    }

    private func sourceListID(for discountID: UUID) -> UUID? {
        // Scan all lists and find which one contains the discount id
        for l in listsVM.lists {
            let items = viewModel.loadDiscounts(for: l.id)
            if items.contains(where: { $0.id == discountID }) { return l.id }
        }
        return nil
    }

    @MainActor private func handleDrop(from sourceIDString: String, to destinationTitle: String) {
        guard let sourceID = UUID(uuidString: sourceIDString) else { return }
        // Find source index
        guard let sourceIndex = viewModel.discounts.firstIndex(where: { $0.id == sourceID }) else { return }
        withAnimation {
            var item = viewModel.discounts.remove(at: sourceIndex)
            // Determine new category from destination; Uncategorized means no category
            let newCategoryName = destinationTitle
            item.category = (newCategoryName == "Uncategorized") ? nil : newCategoryName
            // Append to end of destination group order
            // Compute index to insert: after last item in that category
            var insertIndex = viewModel.discounts.endIndex
            let targetKey = item.category ?? "Uncategorized"
            if let lastIndexInCategory = viewModel.discounts.lastIndex(where: { ($0.category ?? "Uncategorized") == targetKey }) {
                insertIndex = viewModel.discounts.index(after: lastIndexInCategory)
            }
            viewModel.discounts.insert(item, at: insertIndex)
        }
    }
    
    @MainActor private func handleDropIntoGroup(sourceIDString: String, destinationTitle: String, destinationIndex: Int) {
        guard let sourceID = UUID(uuidString: sourceIDString) else { return }
        guard let sourceIndex = viewModel.discounts.firstIndex(where: { $0.id == sourceID }) else { return }
        withAnimation {
            var item = viewModel.discounts.remove(at: sourceIndex)
            // Update category according to destination section (nil for Uncategorized)
            let newCategoryName = destinationTitle
            item.category = (newCategoryName == "Uncategorized") ? nil : newCategoryName
            // Compute the flat insertion index in the master discounts array corresponding to the destination section and index
            let targetKey = item.category ?? "Uncategorized"
            // Build a list of indices of items in the target category
            let targetIndices = viewModel.discounts.enumerated().filter { (_, d) in
                (d.category ?? "Uncategorized") == targetKey
            }.map { $0.offset }
            var insertIndex: Int
            if targetIndices.isEmpty {
                // No items in target category yet: append to end
                insertIndex = viewModel.discounts.endIndex
            } else if destinationIndex <= 0 {
                insertIndex = targetIndices.first!
            } else if destinationIndex >= targetIndices.count {
                insertIndex = targetIndices.last! + 1
            } else {
                insertIndex = targetIndices[destinationIndex]
            }
            viewModel.discounts.insert(item, at: insertIndex)
        }
    }

    @MainActor private func moveInCategory(title: String, from source: IndexSet, to destination: Int) {
        // Determine the key used in the array (nil for Uncategorized)
        let targetKey: String? = (title == "Uncategorized") ? nil : title
        // Collect indices of items in that category
        let indices = viewModel.discounts.enumerated().filter { (_, d) in
            (d.category ?? "Uncategorized") == (targetKey ?? "Uncategorized")
        }.map { $0.offset }
        guard !indices.isEmpty else { return }
        // Map the local section indices to global indices
        let sourceGlobal = IndexSet(source.map { indices[$0] })
        var destGlobal: Int
        if destination <= 0 {
            destGlobal = indices.first!
        } else if destination >= indices.count {
            destGlobal = indices.last! + 1
        } else {
            destGlobal = indices[destination]
        }
        withAnimation {
            viewModel.discounts.move(fromOffsets: sourceGlobal, toOffset: destGlobal)
        }
    }
    
    // MARK: - Subviews
    
    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coupon Tracker")
                    .font(.title).bold()
                Text("Track your gift cards, coupons and credits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Values:")
                .font(.headline)
            
            if filteredDiscounts.isEmpty {
                Text("$0.00")
                    .font(.title)
                    .bold()
                    .foregroundStyle(themeColor)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.totalsByCurrency, id: \.code) { (item: (code: String, total: Double)) in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                let symbol = viewModel.currencySymbol(for: item.code)
                                let amountText = String(format: "%.2f", item.total)
                                Text("\(symbol)\(amountText)")
                                    .font(.title2).bold()
                                    .foregroundStyle(themeColor)
                                Text(item.code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemFill))
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("No coupons yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap the button below to add your first coupon.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    private var discountsList: some View {
        let groups = buildGroups(discounts: filteredDiscounts, categories: viewModel.categories)
        return DiscountsListView(
            groups: groups,
            currencySymbol: { viewModel.currencySymbol(for: $0) },
            onEdit: { discount in
                discountToEdit = discount
            },
            onDelete: { discount in
                if listsVM.selectedList?.id == ListsViewModel.recentlyDeletedID {
                    viewModel.permanentlyDeleteFromRecentlyDeleted(discount.id)
                } else {
                    viewModel.delete(discount)
                }
            },
            onUse: { discount in
                discountToUse = discount
                showingUseSheet = true
            },
            onShowLarge: { discount in
                discountToShowNumber = discount
            },
            onDropToGroup: { sourceIDString, destinationTitle in
                handleDrop(from: sourceIDString, to: destinationTitle)
            },
            onDropToGroupAtIndex: { destinationTitle, index, sourceIDString in
                handleDropIntoGroup(sourceIDString: sourceIDString, destinationTitle: destinationTitle, destinationIndex: index)
            },
            onMoveInGroup: { title, source, dest in
                moveInCategory(title: title, from: source, to: dest)
            }
        )
        .environmentObject(viewModel)
    }
    
    private func buildGroups(discounts: [Discount], categories: [String], categoryNameTransform: ((Discount) -> String)? = nil) -> [(title: String, items: [Discount])] {
        // Determine display category for a discount (with optional transform)
        func displayCategory(for d: Discount) -> String {
            if let transform = categoryNameTransform {
                return transform(d)
            }
            let cat = d.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cat.isEmpty ? "Uncategorized" : cat
        }

        // Group discounts by display category
        let byCategory: [String: [Discount]] = Dictionary(grouping: discounts) { (d: Discount) -> String in
            displayCategory(for: d)
        }

        var result: [(String, [Discount])] = []

        // Add known categories in provided order (apply transform to match grouping keys)
        for cat in categories {
            let itemsInOrder = discounts.filter { (d) in
                displayCategory(for: d) == cat
            }
            if !itemsInOrder.isEmpty {
                result.append((cat, itemsInOrder))
            }
        }

        // Add Uncategorized last if present (matching transformed key)
        let uncInOrder = discounts.filter { (d) in
            displayCategory(for: d) == "Uncategorized"
        }
        if !uncInOrder.isEmpty {
            result.append(("Uncategorized", uncInOrder))
        }

        // Add any remaining categories not in the managed list, sorted by name
        let remainingCats = byCategory.keys.filter { key in
            key != "Uncategorized" && !categories.contains(key)
        }.sorted()

        for cat in remainingCats {
            let itemsInOrder = discounts.filter { (d) in
                displayCategory(for: d) == cat
            }
            if !itemsInOrder.isEmpty {
                result.append((cat, itemsInOrder))
            }
        }

        return result
    }
    
    private func sectionVersion(for title: String) -> Int {
        if listsVM.selectedList?.id == ListsViewModel.recentlyDeletedID {
            var hash = 5381
            for d in viewModel.recentlyDeleted {
                hash = (hash &* 33) &+ d.id.hashValue
                hash = (hash &* 33) &+ Int(d.deletedAt.timeIntervalSince1970)
            }
            return hash
        }
        let items: [Discount] = filteredDiscounts.filter { ($0.category ?? "Uncategorized") == title }
        var hash = 5381
        for d in items {
            hash = (hash &* 33) &+ d.id.hashValue
            hash = (hash &* 33) &+ d.number.hashValue
        }
        return hash
    }
    
    private var addButton: some View {
        Button {
            if !isPro && filteredDiscounts.count >= 6 {
                showingPro = true
                return
            }
            discountToEdit = nil
            showingForm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add New Coupon")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(themeColor)
            )
        }
    }
}

private struct DiscountsListView: View {
    let groups: [(title: String, items: [Discount])]
    let currencySymbol: (String) -> String
    let onEdit: (Discount) -> Void
    let onDelete: (Discount) -> Void
    let onUse: (Discount) -> Void
    let onShowLarge: (Discount) -> Void
    let onDropToGroup: (String, String) -> Void
    let onDropToGroupAtIndex: (String, Int, String) -> Void
    let onMoveInGroup: (String, IndexSet, Int) -> Void

    @EnvironmentObject var viewModel: DiscountViewModel

    var body: some View {
        List {
            ForEach(groups, id: \.title) { group in
                GroupSectionView(
                    group: group,
                    sectionID: 0,
                    currencySymbol: currencySymbol,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onUse: onUse,
                    onShowLarge: onShowLarge,
                    onDropToGroup: onDropToGroup,
                    onDropToGroupAtIndex: onDropToGroupAtIndex,
                    onMoveInGroup: onMoveInGroup
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

private struct GroupSectionView: View {
    let group: (title: String, items: [Discount])
    let sectionID: Int
    let currencySymbol: (String) -> String
    let onEdit: (Discount) -> Void
    let onDelete: (Discount) -> Void
    let onUse: (Discount) -> Void
    let onShowLarge: (Discount) -> Void
    let onDropToGroup: (String, String) -> Void
    let onDropToGroupAtIndex: (String, Int, String) -> Void
    let onMoveInGroup: (String, IndexSet, Int) -> Void

    @EnvironmentObject var viewModel: DiscountViewModel

    var body: some View {
        Section(header:
            Text(group.title)
                .font(.title3).bold()
                .textCase(nil)
        ) {
            ForEach(group.items) { discount in
                DiscountRowContainer(
                    discount: discount,
                    symbol: currencySymbol(discount.currency),
                    groupTitle: group.title,
                    viewModel: viewModel,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onUse: onUse,
                    onShowLarge: onShowLarge,
                    onDropToGroupTitle: onDropToGroup
                )
            }
            .onMove(perform: { indices, newOffset in
                onMoveInGroup(group.title, indices, newOffset)
            })
        }
        .id(sectionID)
        .onDrop(of: [UTType.plainText], isTargeted: nil, perform: { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                if let nsString = object as? NSString {
                    let idString = nsString as String
                    DispatchQueue.main.async {
                        onDropToGroup(group.title, idString)
                    }
                }
            }
            return true
        })
    }
}

private struct DiscountRowContainer: View {
    let discount: Discount
    let symbol: String
    let groupTitle: String
    let viewModel: DiscountViewModel
    let onEdit: (Discount) -> Void
    let onDelete: (Discount) -> Void
    let onUse: (Discount) -> Void
    let onShowLarge: (Discount) -> Void
    let onDropToGroupTitle: (String, String) -> Void

    var body: some View {
        HStack(alignment: .center) {
            DiscountRow(
                discount: discount,
                symbol: symbol
            )
            Spacer(minLength: 8)
            RowActionsView(
                discount: discount,
                onUse: { onUse(discount) },
                onShowLarge: { onShowLarge(discount) }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit(discount) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete(discount) } label: {
                Label("Delete", image: "trash")
            }
            Button(action: { onEdit(discount) }, label: {
                Label("Edit", image: "pencil")
            })
            .tint(.blue)
        }
        .onDrag { NSItemProvider(object: discount.id.uuidString as NSString) }
    }
}

private struct RowActionsView: View {
    let discount: Discount
    let onUse: () -> Void
    let onShowLarge: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var listsVM: ListsViewModel
    
    var themeColor: Color {
        listsVM.selectedList?.color ?? .blue
    }

    var body: some View {
        HStack(spacing: 8) {
            if discount.amountLeft != nil {
                Button(action: onUse) {
                    Image(systemName: "dollarsign.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .padding(6)
                .background(Capsule().fill(Color(.secondarySystemFill)))
                .foregroundStyle(themeColor)
            }

            Button(action: onShowLarge) {
                Image(systemName: "textformat.size.larger")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(6)
            .background(Capsule().fill(Color(.secondarySystemFill)))
            .foregroundStyle(themeColor)
        }
    }
}

struct DiscountRow: View {
    let discount: Discount
    let symbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(discount.name)
                .font(.headline)
            Text(discount.number)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
            if let desc = discount.descriptionText, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            if let cat = discount.category, !cat.isEmpty {
                Text(cat)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(.secondarySystemFill))
                    )
            }
            if let t = discount.type, !t.isEmpty {
                Text(t)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(.secondarySystemFill))
                    )
            }
            if let exp = discount.expirationDate {
                Text("Expires " + exp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let amt = discount.amountLeft {
                Text("\(symbol)\(String(format: "%.2f", amt)) \(discount.currency)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct DiscountFormView: View {
    @ObservedObject var viewModel: DiscountViewModel
    var existingDiscount: Discount?
    var targetListID: UUID? = nil
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var listsVM: ListsViewModel

    @State private var name: String = ""
    @State private var number: String = ""
    @State private var amountString: String = ""
    @State private var currency: String = ""
    @State private var descriptionText: String = ""
    @State private var descriptionHeight: CGFloat = 80
    private let descriptionLimit: Int = 120
    @State private var expirationDate: Date? = nil
    @State private var hasExpiration: Bool = false
    @State private var category: String = ""
    @State private var type: String = ""
    @State private var selectedListID: UUID? = nil

    @State private var showPro: Bool = false
    @State private var showDuplicateConfirmation: Bool = false

    var isEditing: Bool { existingDiscount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(isEditing ? "Edit Coupon" : "New Coupon") {
                    TextField("Coupon Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Code / Number", text: $number)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        TextField("Amount Left", text: $amountString)
                            .keyboardType(.decimalPad)
                        Picker("Currency", selection: $currency) {
                            ForEach(viewModel.currencies, id: \.id) { curr in
                                Text(curr.code).tag(curr.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Description") {
                    // Dynamic height TextEditor with a background measuring layer
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 60, maxHeight: max(80, descriptionHeight))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator))
                        )
                        .onChange(of: descriptionText) { oldValue, newValue in
                            if newValue.count > descriptionLimit {
                                descriptionText = String(newValue.prefix(descriptionLimit))
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        descriptionHeight = geo.size.height + 24
                                    }
                                    .onChange(of: descriptionText) { _, _ in
                                        descriptionHeight = geo.size.height + 24
                                    }
                            }
                        )

                    HStack {
                        Spacer()
                        Text("\(min(descriptionText.count, descriptionLimit))/\(descriptionLimit)")
                            .font(.caption2)
                            .foregroundStyle(descriptionText.count > descriptionLimit ? .red : .secondary)
                            .accessibilityLabel("Description character count")
                    }
                }

                if viewModel.isProUnlocked {
                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Type", selection: $type) {
                        Text("None").tag("")
                        ForEach(viewModel.types, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Category (Pro)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                showPro = true
                            } label: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.borderless)
                        }
                        HStack {
                            Text("Type (Pro)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                showPro = true
                            } label: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !(listsVM.selectedList?.isSmart ?? false) {
                    if viewModel.isProUnlocked {
                        Picker("List", selection: Binding(get: { selectedListID ?? listsVM.selectedList?.id }, set: { selectedListID = $0 })) {
                            ForEach(listsVM.lists, id: \.id) { l in
                                if l.id != ListsViewModel.recentlyDeletedID { // exclude Recently Deleted
                                    Text(l.name).tag(Optional(l.id))
                                }
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("List", selection: Binding(get: {
                            // Force to first default list
                            let firstDefault = listsVM.lists.first(where: { $0.isDefault })
                            return selectedListID ?? firstDefault?.id ?? listsVM.selectedList?.id
                        }, set: { _ in })) {
                            ForEach(listsVM.lists.filter { $0.isDefault }, id: \.id) { l in
                                Text(l.name).tag(Optional(l.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(true)
                        .overlay(
                            Button {
                                showPro = true
                            } label: {
                                Color.clear
                            }
                        )
                    }
                }
                
                // Duplicate buttons section (only when editing)
                if isEditing {
                    Section("Duplicate") {
                        HStack(spacing: 12) {
                            Button {
                                duplicateFull()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Full Duplicate")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            
                            Button {
                                duplicatePartial()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Duplicate")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Coupon" : "New Coupon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onClose()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        save()
                    }
                    .disabled(!canSave)
                    .help({
                        if let list = listsVM.selectedList, list.isSmart {
                            return "This coupon must satisfy the smart list's conditions to be saved."
                        } else {
                            return ""
                        }
                    }())
                }
            }
            .onAppear(perform: loadExisting)
            .sheet(isPresented: $showPro) {
                ProPaywallView(isPresented: $showPro) {
                    // Purchase flow handles unlock
                }
                .environmentObject(viewModel)
            }
            .alert("Coupon Duplicated", isPresented: $showDuplicateConfirmation) {
                Button("OK", role: .cancel) {
                    dismiss()
                    onClose()
                }
            } message: {
                Text("A new coupon has been created successfully.")
            }
        }
    }
    
    private func duplicateFull() {
        guard let destListID = selectedListID else { return }
        
        if !viewModel.isProUnlocked {
            let currentCount = viewModel.loadDiscounts(for: destListID).count
            if currentCount >= 8 {
                showPro = true
                return
            }
        }
        
        let amount = Double(amountString)
        let finalExpiration = hasExpiration ? expirationDate : nil
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = trimmedCategory.isEmpty ? nil : trimmedCategory
        let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalType = trimmedType.isEmpty ? nil : trimmedType
        
        let duplicate = Discount(
            id: UUID(),
            name: name,
            number: number,
            amountLeft: amount,
            currency: currency,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText,
            createdAt: Date(),
            expirationDate: finalExpiration,
            category: finalCategory,
            type: finalType
        )
        
        viewModel.addDiscount(duplicate, to: destListID)
        showDuplicateConfirmation = true
    }
    
    private func duplicatePartial() {
        guard let destListID = selectedListID else { return }
        
        if !viewModel.isProUnlocked {
            let currentCount = viewModel.loadDiscounts(for: destListID).count
            if currentCount >= 8 {
                showPro = true
                return
            }
        }
        
        let finalExpiration = hasExpiration ? expirationDate : nil
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = trimmedCategory.isEmpty ? nil : trimmedCategory
        let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalType = trimmedType.isEmpty ? nil : trimmedType
        
        let duplicate = Discount(
            id: UUID(),
            name: name,
            number: "",  // Empty code/number
            amountLeft: nil,  // No amount
            currency: currency,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText,
            createdAt: Date(),
            expirationDate: finalExpiration,
            category: finalCategory,
            type: finalType
        )
        
        viewModel.addDiscount(duplicate, to: destListID)
        showDuplicateConfirmation = true
    }

    private var canSave: Bool {
        let base = !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !number.trimmingCharacters(in: .whitespaces).isEmpty &&
        !currency.isEmpty &&
        selectedListID != nil
        guard base else { return false }
        // Validate against smart list if present
        if let list = listsVM.selectedList, list.isSmart {
            let temp = Discount(id: existingDiscount?.id ?? UUID(), name: name, number: number, amountLeft: Double(amountString), currency: currency, descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText, createdAt: existingDiscount?.createdAt ?? Date(), expirationDate: hasExpiration ? expirationDate : nil, category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category, type: type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : type)
            return list.matches(discount: temp, listName: list.name)
        }
        return true
    }

    private func loadExisting() {
        if let existing = existingDiscount {
            // When editing, default to the list we came from (targetListID)
            if let lid = targetListID { selectedListID = lid }
            else { selectedListID = listsVM.selectedList?.id }

            name = existing.name
            number = existing.number
            if let amt = existing.amountLeft {
                amountString = String(amt)
            } else {
                amountString = ""
            }
            currency = existing.currency
            descriptionText = existing.descriptionText ?? ""
            if let exp = existing.expirationDate {
                expirationDate = exp
                hasExpiration = true
            } else {
                expirationDate = nil
                hasExpiration = false
            }
            category = existing.category ?? ""
            type = existing.type ?? ""
        } else {
            // Default destination list for new coupon
            if let sel = listsVM.selectedList, sel.id != ListsViewModel.recentlyDeletedID {
                selectedListID = sel.id
            } else {
                selectedListID = listsVM.lists.first?.id
            }
            currency = viewModel.defaultCurrency
            descriptionText = ""
            expirationDate = nil
            hasExpiration = false
            category = ""
            type = ""
            if let list = listsVM.selectedList, list.isSmart {
                if let fixedType = list.smartConditions.first(where: { $0.key == .type && $0.comparison == .equals })?.stringValue {
                    type = fixedType
                }
            }
            // In a smart list, lock the destination to the current list and hide the list picker
            if let sel = listsVM.selectedList, sel.isSmart {
                selectedListID = sel.id
            }
            // If not Pro, force list selection to first default list
            if !viewModel.isProUnlocked {
                if let firstDefault = listsVM.lists.first(where: { $0.isDefault }) {
                    selectedListID = firstDefault.id
                }
            }
        }
    }

    private func save() {
        let amount = Double(amountString)
        let finalExpiration = hasExpiration ? expirationDate : nil
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = trimmedCategory.isEmpty ? nil : trimmedCategory
        let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalType = trimmedType.isEmpty ? nil : trimmedType
        guard let destListID = selectedListID else { return }

        if !viewModel.isProUnlocked && !isEditing {
            // Count discounts in target list
            let currentCount = viewModel.loadDiscounts(for: destListID).count
            if currentCount >= 8 {
                showPro = true
                return
            }
        }

        if var existing = existingDiscount {
            existing.name = name
            existing.number = number
            existing.amountLeft = amount
            existing.currency = currency
            existing.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText
            existing.expirationDate = finalExpiration
            existing.category = finalCategory
            existing.type = finalType
            if let sourceID = targetListID {
                if sourceID == destListID {
                    viewModel.updateDiscount(existing, in: sourceID)
                } else {
                    viewModel.moveDiscount(existing, from: sourceID, to: destListID)
                }
            } else if let currentID = viewModel.currentListID {
                if currentID == destListID {
                    viewModel.updateDiscount(existing, in: currentID)
                } else {
                    viewModel.moveDiscount(existing, from: currentID, to: destListID)
                }
            } else {
                // Fallback: update in destination
                viewModel.updateDiscount(existing, in: destListID)
            }
        } else {
            let new = Discount(
                id: UUID(),
                name: name,
                number: number,
                amountLeft: amount,
                currency: currency,
                descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText,
                createdAt: Date(),
                expirationDate: finalExpiration,
                category: finalCategory,
                type: finalType
            )
            viewModel.addDiscount(new, to: destListID)
        }
        dismiss()
        onClose()
    }
}

struct UseAmountView: View {
    let discount: Discount?
    var onCancel: () -> Void
    var onUse: (Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amountString: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Use Amount") {
                    if let discount {
                        Text(discount.name)
                            .font(.headline)
                    }
                    TextField("Amount to use", text: $amountString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Use Balance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        if let amount = Double(amountString), amount > 0 {
                            onUse(amount)
                            dismiss()
                        }
                    }
                    .disabled(Double(amountString) == nil || (Double(amountString) ?? 0) <= 0)
                }
            }
        }
    }
}

struct LargeNumberView: View {
    let discount: Discount?
    var onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedFeedback: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 24) {
                    if let cat = discount?.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let ty = discount?.type, !ty.isEmpty {
                        Text(ty)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let number = discount?.number {
                        Text(number)
                            .font(.system(size: 72, weight: .black, design: .monospaced))
                            .minimumScaleFactor(0.2)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                            )
                            .padding(.horizontal)
                            .onLongPressGesture {
                                UIPasteboard.general.string = number
                                showCopiedFeedback = true
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                // Hide feedback after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedFeedback = false
                                }
                            }
                            .accessibilityHint("Long press to copy to clipboard")
                    }
                    
                    if showCopiedFeedback {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Copied to clipboard")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.regularMaterial)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if let desc = discount?.descriptionText, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(desc)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundStyle(.secondary)
                    }
                    if let d = discount, let amt = d.amountLeft {
                        Text(String(format: "Remaining: %.2f %@", amt, d.currency))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    if let d = discount, let exp = d.expirationDate {
                        Text("Expires " + exp.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(duration: 0.3), value: showCopiedFeedback)
            }
            .navigationTitle(discount?.name ?? "")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        onClose()
                    }
                }
            }
        }
    }
}

struct CategoriesSettingsView: View {
    @ObservedObject var viewModel: DiscountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newCategory: String = ""
    @State private var showPro: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isProUnlocked {
                    Section {
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.yellow)
                                Text("Pro Feature")
                                    .font(.title3.bold())
                                Text("Upgrade to Pro to manage categories")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showPro = true
                        }
                    }
                }
                Section("Add Category") {
                    HStack {
                        TextField("Category name", text: $newCategory)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            let trimmed = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if !viewModel.categories.contains(trimmed) {
                                viewModel.categories.append(trimmed)
                                newCategory = ""
                            }
                        }
                        .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .disabled(!viewModel.isProUnlocked)
                }
                Section("Categories") {
                    if viewModel.categories.isEmpty {
                        Text("No categories yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat)
                        }
                        .onDelete { indexSet in
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            viewModel.categories.remove(atOffsets: indexSet)
                        }
                        .onMove(perform: { indices, newOffset in
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            viewModel.categories.move(fromOffsets: indices, toOffset: newOffset)
                        })
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPro) {
                ProPaywallView(isPresented: $showPro) {
                    // Purchase flow handles unlock
                }
                .environmentObject(viewModel)
            }
        }
    }
}

struct TypesSettingsView: View {
    @ObservedObject var viewModel: DiscountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newType: String = ""
    @State private var showPro: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isProUnlocked {
                    Section {
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.yellow)
                                Text("Pro Feature")
                                    .font(.title3.bold())
                                Text("Upgrade to Pro to manage types")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showPro = true
                        }
                    }
                }
                Section("Add Type") {
                    HStack {
                        TextField("Type name", text: $newType)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            let trimmed = newType.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if !viewModel.types.contains(trimmed) {
                                viewModel.types.append(trimmed)
                                newType = ""
                            }
                        }
                        .disabled(newType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .disabled(!viewModel.isProUnlocked)
                }
                Section("Types") {
                    if viewModel.types.isEmpty {
                        Text("No types yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.types, id: \.self) { t in
                            Text(t)
                        }
                        .onDelete { indexSet in
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            viewModel.types.remove(atOffsets: indexSet)
                        }
                        .onMove(perform: { indices, newOffset in
                            if !viewModel.isProUnlocked {
                                showPro = true
                                return
                            }
                            viewModel.types.move(fromOffsets: indices, toOffset: newOffset)
                        })
                    }
                }
            }
            .navigationTitle("Types")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPro) {
                ProPaywallView(isPresented: $showPro) {
                    // Purchase flow handles unlock
                }
                .environmentObject(viewModel)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: DiscountViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listsVM: ListsViewModel
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Follow System Appearance", isOn: $viewModel.followSystemAppearance)
                    Toggle("Dark Mode", isOn: $viewModel.forceDarkMode)
                        .disabled(viewModel.followSystemAppearance)
                        .foregroundStyle(viewModel.followSystemAppearance ? .secondary : .primary)
                }
                Section("Default Currency") {
                    Picker("Default Currency", selection: $viewModel.defaultCurrency) {
                        ForEach(viewModel.currencies, id: \.id) { currency in
                            Text("\(currency.symbol) \(currency.name) (\(currency.code))").tag(currency.code)
                        }
                    }
                }
                Section("Pro") {
                    Text("Pro is enabled")
                        .foregroundStyle(.secondary)
                }
                Section("Danger Zone") {
                    Button("Reset All Data") {
                        showResetAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } }
            }
            .alert("Are you sure?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Yes, Reset", role: .destructive) {
                    viewModel.resetAllData(listsVM: listsVM)
                }
            } message: {
                Text("This will permanently delete all lists, coupons, categories, types, and settings across this device and iCloud for this Apple ID.")
            }
        }
    }
}

struct ListsManagerView: View {
    @ObservedObject var listsVM: ListsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: DiscountViewModel

    @State private var newName: String = ""
    @State private var newColor: Color = .blue
    @State private var newIcon: String = "list.bullet"
    @State private var isCreatingSmart: Bool = false
    @State private var creatingSmartMatchAll: Bool = true
    @State private var creatingSmartConditions: [ListInfo.SmartCondition] = []

    @State private var showCreate: Bool = false
    @State private var showPro: Bool = false

    private let colorfulGradientColors: [Color] = [
        Color(red: 0.96, green: 0.27, blue: 0.27),
        Color(red: 0.98, green: 0.62, blue: 0.20),
        Color(red: 0.98, green: 0.82, blue: 0.20),
        Color(red: 0.22, green: 0.80, blue: 0.46),
        Color(red: 0.20, green: 0.60, blue: 0.98),
        Color(red: 0.56, green: 0.27, blue: 0.96)
    ]

    private let colorfulSelectionBackground: LinearGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.27, blue: 0.27),
            Color(red: 0.98, green: 0.62, blue: 0.20),
            Color(red: 0.98, green: 0.82, blue: 0.20),
            Color(red: 0.22, green: 0.80, blue: 0.46),
            Color(red: 0.20, green: 0.60, blue: 0.98),
            Color(red: 0.56, green: 0.27, blue: 0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let iconChoicesA: [String] = [
        "list.bullet", "tag", "tag.circle", "tag.square", "gift", "gift.circle", "cart", "cart.fill", "cart.badge.plus", "cart.badge.minus",
        "bag", "bag.fill", "bag.badge.plus", "bag.badge.minus", "creditcard", "creditcard.fill", "wallet.pass", "wallet.pass.fill",
        "ticket", "ticket.fill", "barcode", "qrcode", "dollarsign.circle", "dollarsign.square", "banknote", "percent"
    ]
    static let iconChoicesB: [String] = [
        "shippingbox", "shippingbox.fill", "cube", "cube.box", "purchased", "star", "star.fill", "heart", "heart.fill",
        "bookmark", "bookmark.fill", "calendar", "calendar.badge.plus", "tray", "tray.full", "tray.and.arrow.down",
        "folder", "folder.fill", "folder.badge.plus", "archivebox", "archivebox.fill"
    ]
    static let iconChoices: [String] = iconChoicesA + iconChoicesB

    var body: some View {
        NavigationStack {
            Form {
                proUpsellSection
                newListButtonSection
                createNewListSection
                yourListsSection
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { listsVM.showingListsSheet = false }
                    } label: { Label("Close", systemImage: "xmark") }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .sheet(item: $editing) { edit in
                ListEditView(list: edit, onSave: { listsVM.updateList($0) })
                    .environmentObject(listsVM)
            }
            .sheet(isPresented: $showPro) {
                ProPaywallView(isPresented: $showPro) {
                    // Purchase flow handles unlock
                }
                .environmentObject(viewModel)
            }
        }
    }
    
    @ViewBuilder
    private var proUpsellSection: some View {
        if !viewModel.isProUnlocked {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        Text("Pro Feature")
                            .font(.title3.bold())
                        Text("Upgrade to Pro to manage lists")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showPro = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var newListButtonSection: some View {
        Section {
            Button {
                if !viewModel.isProUnlocked {
                    showPro = true
                    return
                }
                withAnimation { showCreate.toggle() }
            } label: {
                Label(showCreate ? "Hide New List" : "New List", systemImage: showCreate ? "chevron.down.circle" : "plus.circle")
            }
        }
    }
    
    @ViewBuilder
    private var createNewListSection: some View {
        if showCreate && viewModel.isProUnlocked {
            Section("Create New List") {
                TextField("Name", text: $newName)
                ColorPicker("Color", selection: $newColor, supportsOpacity: false)
                Picker("Icon", selection: $newIcon) {
                    ForEach(Self.iconChoices, id: \.self) { name in
                        Label { Text(name) } icon: { Image.systemSymbolPreferringFill(name) }
                            .tag(name)
                    }
                }
                Toggle("Smart List", isOn: $isCreatingSmart)
                if isCreatingSmart {
                    NavigationLink("Edit Smart Conditions") {
                        let proxy = Binding<ListInfo>(
                            get: {
                                ListInfo(name: newName.isEmpty ? "New List" : newName, color: newColor, iconName: newIcon, isDefault: false, isSmart: true, smartMatchAll: creatingSmartMatchAll, smartConditions: creatingSmartConditions)
                            },
                            set: { updated in
                                creatingSmartMatchAll = updated.smartMatchAll
                                creatingSmartConditions = updated.smartConditions
                            }
                        )
                        SmartListEditorView(list: proxy, onSave: nil)
                    }
                }
                Button("Add List") {
                    let info = ListInfo(name: newName.trimmingCharacters(in: .whitespacesAndNewlines), color: newColor, iconName: newIcon, isDefault: false, isSmart: isCreatingSmart, smartMatchAll: creatingSmartMatchAll, smartConditions: creatingSmartConditions)
                    listsVM.lists.append(info)
                    newName = ""; newColor = .blue; newIcon = "list.bullet"; showCreate = false; isCreatingSmart = false
                    creatingSmartMatchAll = true
                    creatingSmartConditions = []
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var yourListsSection: some View {
        Section("Your Lists") {
            if listsVM.lists.isEmpty {
                Text("No lists yet").foregroundStyle(.secondary)
            } else {
                listItemsView
                recentlyDeletedRow
            }
        }
    }
    
    @ViewBuilder
    private var listItemsView: some View {
        ForEach(listsVM.lists) { list in
            ListRowView(
                list: list,
                listsVM: listsVM,
                viewModel: viewModel,
                colorfulSelectionBackground: colorfulSelectionBackground,
                onSelectList: { selectedList in
                    if viewModel.isProUnlocked {
                        listsVM.selectedListID = selectedList.id
                        withAnimation { listsVM.showingListsSheet = false }
                    } else {
                        // Only allow selecting default "Coupons" list
                        if let defaultList = listsVM.lists.first(where: { $0.isDefault }), defaultList.id == selectedList.id {
                            listsVM.selectedListID = selectedList.id
                            withAnimation { listsVM.showingListsSheet = false }
                        } else {
                            showPro = true
                        }
                    }
                },
                onEdit: { list in
                    editing = list
                },
                onDelete: { list in
                    if !viewModel.isProUnlocked {
                        showPro = true
                        return
                    }
                    // Prevent deleting last list
                    if listsVM.lists.count > 1 {
                        if let idx = listsVM.lists.firstIndex(where: { $0.id == list.id }) {
                            listsVM.delete(at: IndexSet(integer: idx))
                        }
                    }
                },
                showPro: $showPro
            )
        }
        .onMove(perform: { idx, newOffset in
            if !viewModel.isProUnlocked {
                showPro = true
                return
            }
            listsVM.lists.move(fromOffsets: idx, toOffset: newOffset)
        })
    }
    
    @ViewBuilder
    private var recentlyDeletedRow: some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: 12)
            ZStack(alignment: .leading) {
                HStack {
                    // Left count bubble for Recently Deleted
                    CountBubble(count: viewModel.recentlyDeleted.count)
                    Image.systemSymbolPreferringFill("trash")
                        .foregroundStyle(Color.gray)
                    Text("Recently Deleted")
                    Spacer()
                    if listsVM.selectedListID == ListsViewModel.recentlyDeletedID {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.gray)
                    }
                }
                .padding(8)
            }
            .listRowBackground(Color.clear)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                if viewModel.isProUnlocked {
                    listsVM.selectedListID = ListsViewModel.recentlyDeletedID
                    withAnimation { listsVM.showingListsSheet = false }
                } else {
                    showPro = true
                }
            }
        }
    }

    @State private var editing: ListInfo? = nil
}

private struct CountBubble: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.caption2).bold()
            .frame(minWidth: 20)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.secondarySystemFill)))
            .foregroundStyle(.secondary)
    }
}

private struct ListRowView: View {
    let list: ListInfo
    let listsVM: ListsViewModel
    let viewModel: DiscountViewModel
    let colorfulSelectionBackground: LinearGradient
    let onSelectList: (ListInfo) -> Void
    let onEdit: (ListInfo) -> Void
    let onDelete: (ListInfo) -> Void
    @Binding var showPro: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                listCountBubble
                Image.systemSymbolPreferringFill(list.iconName)
                    .foregroundStyle(list.color)
                Text(list.name)
                Spacer()
                if listsVM.selectedListID == list.id {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(list.color)
                }
            }
            .padding(8)
            .background(alignment: .leading) {
                if list.isSmart {
                    Circle()
                        .fill(colorfulSelectionBackground)
                        .frame(width: 8, height: 8)
                        .offset(x: -8)
                }
            }
        }
        .listRowBackground(Color.clear)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onSelectList(list)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(list)
            } label: { Label("Delete", systemImage: "trash") }

            Button {
                if !viewModel.isProUnlocked {
                    showPro = true
                    return
                }
                onEdit(list)
            } label: { Label("Edit", systemImage: "pencil") }
            .tint(.blue)
        }
    }
    
    @ViewBuilder
    private var listCountBubble: some View {
        if list.id == ListsViewModel.recentlyDeletedID {
            CountBubble(count: viewModel.recentlyDeleted.count)
        } else if list.isSmart {
            CountBubble(count: smartListCount)
        } else {
            CountBubble(count: viewModel.countForList(list.id))
        }
    }
    
    private var smartListCount: Int {
        var idToListName: [UUID: String] = [:]
        var allDiscounts: [Discount] = []
        for l in listsVM.lists {
            let items = viewModel.loadDiscounts(for: l.id)
            for it in items { idToListName[it.id] = l.name }
            allDiscounts.append(contentsOf: items)
        }
        let matched = allDiscounts.filter { d in
            list.matches(discount: d, listName: idToListName[d.id] ?? "")
        }
        return matched.count
    }
}

// Added Views:

struct ListEditView: View {
    @State var list: ListInfo
    var onSave: (ListInfo) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listsVM: ListsViewModel

    @State private var color: Color = .blue
    @State private var icon: String = "list.bullet"
    @State private var name: String = ""

    @State private var isSmart: Bool = false
    @State private var smartMatchAll: Bool = true
    @State private var smartConditions: [ListInfo.SmartCondition] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Edit List") {
                    TextField("Name", text: $name)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                    Picker("Icon", selection: $icon) {
                        ForEach(ListsManagerView.iconChoices, id: \.self) { name in
                            Label { Text(name) } icon: { Image.systemSymbolPreferringFill(name) }
                                .tag(name)
                        }
                    }

                    Toggle("Smart List", isOn: $isSmart)
                        .disabled(list.isDefault || list.id == ListsViewModel.recentlyDeletedID)
                    if isSmart {
                        NavigationLink("Edit Smart Conditions") {
                            SmartListEditorView(list: Binding(get: {
                                return list
                            }, set: { updated in
                                isSmart = updated.isSmart
                                smartMatchAll = updated.smartMatchAll
                                smartConditions = updated.smartConditions
                                list = updated
                            }), onSave: {
                                onSave(list)
                            })
                        }
                        .disabled(list.isDefault || list.id == ListsViewModel.recentlyDeletedID)
                    }
                }
            }
            .navigationTitle("Edit List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = list
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.colorHex = color.toHexString()
                        updated.iconName = icon
                        updated.isSmart = isSmart
                        updated.smartMatchAll = smartMatchAll
                        updated.smartConditions = smartConditions
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = list.name
                color = list.color
                icon = list.iconName
                isSmart = list.isSmart
                smartMatchAll = list.smartMatchAll
                smartConditions = list.smartConditions
            }
        }
    }
}

struct SmartListEditorView: View {
    @Binding var list: ListInfo
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)? = nil

    @State private var newType: String = ""
    @State private var amount: String = ""
    @State private var selectedKey: ListInfo.ConditionKey = .type
    @State private var comparison: ListInfo.SmartCondition.Comparison = .equals

    var body: some View {
        Form {
            Section("Matching") {
                Toggle("Require all conditions", isOn: $list.smartMatchAll)
            }
            Section("Add Condition") {
                Picker("Field", selection: $selectedKey) {
                    ForEach(ListInfo.ConditionKey.allCases, id: \.self) { k in Text(k.rawValue) }
                }
                Picker("Comparison", selection: $comparison) {
                    ForEach(ListInfo.SmartCondition.Comparison.allCases, id: \.self) { c in Text(c.rawValue) }
                }
                if selectedKey == .type || selectedKey == .list {
                    TextField("Value", text: $newType)
                } else if selectedKey == .amount || selectedKey == .expirationDate {
                    TextField("Number", text: $amount).keyboardType(.decimalPad)
                }
                Button("Add") {
                    var cond = ListInfo.SmartCondition(key: selectedKey, comparison: comparison)
                    if selectedKey == .type || selectedKey == .list { cond.stringValue = newType }
                    if selectedKey == .amount || selectedKey == .expirationDate { cond.doubleValue = Double(amount) }
                    list.smartConditions.append(cond)
                    newType = ""; amount = ""
                }
                .disabled((selectedKey == .type || selectedKey == .list) && newType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Conditions") {
                if list.smartConditions.isEmpty { Text("No conditions yet").foregroundStyle(.secondary) }
                ForEach(list.smartConditions) { cond in
                    HStack {
                        Text(cond.key.rawValue)
                        Spacer()
                        Text(cond.comparison.rawValue)
                        if let s = cond.stringValue { Text(s) }
                        if let d = cond.doubleValue { Text(String(d)) }
                    }
                }
                .onDelete { idx in list.smartConditions.remove(atOffsets: idx) }
            }
        }
        .navigationTitle("Smart Conditions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    onSave?()
                    dismiss()
                }
            }
        }
    }
}

