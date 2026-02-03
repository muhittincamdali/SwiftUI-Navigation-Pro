import Foundation

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
}
