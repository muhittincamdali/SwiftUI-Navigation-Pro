import Foundation
import Combine

// MARK: - Deep Link Result

/// The result of parsing a deep link.
public enum DeepLinkResult<R: Route>: Sendable {
    /// Successfully parsed route.
    case success(route: R, parameters: [String: String])
    /// Failed to parse with reason.
    case failure(reason: DeepLinkError)
    
    /// The parsed route, if successful.
    public var route: R? {
        if case .success(let route, _) = self {
            return route
        }
        return nil
    }
    
    /// The parsed parameters, if successful.
    public var parameters: [String: String]? {
        if case .success(_, let params) = self {
            return params
        }
        return nil
    }
    
    /// Whether parsing was successful.
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Deep Link Error

/// Errors that can occur during deep link parsing.
public enum DeepLinkError: Error, Sendable {
    /// The URL scheme is not accepted.
    case invalidScheme(scheme: String?, accepted: Set<String>)
    /// The URL host doesn't match.
    case invalidHost(host: String?, expected: String?)
    /// No pattern matched the URL.
    case noMatchingPattern(path: String)
    /// A required parameter is missing.
    case missingParameter(name: String)
    /// A parameter value is invalid.
    case invalidParameter(name: String, value: String)
    /// The URL is malformed.
    case malformedURL(String)
    /// A custom validation failed.
    case validationFailed(reason: String)
    /// The deep link is expired.
    case expired(Date)
    /// The deep link requires authentication.
    case authenticationRequired
}

// MARK: - Deep Link Event

/// Events that occur during deep link handling.
public enum DeepLinkEvent<R: Route>: Sendable {
    /// A deep link was received.
    case received(url: URL)
    /// A deep link was successfully parsed.
    case parsed(route: R, url: URL)
    /// A deep link failed to parse.
    case failed(error: DeepLinkError, url: URL)
    /// A deep link was handled.
    case handled(route: R)
    /// A deep link was deferred for later handling.
    case deferred(url: URL)
}

// MARK: - Pattern Match Result

/// The result of matching a URL against a pattern.
public struct PatternMatchResult: Sendable {
    /// Whether the pattern matched.
    public let matched: Bool
    /// Extracted path parameters.
    public let pathParameters: [String: String]
    /// Query parameters from the URL.
    public let queryParameters: [String: String]
    /// The matched pattern.
    public let pattern: String?
    /// Match confidence score (0.0 to 1.0).
    public let confidence: Double
    
    /// Creates a successful match result.
    public static func success(
        pathParameters: [String: String],
        queryParameters: [String: String],
        pattern: String,
        confidence: Double = 1.0
    ) -> PatternMatchResult {
        PatternMatchResult(
            matched: true,
            pathParameters: pathParameters,
            queryParameters: queryParameters,
            pattern: pattern,
            confidence: confidence
        )
    }
    
    /// Creates a failed match result.
    public static let failure = PatternMatchResult(
        matched: false,
        pathParameters: [:],
        queryParameters: [:],
        pattern: nil,
        confidence: 0
    )
}

/// A configurable parser that converts deep link URLs into typed routes.
///
/// `DeepLinkParser` accepts a closure that maps a `URL` to an optional route.
/// You can also register path patterns for automatic matching.
///
/// ```swift
/// let parser = DeepLinkParser<AppRoute> { url in
///     switch url.path {
///     case "/home": return .home
///     default: return nil
///     }
/// }
/// ```
public struct DeepLinkParser<R: Route> {

    // MARK: - Types

    /// A closure that attempts to parse a URL into a route.
    public typealias ParserHandler = (URL) -> R?

    /// A registered pattern with its associated route factory.
    struct PatternEntry {
        let pattern: String
        let parameterNames: [String]
        let factory: ([String: String]) -> R?
    }

    // MARK: - Properties

    /// The primary parsing closure.
    private let handler: ParserHandler

    /// Registered URL path patterns.
    private var patterns: [PatternEntry] = []

    /// The URL schemes this parser accepts. Empty means accept all schemes.
    private let acceptedSchemes: Set<String>

    /// The host this parser expects. `nil` means accept any host.
    private let expectedHost: String?

    // MARK: - Initialization

