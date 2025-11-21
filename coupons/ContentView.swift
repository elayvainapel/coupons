import Combine
import SwiftUI
import UniformTypeIdentifiers

struct Discount: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var number: String
    var amountLeft: Double
    var currency: String
    var createdAt: Date
    var expirationDate: Date? = nil
    var category: String? = nil
}

struct CurrencyInfo: Identifiable {
    let id = UUID()
    let code: String
    let symbol: String
    let name: String
}

final class DiscountViewModel: ObservableObject {
    @Published var discounts: [Discount] = [] {
        didSet { saveDiscounts() }
    }
    
    @Published var defaultCurrency: String = "USD" {
        didSet { saveCurrency() }
    }
    
    @Published var showCurrencySettings: Bool = false
    @Published var editingDiscount: Discount? = nil
    
    @Published var categories: [String] = [] {
        didSet { saveCategories() }
    }
    @Published var showCategoriesSettings: Bool = false
    
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
    
    private let discountsKey = "discounts"
    private let currencyKey = "defaultCurrency"
    private let categoriesKey = "categories"
    
    init() {
        loadCurrency()
        loadDiscounts()
        loadCategories()
    }
    
    func currencySymbol(for code: String) -> String {
        currencies.first(where: { $0.code == code })?.symbol ?? code
    }
    
    var totalsByCurrency: [(code: String, total: Double)] {
        var dict: [String: Double] = [:]
        for d in discounts {
            let c = d.currency
            dict[c, default: 0] += d.amountLeft
        }
        return dict.map { ($0.key, $0.value) }
            .sorted { $0.code < $1.code }
    }
    
    // MARK: - CRUD
    
    func addDiscount(name: String, number: String, amountLeft: Double, currency: String, expirationDate: Date?, category: String?) {
        let new = Discount(
            id: UUID(),
            name: name,
            number: number,
            amountLeft: amountLeft,
            currency: currency,
            createdAt: Date(),
            expirationDate: expirationDate,
            category: category
        )
        discounts.append(new)
    }
    
    func updateDiscount(_ discount: Discount) {
        if let index = discounts.firstIndex(where: { $0.id == discount.id }) {
            discounts[index] = discount
        }
    }
    
    func delete(at offsets: IndexSet) {
        discounts.remove(atOffsets: offsets)
    }
    
    func delete(_ discount: Discount) {
        discounts.removeAll { $0.id == discount.id }
    }
    
    func useAmount(_ amount: Double, for discount: Discount) {
        guard amount > 0 else { return }
        if var existing = discounts.first(where: { $0.id == discount.id }) {
            let newAmount = max(0, existing.amountLeft - amount)
            existing.amountLeft = newAmount
            updateDiscount(existing)
        }
    }
    
    // MARK: - Persistence
    
    private func loadDiscounts() {
        guard let data = UserDefaults.standard.data(forKey: discountsKey) else { return }
        if let decoded = try? JSONDecoder().decode([Discount].self, from: data) {
            discounts = decoded
        }
    }
    
    private func saveDiscounts() {
        if let data = try? JSONEncoder().encode(discounts) {
            UserDefaults.standard.set(data, forKey: discountsKey)
        }
    }
    
    private func loadCurrency() {
        if let value = UserDefaults.standard.string(forKey: currencyKey) {
            defaultCurrency = value
        }
    }
    
    private func saveCurrency() {
        UserDefaults.standard.set(defaultCurrency, forKey: currencyKey)
    }
    
