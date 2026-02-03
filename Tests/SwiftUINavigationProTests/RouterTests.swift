import XCTest
@testable import SwiftUINavigationPro

// MARK: - Test Route

enum TestRoute: Route {
    case home
    case detail(id: Int)
    case settings
    case profile(name: String)

    var path: String {
        switch self {
        case .home: return "/home"
        case .detail(let id): return "/detail/\(id)"
        case .settings: return "/settings"
        case .profile(let name): return "/profile/\(name)"
        }
    }
}

// MARK: - Router Tests

@MainActor
final class RouterTests: XCTestCase {

    var router: Router<TestRoute>!

    override func setUp() {
        super.setUp()
        router = Router<TestRoute>()
    }

    override func tearDown() {
        router = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(router.isAtRoot)
        XCTAssertEqual(router.stackDepth, 0)
        XCTAssertNil(router.topRoute)
    }

    func testPushRoute() {
        router.push(.home)
        XCTAssertEqual(router.stackDepth, 1)
        XCTAssertEqual(router.topRoute, .home)
        XCTAssertFalse(router.isAtRoot)
    }

    func testPushMultipleRoutes() {
        router.push(.home)
        router.push(.detail(id: 42))
        router.push(.settings)
        XCTAssertEqual(router.stackDepth, 3)
        XCTAssertEqual(router.topRoute, .settings)
    }

    func testPopRoute() {
        router.push(.home)
        router.push(.detail(id: 1))
        router.pop()
        XCTAssertEqual(router.stackDepth, 1)
        XCTAssertEqual(router.topRoute, .home)
    }

    func testPopToRoot() {
        router.push(.home)
        router.push(.detail(id: 1))
        router.push(.settings)
        router.popToRoot()
        XCTAssertTrue(router.isAtRoot)
        XCTAssertEqual(router.stackDepth, 0)
    }

    func testPopOnEmptyStackDoesNothing() {
        router.pop()
        XCTAssertTrue(router.isAtRoot)
    }

    func testPresentSheet() {
        router.present(.settings, style: .sheet)
        XCTAssertTrue(router.isSheetPresented)
        XCTAssertEqual(router.presentedSheet, .settings)
    }

    func testDismissSheet() {
        router.present(.settings, style: .sheet)
        router.dismiss()
        XCTAssertFalse(router.isSheetPresented)
        XCTAssertNil(router.presentedSheet)
    }

    func testPresentFullScreenCover() {
        router.present(.profile(name: "test"), style: .fullScreenCover)
        XCTAssertTrue(router.isFullScreenCoverPresented)
        XCTAssertEqual(router.presentedFullScreenCover, .profile(name: "test"))
    }

    func testPushContentsOf() {
        let routes: [TestRoute] = [.home, .detail(id: 1), .settings]
        router.push(contentsOf: routes)
        XCTAssertEqual(router.stackDepth, 3)
        XCTAssertEqual(router.topRoute, .settings)
    }
}

// MARK: - NavigationState Tests

final class NavigationStateTests: XCTestCase {

    func testStateCreation() {
        let state = NavigationState(routes: [TestRoute.home, .detail(id: 5)])
        XCTAssertEqual(state.depth, 2)
        XCTAssertFalse(state.isEmpty)
        XCTAssertEqual(state.topRoute, .detail(id: 5))
        XCTAssertEqual(state.rootRoute, .home)
    }

    func testEmptyState() {
        let state = NavigationState<TestRoute>(routes: [])
        XCTAssertTrue(state.isEmpty)
        XCTAssertEqual(state.depth, 0)
        XCTAssertNil(state.topRoute)
    }

    func testStateCodable() throws {
        let original = NavigationState(routes: [TestRoute.home, .settings])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NavigationState<TestRoute>.self, from: data)
        XCTAssertEqual(decoded.routes, original.routes)
    }

    func testRouteAtIndex() {
        let state = NavigationState(routes: [TestRoute.home, .detail(id: 3)])
        XCTAssertEqual(state.route(at: 0), .home)
        XCTAssertEqual(state.route(at: 1), .detail(id: 3))
        XCTAssertNil(state.route(at: 5))
    }
}