    /// Creates a parser with a custom handler closure.
    ///
    /// - Parameters:
    ///   - schemes: Accepted URL schemes (default: all).
    ///   - host: Expected host (default: any).
    ///   - handler: A closure that maps URLs to routes.
    public init(
        schemes: Set<String> = [],
        host: String? = nil,
        handler: @escaping ParserHandler
    ) {
        self.acceptedSchemes = schemes
        self.expectedHost = host
        self.handler = handler
    }

    // MARK: - Pattern Registration

    /// Registers a URL path pattern for automatic route matching.
    ///
    /// Patterns use `:paramName` syntax for path parameters:
    /// ```swift
    /// parser.register("/profile/:userId") { params in
    ///     guard let id = params["userId"] else { return nil }
    ///     return .profile(userId: id)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - pattern: The URL path pattern with `:param` placeholders.
    ///   - factory: A closure that creates a route from extracted parameters.
    public mutating func register(
        _ pattern: String,
        factory: @escaping ([String: String]) -> R?
    ) {
        let components = pattern.split(separator: "/")
        let parameterNames = components
            .filter { $0.hasPrefix(":") }
            .map { String($0.dropFirst()) }

        let entry = PatternEntry(
            pattern: pattern,
            parameterNames: parameterNames,
            factory: factory
        )
        patterns.append(entry)
    }

    // MARK: - Parsing

    /// Parses a URL into a route.
    ///
    /// The parser first checks registered patterns, then falls back to the
    /// custom handler closure.
    ///
    /// - Parameter url: The URL to parse.
    /// - Returns: A route if the URL could be parsed, or `nil`.
    public func parse(_ url: URL) -> R? {
        guard isAcceptedScheme(url) else { return nil }
        guard isExpectedHost(url) else { return nil }

        // Try registered patterns first
        if let route = matchPatterns(url) {
            return route
        }

        // Fall back to custom handler
        return handler(url)
    }

    /// Parses a URL string into a route.
    ///
    /// - Parameter urlString: The URL string to parse.
    /// - Returns: A route if the URL could be parsed, or `nil`.
    public func parse(_ urlString: String) -> R? {
        guard let url = URL(string: urlString) else { return nil }
        return parse(url)
    }

    // MARK: - Private Helpers

    private func isAcceptedScheme(_ url: URL) -> Bool {
        guard !acceptedSchemes.isEmpty else { return true }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return acceptedSchemes.contains(scheme)
    }

    private func isExpectedHost(_ url: URL) -> Bool {
        guard let expectedHost else { return true }
        return url.host?.lowercased() == expectedHost.lowercased()
    }

    private func matchPatterns(_ url: URL) -> R? {
        let urlComponents = url.pathComponents.filter { $0 != "/" }

        for entry in patterns {
            let patternComponents = entry.pattern.split(separator: "/").map(String.init)

            guard urlComponents.count == patternComponents.count else { continue }

            var parameters: [String: String] = [:]
            var isMatch = true

            for (urlPart, patternPart) in zip(urlComponents, patternComponents) {
                if patternPart.hasPrefix(":") {
                    let paramName = String(patternPart.dropFirst())
                    parameters[paramName] = urlPart
                } else if urlPart != patternPart {
                    isMatch = false
                    break
                }
            }

            if isMatch, let route = entry.factory(parameters) {
                return route
            }
        }

        return nil
    }
}

// MARK: - Query Parameter Extraction

public extension DeepLinkParser {
    /// Extracts query parameters from a URL as a dictionary.
    ///
    /// - Parameter url: The URL to extract parameters from.
    /// - Returns: A dictionary of query parameter names and values.
    static func queryParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }
        return params
    }
    
    /// Extracts a typed value from query parameters.
    ///
    /// - Parameters:
    ///   - key: The parameter key.
    ///   - url: The URL to extract from.
    ///   - transform: A transform closure.
    /// - Returns: The transformed value, if available.
    static func queryParameter<T>(
        _ key: String,
        from url: URL,
        transform: (String) -> T?
    ) -> T? {
        let params = queryParameters(from: url)
        guard let value = params[key] else { return nil }
        return transform(value)
    }
    
    /// Extracts an integer query parameter.
    ///
    /// - Parameters:
    ///   - key: The parameter key.
    ///   - url: The URL to extract from.
    /// - Returns: The integer value, if available.
    static func intParameter(_ key: String, from url: URL) -> Int? {
        queryParameter(key, from: url, transform: Int.init)
    }
    
    /// Extracts a boolean query parameter.
    ///
    /// - Parameters:
    ///   - key: The parameter key.
    ///   - url: The URL to extract from.
    /// - Returns: The boolean value, if available.
    static func boolParameter(_ key: String, from url: URL) -> Bool? {
        queryParameter(key, from: url) { value in
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
    }
}

