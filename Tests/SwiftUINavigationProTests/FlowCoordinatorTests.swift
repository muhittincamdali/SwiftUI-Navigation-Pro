import XCTest
@testable import SwiftUINavigationPro

/// Tests for FlowCoordinator functionality.
final class FlowCoordinatorTests: XCTestCase {
    
    // MARK: - Test Steps
    
    enum TestStep: String, FlowStep, CaseIterable {
        case first
        case second
        case third
        case fourth
    }
    
    // MARK: - Properties
    
    var coordinator: FlowCoordinator<TestStep>!
    
    // MARK: - Setup
    
    @MainActor
    override func setUp() {
        super.setUp()
        coordinator = FlowCoordinator(
            configuration: FlowConfiguration(
                steps: TestStep.allCases
            )
        )
    }
    
    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInitializationWithDefaultStep() async {
        XCTAssertEqual(coordinator.currentStep, .first)
        XCTAssertEqual(coordinator.currentIndex, 0)
        XCTAssertEqual(coordinator.totalSteps, 4)
        XCTAssertFalse(coordinator.isCompleted)
        XCTAssertFalse(coordinator.isCancelled)
    }
    
    @MainActor
    func testInitializationWithCustomInitialStep() async {
        let customCoordinator = FlowCoordinator(
            configuration: FlowConfiguration(
                steps: TestStep.allCases,
                initialStep: .second
            )
        )
        
        XCTAssertEqual(customCoordinator.currentStep, .second)
        XCTAssertEqual(customCoordinator.currentIndex, 1)
    }
    
