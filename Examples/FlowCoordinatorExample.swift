import SwiftUI
import SwiftUINavigationPro

// MARK: - Onboarding Steps

/// Steps in the onboarding flow.
enum OnboardingStep: String, FlowStep, CaseIterable {
    case welcome
    case profile
    case interests
    case notifications
    case complete
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .profile: return "Profile Setup"
        case .interests: return "Your Interests"
        case .notifications: return "Notifications"
        case .complete: return "All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome: return "Welcome to our app! Let's get you started."
        case .profile: return "Tell us a bit about yourself."
        case .interests: return "What topics interest you?"
        case .notifications: return "Stay updated with push notifications."
        case .complete: return "You're all set to start exploring!"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .profile: return "person.fill"
        case .interests: return "star.fill"
        case .notifications: return "bell.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Onboarding Data

/// Data collected during onboarding.
struct OnboardingData {
    var name: String = ""
    var email: String = ""
    var interests: Set<String> = []
    var notificationsEnabled: Bool = false
}

// MARK: - Onboarding Flow App

/// Example app demonstrating flow coordinator.
struct OnboardingFlowApp: View {
    @StateObject private var flowCoordinator = FlowCoordinator(
        configuration: FlowConfiguration(
            steps: OnboardingStep.allCases,
            allowBackNavigation: true,
            persistState: false
        )
    )
    
    @State private var onboardingData = OnboardingData()
    @State private var showMainApp = false
    
    var body: some View {
        if showMainApp {
            MainAppView(userData: onboardingData)
        } else {
            OnboardingContainerView(
                coordinator: flowCoordinator,
                data: $onboardingData,
                onComplete: {
                    withAnimation {
                        showMainApp = true
                    }
                }
            )
        }
    }
}

// MARK: - Onboarding Container View

/// Container for the onboarding flow.
struct OnboardingContainerView: View {
    @ObservedObject var coordinator: FlowCoordinator<OnboardingStep>
    @Binding var data: OnboardingData
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            FlowProgressView(
                coordinator: coordinator,
                tintColor: .blue,
                height: 4,
                showStepIndicators: true
            )
            .padding(.horizontal)
            .padding(.top)
            
            // Step content
            FlowView(coordinator: coordinator) { step in
                stepContent(for: step)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Navigation bar
            FlowNavigationBar(
                coordinator: coordinator,
                backTitle: "Back",
                nextTitle: "Continue",
                completeTitle: "Get Started",
                onComplete: onComplete
            )
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .profile:
            ProfileStepView(name: $data.name, email: $data.email)
        case .interests:
            InterestsStepView(selectedInterests: $data.interests)
        case .notifications:
            NotificationsStepView(isEnabled: $data.notificationsEnabled)
        case .complete:
            CompleteStepView(data: data)
        }
    }
}

// MARK: - Welcome Step

/// The welcome step view.
struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We're excited to have you here. Let's set up your account in just a few steps.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Profile Step

/// The profile setup step view.
struct ProfileStepView: View {
    @Binding var name: String
    @Binding var email: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text("Tell us about yourself")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                TextField("Your Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                
                TextField("Email Address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Interests Step

/// The interests selection step view.
struct InterestsStepView: View {
    @Binding var selectedInterests: Set<String>
    
    let availableInterests = [
        ("Technology", "laptopcomputer"),
        ("Sports", "sportscourt"),
        ("Music", "music.note"),
        ("Art", "paintpalette"),
        ("Travel", "airplane"),
        ("Food", "fork.knife"),
        ("Science", "atom"),
        ("Gaming", "gamecontroller"),
        ("Books", "book"),
        ("Movies", "film")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .padding(.top, 20)
            
            Text("What interests you?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select at least 3 topics")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(availableInterests, id: \.0) { interest, icon in
                    InterestChip(
                        title: interest,
                        icon: icon,
                        isSelected: selectedInterests.contains(interest),
                        action: {
                            if selectedInterests.contains(interest) {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

/// A selectable interest chip.
struct InterestChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 90, height: 70)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Notifications Step

/// The notifications permission step view.
struct NotificationsStepView: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "bell.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Stay Updated")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Enable notifications to get updates about new content, messages, and more.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Toggle("Enable Notifications", isOn: $isEnabled)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Complete Step

/// The completion step view.
struct CompleteStepView: View {
    let data: OnboardingData
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                if !data.name.isEmpty {
                    HStack {
                        Image(systemName: "person")
                        Text("Welcome, \(data.name)!")
                    }
                }
                
                if !data.interests.isEmpty {
                    HStack {
                        Image(systemName: "star")
                        Text("\(data.interests.count) interests selected")
                    }
                }
                
                HStack {
                    Image(systemName: data.notificationsEnabled ? "bell" : "bell.slash")
                    Text("Notifications \(data.notificationsEnabled ? "enabled" : "disabled")")
                }
            }
            .foregroundColor(.secondary)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Main App View

/// The main app view after onboarding.
struct MainAppView: View {
    let userData: OnboardingData
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Welcome to the App!")
                    .font(.title)
                
                if !userData.name.isEmpty {
                    Text("Hello, \(userData.name)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Home")
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowApp()
}