// MARK: - Deep Link Handler

/// A handler that manages deep link parsing and routing.
@MainActor
public final class DeepLinkHandler<R: Route>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The most recently parsed route.
    @Published public private(set) var currentRoute: R?
    
    /// Whether a deep link is being processed.
    @Published public private(set) var isProcessing: Bool = false
    
    /// The last error that occurred.
    @Published public private(set) var lastError: DeepLinkError?
    
    /// Pending deep links waiting to be handled.
    @Published public private(set) var pendingLinks: [URL] = []
    
    // MARK: - Properties
    
    /// The parser to use.
    private var parser: DeepLinkParser<R>
    
    /// The event publisher.
    private let eventSubject = PassthroughSubject<DeepLinkEvent<R>, Never>()
    
    /// Publisher for deep link events.
    public var events: AnyPublisher<DeepLinkEvent<R>, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Route handlers.
    private var handlers: [String: (R, [String: String]) -> Void] = [:]
    
    /// Whether to defer links when not ready.
    public var deferWhenNotReady: Bool = true
    
    /// Whether the handler is ready to process links.
    public var isReady: Bool = true
    
    /// Cancellables for subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a deep link handler.
    ///
    /// - Parameter parser: The parser to use.
    public init(parser: DeepLinkParser<R>) {
        self.parser = parser
    }
    
    /// Creates a deep link handler with a simple parser closure.
    ///
    /// - Parameter handler: A closure that parses URLs to routes.
    public convenience init(handler: @escaping (URL) -> R?) {
        let parser = DeepLinkParser<R>(handler: handler)
        self.init(parser: parser)
    }
    
    // MARK: - Handling
    
    /// Handles a deep link URL.
    ///
    /// - Parameter url: The URL to handle.
    /// - Returns: Whether the URL was successfully handled.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        eventSubject.send(.received(url: url))
        
        guard isReady else {
            if deferWhenNotReady {
                pendingLinks.append(url)
                eventSubject.send(.deferred(url: url))
            }
            return false
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        guard let route = parser.parse(url) else {
            let error = DeepLinkError.noMatchingPattern(path: url.path)
            lastError = error
            eventSubject.send(.failed(error: error, url: url))
            return false
        }
        
        currentRoute = route
        let params = DeepLinkParser<R>.queryParameters(from: url)
        eventSubject.send(.parsed(route: route, url: url))
        
        // Call registered handler
        let routeKey = String(describing: route)
        handlers[routeKey]?(route, params)
        
        eventSubject.send(.handled(route: route))
        return true
    }
    
    /// Handles a deep link URL string.
    ///
    /// - Parameter urlString: The URL string to handle.
    /// - Returns: Whether the URL was successfully handled.
    @discardableResult
    public func handle(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            lastError = .malformedURL(urlString)
            return false
        }
        return handle(url)
    }
    
    /// Processes all pending deep links.
    public func processPending() {
        let pending = pendingLinks
        pendingLinks.removeAll()
        
        for url in pending {
            handle(url)
        }
    }
    
    /// Clears pending deep links.
    public func clearPending() {
        pendingLinks.removeAll()
    }
    
    /// Registers a handler for a specific route.
    ///
    /// - Parameters:
    ///   - route: The route to handle.
    ///   - handler: The handler closure.
    public func onRoute(_ route: R, handler: @escaping (R, [String: String]) -> Void) {
        let key = String(describing: route)
        handlers[key] = handler
    }
    
    /// Marks the handler as ready and processes pending links.
    public func setReady() {
        isReady = true
        processPending()
    }
}

// MARK: - Universal Link Support

/// A parser for universal links (HTTPS deep links).
public struct UniversalLinkParser<R: Route> {
    
    /// The associated domains for universal links.
    private let domains: Set<String>
    
    /// Path-based route mappings.
    private var pathMappings: [String: (URL) -> R?] = [:]
    