    @MainActor
    func testProgressCalculation() async {
        XCTAssertEqual(coordinator.progress, 0.0, accuracy: 0.01)
        
        await coordinator.next()
        XCTAssertEqual(coordinator.progress, 1.0 / 3.0, accuracy: 0.01)
        
        await coordinator.next()
        XCTAssertEqual(coordinator.progress, 2.0 / 3.0, accuracy: 0.01)
        
        await coordinator.next()
        XCTAssertEqual(coordinator.progress, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func testNextNavigation() async {
        XCTAssertTrue(coordinator.canMoveForward)
        
        let result = await coordinator.next()
        
        XCTAssertTrue(result)
        XCTAssertEqual(coordinator.currentStep, .second)
        XCTAssertEqual(coordinator.currentIndex, 1)
    }
    
    @MainActor
    func testPreviousNavigation() async {
        await coordinator.next()
        XCTAssertTrue(coordinator.canMoveBackward)
        
        let result = await coordinator.previous()
        
        XCTAssertTrue(result)
        XCTAssertEqual(coordinator.currentStep, .first)
        XCTAssertEqual(coordinator.currentIndex, 0)
    }
    
    @MainActor
    func testCannotGoBackFromFirstStep() async {
        XCTAssertFalse(coordinator.canMoveBackward)
        
        let result = await coordinator.previous()
        
        XCTAssertFalse(result)
        XCTAssertEqual(coordinator.currentStep, .first)
    }
    
    @MainActor
    func testCannotGoForwardFromLastStep() async {
        // Navigate to last step
        await coordinator.next()
        await coordinator.next()
        await coordinator.next()
        
        XCTAssertFalse(coordinator.canMoveForward)
        XCTAssertTrue(coordinator.isLastStep)
        
        let result = await coordinator.next()
        
        XCTAssertFalse(result)
        XCTAssertEqual(coordinator.currentStep, .fourth)
    }
    
    @MainActor
    func testJumpToStep() async {
        let coordinator = FlowCoordinator(
            configuration: FlowConfiguration(
                steps: TestStep.allCases,
                allowSkipping: true
            )
        )
        
        let result = await coordinator.jump(to: .third)
        
        XCTAssertTrue(result)
        XCTAssertEqual(coordinator.currentStep, .third)
        XCTAssertEqual(coordinator.currentIndex, 2)
    }
    
    @MainActor
    func testJumpToStepWithoutSkipping() async {
        // Default config doesn't allow skipping
        let result = await coordinator.jump(to: .fourth)
        
        XCTAssertFalse(result)
        XCTAssertEqual(coordinator.currentStep, .first)
    }
    
    @MainActor
    func testRestart() async {
        await coordinator.next()
        await coordinator.next()
        
        await coordinator.restart()
        
        XCTAssertEqual(coordinator.currentStep, .first)
        XCTAssertEqual(coordinator.currentIndex, 0)
        XCTAssertFalse(coordinator.isCompleted)
    }
    
    // MARK: - State Tests
    
    @MainActor
    func testFlowState() async {
        let state = coordinator.state
        
        XCTAssertEqual(state.currentStep, .first)
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertEqual(state.totalSteps, 4)
        XCTAssertTrue(state.canMoveForward)
        XCTAssertFalse(state.canMoveBackward)
    }
    
    @MainActor
    func testIsFirstStepAndIsLastStep() async {
        XCTAssertTrue(coordinator.isFirstStep)
        XCTAssertFalse(coordinator.isLastStep)
        
        await coordinator.next()
        await coordinator.next()
        await coordinator.next()
        
        XCTAssertFalse(coordinator.isFirstStep)
        XCTAssertTrue(coordinator.isLastStep)
    }
    
    @MainActor
    func testNextStepAndPreviousStep() async {
        XCTAssertEqual(coordinator.nextStep, .second)
        XCTAssertNil(coordinator.previousStep)
        
        await coordinator.next()
        
        XCTAssertEqual(coordinator.nextStep, .third)
        XCTAssertEqual(coordinator.previousStep, .first)
    }
    
    // MARK: - Completion Tests
    
    @MainActor
    func testComplete() async {
        coordinator.complete()
        
        XCTAssertTrue(coordinator.isCompleted)
        XCTAssertFalse(coordinator.isCancelled)
    }
    
    @MainActor
    func testCancel() async {
        coordinator.cancel()
        
        XCTAssertFalse(coordinator.isCompleted)
        XCTAssertTrue(coordinator.isCancelled)
    }
    
    // MARK: - Step Data Tests
    
    @MainActor
    func testSetAndGetData() async {
        struct TestData {
            let value: Int
        }
        
        let data = TestData(value: 42)
        coordinator.setData(data, for: .first)
        
        let retrieved = coordinator.getData(TestData.self, for: .first)
        XCTAssertEqual(retrieved?.value, 42)
    }
    
    @MainActor
    func testClearData() async {
        coordinator.setData("test", for: .first)
        coordinator.clearData(for: .first)
        
        let retrieved = coordinator.getData(String.self, for: .first)
        XCTAssertNil(retrieved)
    }
    
    @MainActor
    func testClearAllData() async {
        coordinator.setData("test1", for: .first)
        coordinator.setData("test2", for: .second)
        coordinator.clearAllData()
        
        XCTAssertNil(coordinator.getData(String.self, for: .first))
        XCTAssertNil(coordinator.getData(String.self, for: .second))
    }
    
    // MARK: - History Tests
    
    @MainActor
    func testHistoryTracking() async {
        XCTAssertEqual(coordinator.history.count, 1)
        XCTAssertEqual(coordinator.history.first, .first)
        
        await coordinator.next()
        await coordinator.next()
        
        XCTAssertEqual(coordinator.history.count, 3)
        XCTAssertEqual(coordinator.history, [.first, .second, .third])
    }
}

// MARK: - Tab Coordinator Tests

final class TabCoordinatorTests: XCTestCase {
    
    enum TestTab: String, TabItem, CaseIterable {
        case home
        case search
        case profile
        
        var title: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .home: return "house"
            case .search: return "magnifyingglass"
            case .profile: return "person"
            }
        }
    }
    
