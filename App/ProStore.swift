import SwiftUI
import StoreKit

@MainActor @Observable final class ProStore {
    static let productID = "com.oanarinaldi.dressbytheweather.pro.lifetime"
    private(set) var hasPro = false
    private(set) var product: Product?
    private(set) var loading = false
    private(set) var purchasing = false
    var message: String?
    @ObservationIgnored private var listener: Task<Void, Never>?
    #if DEBUG
    @ObservationIgnored private let previewUnlock = ProcessInfo.processInfo.arguments.contains("--pro-preview") && ProcessInfo.processInfo.arguments.contains("--preview")
    #endif
    func start() async {
        if listener == nil {
            listener = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    guard case .verified(let transaction) = result, transaction.productID == Self.productID else { continue }
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
        await refreshEntitlements()
    }
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID, transaction.revocationDate == nil,
               transaction.expirationDate == nil { entitled = true }
        }
        #if DEBUG
        hasPro = entitled || previewUnlock
        #else
        hasPro = entitled
        #endif
    }
    func loadProduct() async {
        guard !loading else { return }
        loading = true; message = nil
        defer { loading = false }
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.type == .nonConsumable }
            if product == nil { message = "Pro isn’t available from the App Store right now. Your free weather and daily outfits are ready to use. Try again later." }
        } catch { message = "The App Store couldn’t load the price. Check your connection and try again." }
    }
    func purchase() async {
        guard let product, !purchasing else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result, transaction.productID == Self.productID else { message = "Apple couldn’t verify the purchase. Please try Restore Purchases."; return }
                await refreshEntitlements()
                await transaction.finish()
                if !hasPro { message = "The purchase is not active. Use Restore Purchases or contact Apple for help." }
            case .pending: message = "Your purchase is awaiting approval. Pro will unlock after Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "The purchase wasn’t completed. Please try again."
            }
        } catch StoreKitError.userCancelled {
            // Cancellation leaves the free app available and needs no error alert.
        } catch { message = "The purchase couldn’t be completed. You haven’t been granted Pro. Please try again or restore an existing purchase." }
    }
    func restore() async {
        guard !purchasing else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do { try await AppStore.sync(); await refreshEntitlements(); message = hasPro ? "Your Pro purchase is restored." : "No Pro purchase was found for this Apple Account." }
        catch { message = "Purchases couldn’t be restored. Check your connection and Apple Account, then try again." }
    }
    deinit { listener?.cancel() }
}