    /// Creates a universal link parser.
    ///
    /// - Parameter domains: The associated domains.
    public init(domains: Set<String>) {
        self.domains = domains
    }
    
    /// Registers a path mapping.
    ///
    /// - Parameters:
    ///   - path: The path pattern.
    ///   - factory: A closure that creates routes.
    public mutating func register(_ path: String, factory: @escaping (URL) -> R?) {
        pathMappings[path] = factory
    }
    
    /// Parses a universal link URL.
    ///
    /// - Parameter url: The URL to parse.
    /// - Returns: The parsed route, if successful.
    public func parse(_ url: URL) -> R? {
        guard url.scheme == "https" || url.scheme == "http" else { return nil }
        guard let host = url.host, domains.contains(host) else { return nil }
        
        // Try exact path match first
        if let factory = pathMappings[url.path] {
            return factory(url)
        }
        
        // Try pattern matching
        for (pattern, factory) in pathMappings {
            if matchesPattern(url.path, pattern: pattern) {
                return factory(url)
            }
        }
        
        return nil
    }
    
    private func matchesPattern(_ path: String, pattern: String) -> Bool {
        let pathComponents = path.split(separator: "/")
        let patternComponents = pattern.split(separator: "/")
        
        guard pathComponents.count == patternComponents.count else { return false }
        
        for (p, pat) in zip(pathComponents, patternComponents) {
            if pat.hasPrefix(":") { continue }
            if p != pat { return false }
        }
        
        return true
    }
}

// MARK: - App Clip Support

/// A parser for App Clip invocation URLs.
public struct AppClipLinkParser<R: Route> {
    
    /// The App Clip experience URL prefix.
    private let experienceURLPrefix: String
    
    /// Route factory.
    private let routeFactory: (URL, [String: String]) -> R?
    
    /// Creates an App Clip link parser.
    ///
    /// - Parameters:
    ///   - experienceURLPrefix: The URL prefix for the App Clip experience.
    ///   - routeFactory: A closure that creates routes from URLs.
    public init(
        experienceURLPrefix: String,
        routeFactory: @escaping (URL, [String: String]) -> R?
    ) {
        self.experienceURLPrefix = experienceURLPrefix
        self.routeFactory = routeFactory
    }
    
    /// Parses an App Clip invocation URL.
    ///
    /// - Parameter url: The URL to parse.
    /// - Returns: The parsed route, if successful.
    public func parse(_ url: URL) -> R? {
        guard url.absoluteString.hasPrefix(experienceURLPrefix) else { return nil }
        
        let params = DeepLinkParser<R>.queryParameters(from: url)
        return routeFactory(url, params)
    }
}

// MARK: - Shortcut Support

/// A handler for quick action shortcuts.
public struct ShortcutHandler<R: Route> {
    
    /// Shortcut type to route mappings.
    private var shortcuts: [String: R] = [:]
    
    /// Creates a shortcut handler.
    public init() {}
    
    /// Registers a shortcut.
    ///
    /// - Parameters:
    ///   - type: The shortcut type identifier.
    ///   - route: The route to navigate to.
    public mutating func register(_ type: String, route: R) {
        shortcuts[type] = route
    }
    
    /// Handles a shortcut action.
    ///
    /// - Parameter type: The shortcut type.
    /// - Returns: The route for the shortcut, if registered.
    public func handle(_ type: String) -> R? {
        shortcuts[type]
    }
}

// MARK: - Deferred Deep Link

/// A deep link that was deferred for later handling.
public struct DeferredDeepLink: Codable {
    /// The URL string.
    public let urlString: String
    /// When the link was received.
    public let receivedAt: Date
    /// When the link expires.
    public let expiresAt: Date?
    /// Additional context.
    public let context: [String: String]
    
    /// Creates a deferred deep link.
    public init(
        url: URL,
        receivedAt: Date = Date(),
        expiresAt: Date? = nil,
        context: [String: String] = [:]
    ) {
        self.urlString = url.absoluteString
        self.receivedAt = receivedAt
        self.expiresAt = expiresAt
        self.context = context
    }
    
    /// The URL, if valid.
    public var url: URL? {
        URL(string: urlString)
    }
    
    /// Whether the link has expired.
    public var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() > expiry
    }
}