    var coordinator: TabCoordinator<TestTab>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        coordinator = TabCoordinator(
            configuration: TabConfiguration(initialTab: .home)
        )
    }
    
    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }
    
    @MainActor
    func testInitialTab() async {
        XCTAssertEqual(coordinator.selectedTab, .home)
    }
    
    @MainActor
    func testSelectTab() async {
        coordinator.select(.search)
        
        XCTAssertEqual(coordinator.selectedTab, .search)
        XCTAssertEqual(coordinator.previousTab, .home)
    }
    
    @MainActor
    func testSelectNext() async {
        coordinator.selectNext()
        
        XCTAssertEqual(coordinator.selectedTab, .search)
    }
    
    @MainActor
    func testSelectPrevious() async {
        coordinator.select(.profile)
        coordinator.selectPrevious()
        
        XCTAssertEqual(coordinator.selectedTab, .search)
    }
    
    @MainActor
    func testBadgeManagement() async {
        coordinator.setBadge("5", for: .home)
        XCTAssertEqual(coordinator.badges[.home], "5")
        
        coordinator.setBadgeCount(10, for: .search)
        XCTAssertEqual(coordinator.badges[.search], "10")
        
        coordinator.clearBadge(for: .home)
        XCTAssertNil(coordinator.badges[.home])
    }
    
    @MainActor
    func testTabLocking() async {
        coordinator.lock(.profile)
        XCTAssertTrue(coordinator.isLocked(.profile))
        
        coordinator.select(.profile)
        XCTAssertNotEqual(coordinator.selectedTab, .profile)
        
        coordinator.unlock(.profile)
        XCTAssertFalse(coordinator.isLocked(.profile))
    }
    
    @MainActor
    func testTabBarVisibility() async {
        XCTAssertTrue(coordinator.isTabBarVisible)
        
        coordinator.hideTabBar(animated: false)
        XCTAssertFalse(coordinator.isTabBarVisible)
        
        coordinator.showTabBar(animated: false)
        XCTAssertTrue(coordinator.isTabBarVisible)
    }
    
    @MainActor
    func testAllTabs() async {
        XCTAssertEqual(coordinator.allTabs.count, 3)
        XCTAssertTrue(coordinator.allTabs.contains(.home))
        XCTAssertTrue(coordinator.allTabs.contains(.search))
        XCTAssertTrue(coordinator.allTabs.contains(.profile))
    }
}

// MARK: - Navigation History Tests

final class NavigationHistoryTests: XCTestCase {
    
    enum TestRoute: String, Hashable {
        case home
        case detail
        case settings
    }
    
    var history: NavigationHistory<TestRoute>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        history = NavigationHistory()
    }
    
    override func tearDown() {
        history = nil
        super.tearDown()
    }
    
    @MainActor
    func testAddEntry() async {
        history.add(.home)
        
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.currentRoute, .home)
    }
    
    @MainActor
    func testGoBack() async {
        history.add(.home)
        history.add(.detail)
        
        let route = history.goBack()
        
        XCTAssertEqual(route, .home)
        XCTAssertEqual(history.currentRoute, .home)
    }
    
    @MainActor
    func testGoForward() async {
        history.add(.home)
        history.add(.detail)
        history.goBack()
        
        let route = history.goForward()
        
        XCTAssertEqual(route, .detail)
    }
    
    @MainActor
    func testCanGoBackAndForward() async {
        history.add(.home)
        
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
        
        history.add(.detail)
        
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
        
        history.goBack()
        
        XCTAssertFalse(history.canGoBack)
        XCTAssertTrue(history.canGoForward)
    }
    
    @MainActor
    func testClear() async {
        history.add(.home)
        history.add(.detail)
        history.clear()
        
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(history.count, 0)
    }
    
    @MainActor
    func testRecentEntries() async {
        history.add(.home)
        history.add(.detail)
        history.add(.settings)
        
        let recent = history.recentEntries(limit: 2)
        
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first?.route, .settings)
    }
    
    @MainActor
    func testContains() async {
        history.add(.home)
        
        XCTAssertTrue(history.contains(.home))
        XCTAssertFalse(history.contains(.detail))
    }
    
    @MainActor
    func testVisitCount() async {
        history.add(.home)
        history.add(.detail)
        history.add(.home)
        history.add(.home)
        
        XCTAssertEqual(history.visitCount(for: .home), 3)
        XCTAssertEqual(history.visitCount(for: .detail), 1)
    }
}
