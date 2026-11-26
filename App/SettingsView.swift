import SwiftUI
import WeatherStyle

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProStore.self) private var pro
    @State private var reminderHour = 8
    @State private var locations = false
    var body: some View {
        @Bindable var model = model
        Form {
            Section { PageHeading(eyebrow: "Personal by nature", title: "Make it yours.").padding(.vertical, 15).listRowBackground(Color.clear) }
            Section("The personal style studio") {
                NavigationLink { ProStudioView() } label: { Label(pro.hasPro ? "Dress Pro · Unlocked" : "Discover Dress Pro", systemImage: "sparkles") }.accessibilityIdentifier("settingsPro")
                Text("Weekly outfits, your wardrobe, travel capsules and the full editorial collection. A one-time purchase; no subscription.").font(.caption).foregroundStyle(Theme.muted)
                Button("Restore Pro Purchase") { Task { await pro.restore() } }.disabled(pro.purchasing)
                if let message = pro.message { Text(message).font(.caption).foregroundStyle(Theme.muted) }
            }
            Section("Your style") {
                Picker("Daily occasion", selection: $model.style) { ForEach(FashionStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Temperature comfort").font(.subheadline)
                    Slider(value: $model.comfort, in: -5...5, step: 1).tint(Theme.olive).accessibilityLabel("Temperature sensitivity")
                    HStack { Text("I run warm"); Spacer(); Text("I feel cold") }.font(.caption2).foregroundStyle(Theme.muted)
                    Text(model.comfort == 0 ? "Standard layering suggestions" : model.comfort > 0 ? "Prefer warmer layers" : "Prefer lighter layers").font(.caption).foregroundStyle(Theme.olive)
                }.padding(.vertical, 10)
            }
            Section("Your weather") {
                Toggle("Fahrenheit (°F)", isOn: $model.fahrenheit)
                Button { locations = true } label: { Label("Saved places", systemImage: "mappin.and.ellipse") }
                Button { model.requestLocation() } label: { Label(model.locating ? "Finding your location…" : "Use current location", systemImage: "location") }.disabled(model.locating)
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section {
                Picker("Remind me at", selection: $reminderHour) { ForEach(5...12, id: \.self) { Text("\($0):00").tag($0) } }
                Button("Enable daily reminder") { Task { await model.scheduleReminder(hour: reminderHour) } }
                Button("Turn off reminder") { model.disableReminder() }
                if let message = model.notificationMessage { Text(message).font(.caption).foregroundStyle(Theme.muted) }
            } header: { Text("A better morning") } footer: { Text("A local reminder invites you to open the app. It doesn’t send forecasts that may have gone stale overnight.") }
            Section("Private, uncomplicated") {
                NavigationLink("Privacy & data") { PrivacyView() }
                NavigationLink("Weather & credits") { CreditsView() }
                NavigationLink("Add a widget") { WidgetHelpView() }
                Link("Support & feedback", destination: URL(string: "https://github.com/oanaunc/dress_by_the_weather/issues")!)
            }
            Section { VStack(alignment: .leading, spacing: 8) { Text("Dress by the Weather").font(Theme.editorial(25)); Text("Your forecast. Your outfit.").font(.caption); Text("Version 1.0 · No account. No ads.").font(.caption2).foregroundStyle(Theme.muted) }.padding(.vertical, 12) }
        }.scrollContentBackground(.hidden).pageBackground().toolbar(.hidden, for: .navigationBar).sheet(isPresented: $locations) { LocationSheet(onSelect: { city in Task { await model.select(city) } }) }
    }
}
struct PrivacyView: View {
    @Environment(AppModel.self) private var model
    @State private var clearStudio = false
    @State private var removalMessage: String?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) {
            PageHeading(eyebrow: "Privacy · November 26, 2026", title: "Your style stays\nyours.")
            paragraph("No account, no tracking", "We don’t run an account service, advertising, analytics or tracking SDKs. Your style preferences, comfort feedback, saved looks, cities and trips are stored on this device. iOS device backups may include this local data.")
            paragraph("Optional location", "If you allow location access, we use an approximate device location while the app is open. You can choose a city instead and change permission in iOS Settings. Coordinates are truncated to four decimal places before weather requests.")
            paragraph("Weather requests", "Forecasts are requested directly from MET Norway. MET receives the requested coordinates and your IP address in order to deliver its service. This applies to searched places as well as current location. Weather responses are cached on this device to reduce requests.")
            Link("MET Norway privacy policy", destination: URL(string: "https://www.met.no/en/About-us/Privacy")!)
            paragraph("Searching for places", "City and address searches use Apple MapKit. Your search query is sent to Apple. Device location isn’t required for a search. Apple’s privacy terms apply to those requests.")
            paragraph("Reminders & removal", "Reminders are scheduled locally, with your permission. Deleting a look or trip removes it from the app. Uninstalling the app removes its local data; copies may remain in your iOS backups. Widgets use a small locally shared snapshot of the last forecast you opened.")
            paragraph("Your Pro wardrobe", "Wardrobe pieces, optional photos, weekly plans, saved inspiration and travel capsules stay in this app on your device. The photo picker shares only images you select. Photos are not uploaded or analyzed by a cloud AI service.")
            paragraph("Pro purchases", "Apple processes the optional one-time Pro purchase. The app uses StoreKit to verify and restore your entitlement. We do not receive your payment card information or run a purchase-verification server.")
            Link("Published privacy policy", destination: URL(string: "https://www.oanarinaldi.com/dressbytheweatherprivacy.html")!)
            Button("Delete saved Pro Studio data", role: .destructive) { clearStudio = true }.font(.subheadline)
            if let removalMessage { Text(removalMessage).font(.caption).foregroundStyle(Theme.muted) }
            Link("Contact via GitHub issues", destination: URL(string: "https://github.com/oanaunc/dress_by_the_weather/issues")!)
        }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity) }.pageBackground().navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete wardrobe pieces and photos, weekly plans, capsules and saved editorial inspiration from this device?", isPresented: $clearStudio) { Button("Delete Studio data", role: .destructive) { do { try model.clearStudioData(); removalMessage = "Your saved Studio data has been removed from this device. Your Pro purchase is unchanged." } catch { removalMessage = "Some saved data couldn’t be removed. Please try again." } } }
    }
    private func paragraph(_ title: String, _ body: String) -> some View { VStack(alignment: .leading, spacing: 10) { Text(title).font(Theme.editorial(26)); Text(body).font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5) } }
}
struct CreditsView: View {
    var body: some View {
        List {
            Section("Free global forecasts") { Link("MET Norway Locationforecast", destination: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/documentation")!); Link("Data licence: CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!); Link("Provider terms of service", destination: URL(string: "https://api.met.no/doc/TermsOfService")!); Text("Weather data are provided by MET Norway. Daily ranges are derived from available forecast samples. Outfit advice is created by this app; MET Norway does not endorse it.").font(.caption) }
            Section("Feels-like estimates") { Text("Estimated from temperature, wind and humidity. Wind chill is used at ≤10°C with wind above 4.8 km/h. Other conditions use the Bureau of Meteorology shade apparent-temperature formula. These values are estimates, not MET Norway observations.").font(.caption); Link("Apparent temperature formula", destination: URL(string: "https://www.bom.gov.au/info/thermal_stress/")!) }
            Section("Photography") { Text("Fashion photography created in Midjourney with fictional adult models. Backgrounds are editorial scenes, not views of the selected location.").font(.caption) }
        }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Weather & credits").navigationBarTitleDisplayMode(.inline)
    }
}
struct WidgetHelpView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "At a glance", title: "Your morning,\none step closer.")
            ForEach(Array(["Touch and hold an empty part of your Home Screen.", "Tap Edit, then Add Widget.", "Search for Dress by the Weather and choose a size.", "Open the app to refresh the forecast. The widget shows its last update and never claims stale weather is live."].enumerated()), id: \.offset) { index, text in HStack(alignment: .top, spacing: 18) { Text(String(index + 1)).font(Theme.editorial(30)).foregroundStyle(Theme.olive); Text(text).font(.subheadline).lineSpacing(5) } }
        }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity) }.pageBackground().navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
    }
}
