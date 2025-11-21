import Combine
import SwiftUI

struct Discount: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var number: String
    var amountLeft: Double
    var currency: String
    var createdAt: Date
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
    
    init() {
        loadCurrency()
        loadDiscounts()
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
    
    func addDiscount(name: String, number: String, amountLeft: Double, currency: String) {
        let new = Discount(
            id: UUID(),
            name: name,
            number: number,
            amountLeft: amountLeft,
            currency: currency,
            createdAt: Date()
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
}
struct ContentView: View {
    @StateObject private var viewModel = DiscountViewModel()
    
    @State private var showingForm = false
    @State private var discountToEdit: Discount? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    headerCard
                    
                    totalsCard
                    
                    if viewModel.discounts.isEmpty {
                        emptyState
                    } else {
                        discountsList
                    }
                    
                    addButton
                }
                .padding()
            }
            .navigationTitle("Discount Tracker")
            .toolbar {
                toolbarCurrencyButton
            }
            .sheet(isPresented: $viewModel.showCurrencySettings) {
                CurrencySettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingForm) {
                DiscountFormView(
                    viewModel: viewModel,
                    existingDiscount: discountToEdit
                ) {
                    showingForm = false
                    discountToEdit = nil
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Discount Tracker")
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
                .fill(Color.white)
                .shadow(radius: 4, y: 2)
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
                    .foregroundColor(.purple)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.totalsByCurrency, id: \.code) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(viewModel.currencySymbol(for: item.code))" +
                                     String(format: "%.2f", item.total))
                                    .font(.title2).bold()
                                    .foregroundColor(.purple)
                                Text(item.code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.purple.opacity(0.08))
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 4, y: 2)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("No discounts yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap the button below to add your first discount.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 4, y: 2)
        )
    }
    
    private var discountsList: some View {
        List {
            ForEach(viewModel.discounts) { discount in
                DiscountRow(
                    discount: discount,
                    symbol: viewModel.currencySymbol(for: discount.currency)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    discountToEdit = discount
                    showingForm = true
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.delete(discount)
                    } label: {
                        Label("Delete", image: "trash")
                    }
                    
                    Button(action: {
                        discountToEdit = discount
                        showingForm = true
                    }, label: {
                        Label("Edit", image: "pencil")
                    })
                    .tint(.blue)
                }
            }
            .onDelete(perform: viewModel.delete)
        }
        .listStyle(.insetGrouped)
        .background(Color.clear)
    }
    
    private var addButton: some View {
        Button {
            discountToEdit = nil
            showingForm = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add New Discount")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.purple)
                    .shadow(radius: 4, y: 2)
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
            Text("\(symbol)\(String(format: "%.2f", discount.amountLeft)) \(discount.currency)")
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.1))
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
    
    var isEditing: Bool { existingDiscount != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(isEditing ? "Edit Discount" : "New Discount") {
                    TextField("Discount Name", text: $name)
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
                }
            }
            .navigationTitle(isEditing ? "Edit Discount" : "New Discount")
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
        } else {
            currency = viewModel.defaultCurrency
        }
    }
    
    private func save() {
        guard let amount = Double(amountString) else { return }
        
        if var existing = existingDiscount {
            existing.name = name
            existing.number = number
            existing.amountLeft = amount
            existing.currency = currency
            viewModel.updateDiscount(existing)
        } else {
            viewModel.addDiscount(
                name: name,
                number: number,
                amountLeft: amount,
                currency: currency
            )
        }
        
        dismiss()
        onClose()
    }
}