    private func loadCategories() {
        if let saved = UserDefaults.standard.array(forKey: categoriesKey) as? [String] {
            categories = saved
        } else {
            categories = ["Grocery", "Dining", "Fuel", "Online", "Other"]
        }
    }
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: categoriesKey)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DiscountViewModel()
    
    @State private var showingForm = false
    @State private var discountToEdit: Discount? = nil

    @State private var showingUseSheet = false
    @State private var discountToUse: Discount? = nil

    @State private var discountToShowNumber: Discount? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerCard
                            totalsCard
                            if viewModel.discounts.isEmpty {
                                emptyState
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .scrollIndicators(.never)
                    
                    if !viewModel.discounts.isEmpty {
                        discountsList
                    }

                    // Bottom add button
                    addButton
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Coupons")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarCurrencyButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCategoriesSettings.toggle()
                    } label: {
                        Label("Categories", systemImage: "folder")
                    }
                }
            }
            // Currency settings sheet
            .sheet(isPresented: $viewModel.showCurrencySettings) {
                CurrencySettingsView(viewModel: viewModel)
            }
            // Categories settings sheet
            .sheet(isPresented: $viewModel.showCategoriesSettings) {
                CategoriesSettingsView(viewModel: viewModel)
            }
            // Add form sheet
            .sheet(isPresented: $showingForm) {
                DiscountFormView(
                    viewModel: viewModel,
                    existingDiscount: discountToEdit,
                    onClose: {
                        discountToEdit = nil
                    }
                )
            }
            // Edit form sheet as item
            .sheet(item: $discountToEdit) { discount in
                DiscountFormView(
                    viewModel: viewModel,
                    existingDiscount: discount,
                    onClose: {
                        discountToEdit = nil
                    }
                )
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
                            viewModel.useAmount(amount, for: d)
                        }
                        discountToUse = nil
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
        }
    }

    private func handleDrop(from sourceIDString: String, to destinationTitle: String) {
        guard let sourceID = UUID(uuidString: sourceIDString) else { return }
        // Find source index
        guard let sourceIndex = viewModel.discounts.firstIndex(where: { $0.id == sourceID }) else { return }
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
    
    private func handleDropIntoGroup(sourceIDString: String, destinationTitle: String, destinationIndex: Int) {
        guard let sourceID = UUID(uuidString: sourceIDString) else { return }
        guard let sourceIndex = viewModel.discounts.firstIndex(where: { $0.id == sourceID }) else { return }
        var item = viewModel.discounts.remove(at: sourceIndex)
        // Update category according to destination section (nil for Uncategorized)
        let newCategoryName = destinationTitle
        item.category = (newCategoryName == "Uncategorized") ? nil : newCategoryName
        // Compute the flat insertion index in the master discounts array corresponding to the destination section and index
        // Find the indices of items that belong to the target category in the current discounts array
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

    private func moveInCategory(title: String, from source: IndexSet, to destination: Int) {
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
        viewModel.discounts.move(fromOffsets: sourceGlobal, toOffset: destGlobal)
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
            
            if viewModel.totalsByCurrency.isEmpty {
                Text("$0.00")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.tint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.totalsByCurrency, id: \.code) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(viewModel.currencySymbol(for: item.code))" +
                                     String(format: "%.2f", item.total))
                                    .font(.title2).bold()
                                    .foregroundStyle(.tint)
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
        let groups = buildGroups(discounts: viewModel.discounts, categories: viewModel.categories)
        return DiscountsListView(
            groups: groups,
            currencySymbol: { viewModel.currencySymbol(for: $0) },
            onEdit: { discount in
                discountToEdit = discount
            },
            onDelete: { discount in
                viewModel.delete(discount)
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
    }
    
    private func buildGroups(discounts: [Discount], categories: [String]) -> [(title: String, items: [Discount])] {
        // Group discounts by category name or "Uncategorized"
        let byCategory: [String: [Discount]] = Dictionary(grouping: discounts) { (d: Discount) -> String in
            let cat = d.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cat.isEmpty ? "Uncategorized" : cat
        }

        var result: [(String, [Discount])] = []

        // Helper to sort items by name (case-insensitive)
        func sortedByName(_ items: [Discount]) -> [Discount] {
            items.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        // Add known categories in provided order
        for cat in categories {
            if let items = byCategory[cat], !items.isEmpty {
                result.append((cat, sortedByName(items)))
            }
        }

        // Add Uncategorized last if present
        if let unc = byCategory["Uncategorized"], !unc.isEmpty {
            result.append(("Uncategorized", sortedByName(unc)))
        }

        // Add any remaining categories not in the managed list, sorted by name
        let remainingCats = byCategory.keys.filter { key in
            key != "Uncategorized" && !categories.contains(key)
        }.sorted()

        for cat in remainingCats {
            if let items = byCategory[cat], !items.isEmpty {
                result.append((cat, sortedByName(items)))
            }
        }

        return result
    }
    
    private var addButton: some View {
        Button {
            discountToEdit = nil
            showingForm = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add New Coupon")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.tint)
            )
        }
        .padding(.top, 4)
    }
    
    private var toolbarCurrencyButton: some View {
        Button {
            viewModel.showCurrencySettings.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.currencySymbol(for: viewModel.defaultCurrency))
                Text("Currency")
            }
            .foregroundStyle(.primary)
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

    var body: some View {
        List {
            ForEach(groups, id: \.title) { group in
                GroupSectionView(
                    group: group,
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
    let currencySymbol: (String) -> String
    let onEdit: (Discount) -> Void
    let onDelete: (Discount) -> Void
    let onUse: (Discount) -> Void
    let onShowLarge: (Discount) -> Void
    let onDropToGroup: (String, String) -> Void
    let onDropToGroupAtIndex: (String, Int, String) -> Void
    let onMoveInGroup: (String, IndexSet, Int) -> Void

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
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onUse: onUse,
                    onShowLarge: onShowLarge
                )
            }
            .onInsert(of: [UTType.text]) { index, providers in
                guard let provider = providers.first else { return }
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    if let nsString = object as? NSString {
                        let idString = nsString as String
                        DispatchQueue.main.async {
                            onDropToGroupAtIndex(group.title, index, idString)
                        }
                    }
                }
            }
            .onMove { indices, newOffset in
                onMoveInGroup(group.title, indices, newOffset)
            }
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                if let nsString = object as? NSString {
                    let idString = nsString as String
                    DispatchQueue.main.async {
                        onDropToGroup(idString, group.title)
                    }
                }
            }
            return true
        }
    }
}

