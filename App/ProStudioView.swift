import SwiftUI

struct ProFeature<Content: View>: View {
    @Environment(ProStore.self) private var pro
    @ViewBuilder var content: () -> Content
    var body: some View { Group { if pro.hasPro { content() } else { ProPaywallView() } } }
}
struct ProStudioCard: View {
    @Environment(ProStore.self) private var pro
    var body: some View {
        NavigationLink { ProStudioView() } label: {
            HStack(spacing: 18) {
                Image(systemName: "sparkles").font(.title2).frame(width: 46, height: 54).background(Theme.sand, in: .rect(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Dress by the Weather Pro")
                    Text(pro.hasPro ? "Open your personal Studio" : "A little more personal.").font(Theme.editorial(25))
                    Text("Your wardrobe. Your week. Your next escape.").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0); Image(systemName: "arrow.up.right")
            }.glassCard()
        }.buttonStyle(.plain).accessibilityIdentifier("openProStudio")
    }
}

struct ProStudioView: View {
    @Environment(ProStore.self) private var pro
    var body: some View {
        Group {
            if pro.hasPro {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        PageHeading(eyebrow: "Your permanent Pro collection", title: "The personal\nstyle studio.")
                        EditorialPhoto(name: "couple_dry_5_2_3", height: 280).clipShape(.rect(cornerRadius: 28))
                        Text("Make fewer decisions. Wear more of what you love.").font(Theme.editorial(29))
                        studioLink("Dress the week", subtitle: "An occasion and an outfit for each forecast day.", icon: "calendar", id: "weeklyPlanner") { WeeklyPlannerView() }
                        studioLink("Your wardrobe", subtitle: "Add your own pieces. Find what works for the weather.", icon: "cabinet", id: "personalWardrobe") { WardrobeView() }
                        studioLink("The travel capsule", subtitle: "Reuse suitable pieces across a destination’s changing forecast.", icon: "suitcase.rolling", id: "capsulePlanner") { CapsuleHomeView() }
                        studioLink("The editorial library", subtitle: "214 couple photographs. Eight considered style guides.", icon: "book.closed", id: "editorialLibrary") { EditorialLibraryView() }
                        Label("Pro unlocked · No subscription", systemImage: "checkmark.seal").font(.caption).foregroundStyle(Theme.olive)
                    }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }.pageBackground()
            } else { ProPaywallView() }
        }.navigationTitle("The Pro Studio").navigationBarTitleDisplayMode(.inline)
    }
    private func studioLink<Destination: View>(_ title: String, subtitle: String, icon: String, id: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { ProFeature { destination() } } label: { HStack(spacing: 18) {
            Image(systemName: icon).font(.title2).frame(width: 38)
            VStack(alignment: .leading, spacing: 7) { Text(title).font(Theme.editorial(26)); Text(subtitle).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading) }
            Spacer(); Image(systemName: "chevron.right").font(.caption)
        }.glassCard() }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

struct ProPaywallView: View {
    @Environment(ProStore.self) private var pro
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                PageHeading(eyebrow: "Dress by the Weather Pro", title: "Good style.\nLess guesswork.")
                EditorialPhoto(name: "couple_dry_5_2_3", height: 260).clipShape(.rect(cornerRadius: 28))
                Text("One purchase. Your own style studio.").font(Theme.editorial(29))
                feature("calendar", "Dress the week", "Save occasions and outfit variations for the next seven forecast days.")
                feature("tshirt", "Wear what you own", "Build a private wardrobe with optional photos, comfort ranges and weather-ready pieces.")
                feature("suitcase.rolling", "Pack a better capsule", "Plan daily outfits and reuse your pieces across changing destination weather.")
                feature("book.closed", "Explore the full collection", "Browse 214 reviewed couple photographs and eight original styling guides.")
                Button { Task { await pro.purchase() } } label: {
                    HStack { Spacer(); if pro.purchasing { ProgressView().tint(.white) }; Text(pro.product.map { "Unlock Pro · \($0.displayPrice)" } ?? (pro.loading ? "Loading App Store price…" : "Price unavailable")); Spacer() }.padding(11)
                }.buttonStyle(.borderedProminent).foregroundStyle(.white).disabled(pro.product == nil || pro.purchasing).accessibilityIdentifier("buyPro")
                Text("One-time purchase. Permanent unlock for this app. No subscription or recurring charge. Your Apple Account handles payment and restoration.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(4)
                if let message = pro.message { Text(message).font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("purchaseMessage") }
                HStack {
                    Button("Restore Purchases") { Task { await pro.restore() } }.disabled(pro.purchasing).accessibilityIdentifier("restorePro")
                    Spacer()
                    Button("Reload price") { Task { await pro.loadProduct() } }.disabled(pro.loading || pro.purchasing)
                }.font(.caption)
                Text("Always free: global weather, current location, worldwide search, daily outfit advice and basic packing lists.").font(.caption).foregroundStyle(Theme.olive).padding(.vertical, 8)
                HStack(spacing: 18) { Link("Privacy", destination: URL(string: "https://www.oanarinaldi.com/dressbytheweatherprivacy.html")!); Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }.font(.caption2)
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.pageBackground().task { await pro.loadProduct() }.accessibilityIdentifier("proPaywall")
    }
    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) { Image(systemName: icon).font(.title3).frame(width: 30).foregroundStyle(Theme.olive); VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.bold()); Text(detail).font(.caption).foregroundStyle(Theme.muted).lineSpacing(3) } }
    }
}
