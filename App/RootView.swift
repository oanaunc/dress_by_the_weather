import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var model = model
        Group {
            if model.completedOnboarding {
                TabView {
                    Tab("Today", systemImage: "sun.max") { NavigationStack { TodayView() } }
                    Tab("Forecast", systemImage: "chart.xyaxis.line") { NavigationStack { ForecastView() } }
                    Tab("Looks", systemImage: "tshirt") { NavigationStack { LooksView() } }
                    Tab("Planner", systemImage: "suitcase.rolling") { NavigationStack { PlannerView() } }
                    Tab("You", systemImage: "slider.horizontal.3") { NavigationStack { SettingsView() } }
                }.tabBarMinimizeBehavior(.onScrollDown)
            } else { OnboardingView() }
        }.foregroundStyle(Theme.ink)
            .task {
                if model.completedOnboarding && model.forecast == nil { await model.refresh() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && model.completedOnboarding && model.forecast != nil && model.forecast?.isPreview == false { Task { await model.refresh() } }
            }
    }
}
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var showLocations = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Eyebrow(text: "Dress by the Weather"); Spacer(); Image(systemName: "sun.max").font(.title2) }.padding(.top, 14)
                    Image("couple_dry_7_0_0").resizable().scaledToFill().frame(height: max(260, min(geometry.size.height * 0.45, 420)), alignment: .top).clipped().clipShape(.rect(cornerRadius: 30)).overlay(alignment: .bottomLeading) { Text("THE EVERYDAY EDIT").font(.system(size: 9, design: .monospaced)).tracking(2).padding(14).background(.thinMaterial, in: Capsule()).padding(16) }
                    Text("Your forecast.\nYour outfit.").font(Theme.editorial(48)).lineSpacing(-3)
                    Text("A little weather intelligence. A lot of personal style. Know what to wear, before you step outside.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                    HStack { Label("No account", systemImage: "person.crop.circle.badge.checkmark"); Spacer(); Label("Free weather", systemImage: "cloud.sun") }.font(.caption)
                    Button { showLocations = true } label: { HStack { Text("Find my city"); Spacer(); Image(systemName: "arrow.right") }.padding(12).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).accessibilityIdentifier("findCity")
                    Button { model.requestLocation() } label: { HStack { Spacer(); if model.locating { ProgressView() }; Label("Use my current location", systemImage: "location"); Spacer() } }.buttonStyle(.glass).disabled(model.locating)
                    Button("Explore the sample edition") { model.completedOnboarding = true; model.showPreview() }.font(.caption).frame(maxWidth: .infinity)
                    if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
                    Text("Your preferences stay on your device. Location access is optional.").font(.caption2).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.pageBackground().sheet(isPresented: $showLocations) { LocationSheet(onSelect: { city in model.completedOnboarding = true; Task { await model.select(city) } }) }
        }
    }
}