private struct DiscountRowContainer: View {
    let discount: Discount
    let symbol: String
    let onEdit: (Discount) -> Void
    let onDelete: (Discount) -> Void
    let onUse: (Discount) -> Void
    let onShowLarge: (Discount) -> Void

    var body: some View {
        HStack(alignment: .center) {
            DiscountRow(
                discount: discount,
                symbol: symbol
            )
            Spacer(minLength: 8)
            RowActionsView(
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
    let onUse: () -> Void
    let onShowLarge: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onUse) {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(6)
            .background(Capsule().fill(Color(.secondarySystemFill)))
            .foregroundStyle(.tint)

            Button(action: onShowLarge) {
                Image(systemName: "textformat.size.larger")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(6)
            .background(Capsule().fill(Color(.secondarySystemFill)))
            .foregroundStyle(.tint)
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
            if let cat = discount.category, !cat.isEmpty {
                Text(cat)
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
            Text("\(symbol)\(String(format: "%.2f", discount.amountLeft)) \(discount.currency)")
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                )
        }
        .padding(.vertical, 4)
    }
}

struct CurrencySettingsView: View {
    @ObservedObject var viewModel: DiscountViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Default Currency") {
                    Picker("Default Currency", selection: $viewModel.defaultCurrency) {
                        ForEach(viewModel.currencies) { currency in
                            Text("\(currency.symbol) \(currency.name) (\(currency.code))")
                                .tag(currency.code)
                        }
                    }
                }
            }
            .navigationTitle("Currency Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
struct DiscountFormView: View {
    @ObservedObject var viewModel: DiscountViewModel
    var existingDiscount: Discount?
    var onClose: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var amountString: String = ""
    @State private var currency: String = ""
    @State private var expirationDate: Date? = nil
    @State private var hasExpiration: Bool = false
    @State private var category: String = ""
    
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
                            ForEach(viewModel.currencies) { curr in
                                Text(curr.code).tag(curr.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Toggle("Has Expiration", isOn: $hasExpiration)
                    DatePicker("Expiration Date", selection: Binding(
                        get: { expirationDate ?? Date() },
                        set: { expirationDate = $0 }
                    ), displayedComponents: .date)
                    .disabled(!hasExpiration)
                    
                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
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
                }
            }
            .onAppear(perform: loadExisting)
        }
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !number.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amountString) != nil &&
        !currency.isEmpty
    }
    
    private func loadExisting() {
        if let existing = existingDiscount {
            name = existing.name
            number = existing.number
            amountString = String(existing.amountLeft)
            currency = existing.currency
            if let exp = existing.expirationDate {
                expirationDate = exp
                hasExpiration = true
            } else {
                expirationDate = nil
                hasExpiration = false
            }
            category = existing.category ?? ""
        } else {
            currency = viewModel.defaultCurrency
            expirationDate = nil
            hasExpiration = false
            category = ""
        }
    }
    
    private func save() {
        guard let amount = Double(amountString) else { return }
        
        let finalExpiration = hasExpiration ? expirationDate : nil
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = trimmedCategory.isEmpty ? nil : trimmedCategory
        
        if var existing = existingDiscount {
            existing.name = name
            existing.number = number
            existing.amountLeft = amount
            existing.currency = currency
            existing.expirationDate = finalExpiration
            existing.category = finalCategory
            viewModel.updateDiscount(existing)
        } else {
            viewModel.addDiscount(
                name: name,
                number: number,
                amountLeft: amount,
                currency: currency,
                expirationDate: finalExpiration,
                category: finalCategory
            )
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
                    }
                    if let d = discount {
                        Text(String(format: "Remaining: %.2f %@", d.amountLeft, d.currency))
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Add Category") {
                    HStack {
                        TextField("Category name", text: $newCategory)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            let trimmed = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if !viewModel.categories.contains(trimmed) {
                                viewModel.categories.append(trimmed)
                                newCategory = ""
                            }
                        }
                        .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
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
                            viewModel.categories.remove(atOffsets: indexSet)
                        }
                        .onMove { indices, newOffset in
                            viewModel.categories.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

