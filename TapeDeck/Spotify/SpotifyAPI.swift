import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

// Spotify, reached through its Web API. Casseti signs in with Spotify's own
// login page (PKCE, so no secret is kept in the app), reads the library and
// tells the Spotify app what to play. The audio is played by the Spotify app.

enum SpotifyConfig {
    /// The client ID of the Spotify developer app, set in the Info.plist.
    static var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
    static let redirectURI = "casseti://spotify-callback"
    static let callbackScheme = "casseti"
    static let scopes = [
        "user-read-playback-state", "user-modify-playback-state", "user-read-currently-playing",
        "playlist-read-private", "playlist-read-collaborative", "user-library-read",
        "user-follow-read", "user-read-private"
    ]
}

// MARK: Errors

struct SpotifyError: LocalizedError {
    enum Kind { case notSetUp, notSignedIn, cancelled, premiumRequired, noDevice, notOwnPlaylist, other }
    let kind: Kind
    var detail = ""

    var errorDescription: String? {
        switch kind {
        case .notSetUp: return "Spotify is not set up in this copy of Casseti yet."
        case .notSignedIn: return "Connect Spotify in Settings first."
        case .cancelled: return "Spotify was not connected."
        case .premiumRequired: return "Spotify only lets other apps start music on Premium accounts."
        case .noDevice: return "Spotify needs to be open. Casseti has opened it; come back and press play again."
        case .notOwnPlaylist: return "Spotify only shares the songs of playlists you made or collaborate on."
        case .other: return detail.isEmpty ? "Spotify did not answer." : detail
        }
    }
}

// MARK: What Spotify sends

struct SpotifyImage: Decodable, Hashable {
    let url: String
    let width: Int?
}

struct SpotifyArtistRef: Decodable, Hashable {
    let id: String?
    let name: String
}

struct SpotifyAlbumRef: Decodable, Hashable {
    let id: String
    let name: String
    let uri: String
    var images: [SpotifyImage]?
    var artists: [SpotifyArtistRef]?
    var releaseDate: String?
}

struct SpotifyTrack: Decodable, Hashable {
    let id: String?
    let name: String
    let uri: String
    let durationMs: Int
    var artists: [SpotifyArtistRef] = []
    var album: SpotifyAlbumRef?
    var isLocal: Bool?

    var artistLine: String { artists.map(\.name).joined(separator: ", ") }
    var duration: TimeInterval { Double(durationMs) / 1000 }
    /// The id the shelf picks a song by.
    var pickID: String { id ?? uri }

    enum CodingKeys: String, CodingKey { case id, name, uri, durationMs, artists, album, isLocal }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        uri = try c.decode(String.self, forKey: .uri)
        durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? 0
        artists = try c.decodeIfPresent([SpotifyArtistRef].self, forKey: .artists) ?? []
        album = try? c.decodeIfPresent(SpotifyAlbumRef.self, forKey: .album)
        isLocal = try c.decodeIfPresent(Bool.self, forKey: .isLocal)
    }
}

struct SpotifyArtist: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    var images: [SpotifyImage]?
}

struct SpotifyOwner: Decodable, Hashable {
    let id: String
    var displayName: String?
}

struct SpotifyPlaylist: Decodable, Hashable {
    let id: String
    let name: String
    let uri: String
    var images: [SpotifyImage]?
    let owner: SpotifyOwner
    var collaborative: Bool?
}

/// A list entry that is dropped, rather than failing the whole list, when
/// Spotify sends something Casseti cannot read (a podcast, a gap).
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct SpotifyPage<T: Decodable>: Decodable {
    let items: [Lossy<T>]
    let next: String?
    var values: [T] { items.compactMap(\.value) }
}

private struct SavedAlbum: Decodable { let album: SpotifyAlbumRef }
private struct SavedTrack: Decodable { let track: SpotifyTrack }
private struct PlaylistEntry: Decodable {
    let item: SpotifyTrack?
    let track: SpotifyTrack?
    enum CodingKeys: String, CodingKey { case item, track }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        item = try? c.decodeIfPresent(SpotifyTrack.self, forKey: .item)
        track = try? c.decodeIfPresent(SpotifyTrack.self, forKey: .track)
    }
}
private struct FollowedArtists: Decodable {
    struct Inner: Decodable { let items: [Lossy<SpotifyArtist>]; let next: String? }
    let artists: Inner
}
private struct SearchAnswer: Decodable {
    var artists: SpotifyPage<SpotifyArtist>?
    var albums: SpotifyPage<SpotifyAlbumRef>?
    var tracks: SpotifyPage<SpotifyTrack>?
}
private struct Me: Decodable { let id: String; var displayName: String? }

struct SpotifyDevice: Decodable {
    let id: String?
    let isActive: Bool
    let isRestricted: Bool?
    let name: String
    let type: String
}
private struct Devices: Decodable { let devices: [SpotifyDevice] }

struct SpotifyPlayerState: Decodable {
    var device: SpotifyDevice?
    let isPlaying: Bool
    var progressMs: Int?
    var item: SpotifyTrack?

    enum CodingKeys: String, CodingKey { case device, isPlaying, progressMs, item }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = try? c.decodeIfPresent(SpotifyDevice.self, forKey: .device)
        isPlaying = try c.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
        progressMs = try c.decodeIfPresent(Int.self, forKey: .progressMs)
        item = try? c.decodeIfPresent(SpotifyTrack.self, forKey: .item)
    }
}

/// What a search of Spotify found.
struct SpotifyFindings {
    var artists: [SpotifyArtist] = []
    var albums: [SpotifyAlbumRef] = []
    var tracks: [SpotifyTrack] = []
    var isEmpty: Bool { artists.isEmpty && albums.isEmpty && tracks.isEmpty }
}

// MARK: Sign-in and tokens

private struct SpotifyTokens: Codable {
    var access: String
    var refresh: String
    var expires: Date
}

/// Keeps the Spotify sign-in in the keychain.
private enum TokenStore {
    static let account = "spotify"
    static let service = "com.rogerseng.tapedeck.spotify"

    static func load() -> SpotifyTokens? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true]
        var found: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyTokens.self, from: data)
    }

    static func save(_ tokens: SpotifyTokens?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard let tokens, let data = try? JSONEncoder().encode(tokens) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Presents Spotify's login page over the app.
private final class LoginAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

@MainActor
final class SpotifyAPI {
    private var tokens = TokenStore.load()
    private var refreshing: Task<Void, Error>?
    private let anchor = LoginAnchor()
    private var loginSession: ASWebAuthenticationSession?
    private(set) var userID: String?

    var isSignedIn: Bool { tokens != nil }
    static var isSetUp: Bool { !SpotifyConfig.clientID.isEmpty }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: Signing in

    /// Opens Spotify's login page and keeps the sign-in it hands back.
    func signIn() async throws {
        guard Self.isSetUp else { throw SpotifyError(kind: .notSetUp) }
        let verifier = Self.randomString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = Self.randomString()
        var parts = URLComponents(string: "https://accounts.spotify.com/authorize")!
        parts.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: state),
            .init(name: "scope", value: SpotifyConfig.scopes.joined(separator: " "))
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: parts.url!, callbackURLScheme: SpotifyConfig.callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: SpotifyError(kind: .cancelled))
                }
                _ = error
            }
            session.presentationContextProvider = anchor
            loginSession = session
            session.start()
        }
        loginSession = nil
        let answer = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard answer.first(where: { $0.name == "state" })?.value == state,
              let code = answer.first(where: { $0.name == "code" })?.value else {
            throw SpotifyError(kind: .cancelled)
        }
        try await requestTokens([
            "grant_type": "authorization_code", "code": code,
            "redirect_uri": SpotifyConfig.redirectURI, "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier
        ])
        userID = nil
        _ = try? await currentUserID()
    }

    func signOut() {
        tokens = nil
        userID = nil
        TokenStore.save(nil)
    }

    private func requestTokens(_ form: [String: String]) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.map { "\($0.key)=\($0.value.formEncoded)" }
            .joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        struct Answer: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresIn: Double
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let answer = try? Self.decoder.decode(Answer.self, from: data) else {
            // A refused refresh means the sign-in has been withdrawn.
            if form["grant_type"] == "refresh_token" { signOut() }
            throw SpotifyError(kind: .notSignedIn)
        }
        let refresh = answer.refreshToken ?? tokens?.refresh ?? ""
        let fresh = SpotifyTokens(access: answer.accessToken, refresh: refresh,
                                  expires: Date().addingTimeInterval(answer.expiresIn - 60))
        tokens = fresh
        TokenStore.save(fresh)
    }

    /// A token that is good for at least another minute.
    private func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard let current = tokens else { throw SpotifyError(kind: .notSignedIn) }
        if !forceRefresh, current.expires > Date() { return current.access }
        if let refreshing {
            try await refreshing.value
        } else {
            let task = Task { [self] in
                try await requestTokens(["grant_type": "refresh_token", "refresh_token": current.refresh,
                                         "client_id": SpotifyConfig.clientID])
            }
            refreshing = task
            defer { refreshing = nil }
            try await task.value
        }
        guard let token = tokens?.access else { throw SpotifyError(kind: .notSignedIn) }
        return token
    }

    // MARK: Requests

    /// Sends a request. `path` is either a path under /v1 or a whole URL from
    /// a `next` link. Returns the body, or nil when there is none.
    @discardableResult
    func call(_ method: String = "GET", _ path: String, query: [String: String] = [:],
              body: [String: Any]? = nil) async throws -> Data? {
        var parts = URLComponents(string: path.hasPrefix("https://") ? path : "https://api.spotify.com/v1\(path)")!
        if !query.isEmpty {
            parts.queryItems = (parts.queryItems ?? []) + query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var attempt = 0
        var forceRefresh = false
        while true {
            attempt += 1
            var request = URLRequest(url: parts.url!)
            request.httpMethod = method
            request.timeoutInterval = 15
            request.setValue("Bearer \(try await accessToken(forceRefresh: forceRefresh))", forHTTPHeaderField: "Authorization")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } else if method != "GET" {
                request.httpBody = Data()
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300:
                return data.isEmpty ? nil : data
            case 401 where attempt == 1:
                forceRefresh = true
                continue
            case 429 where attempt <= 2:
                let wait = Double((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
                try await Task.sleep(nanoseconds: UInt64(min(wait, 5) * 1_000_000_000))
                continue
            default:
                throw Self.failure(status: status, data: data)
            }
        }
    }

    private static func failure(status: Int, data: Data) -> SpotifyError {
        struct Body: Decodable {
            struct Inner: Decodable { let message: String?; let reason: String? }
            let error: Inner
        }
        let inner = (try? decoder.decode(Body.self, from: data))?.error
        if inner?.reason == "PREMIUM_REQUIRED" { return SpotifyError(kind: .premiumRequired) }
        if inner?.reason == "NO_ACTIVE_DEVICE" || status == 404 && (inner?.message ?? "").contains("device") {
            return SpotifyError(kind: .noDevice)
        }
        if status == 401 { return SpotifyError(kind: .notSignedIn) }
        if status == 403, inner?.message?.localizedCaseInsensitiveContains("premium") == true {
            return SpotifyError(kind: .premiumRequired)
        }
        return SpotifyError(kind: .other, detail: inner?.message.map { "Spotify said: \($0)." } ?? "Spotify answered with an error (\(status)).")
    }

    func get<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:]) async throws -> T {
        guard let data = try await call("GET", path, query: query) else {
            throw SpotifyError(kind: .other, detail: "Spotify sent nothing back.")
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Every page of a list, up to `limit` items.
    func all<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:], limit: Int = 500) async throws -> [T] {
        var page = try await get(SpotifyPage<T>.self, path, query: query.merging(["limit": "50"]) { a, _ in a })
        var found = page.values
        while let next = page.next, found.count < limit {
            page = try await get(SpotifyPage<T>.self, next)
            found += page.values
        }
        return Array(found.prefix(limit))
    }

    // MARK: The library

    func currentUserID() async throws -> String {
        if let userID { return userID }
        let me = try await get(Me.self, "/me")
        userID = me.id
        return me.id
    }

    /// The playlists Spotify will play for Casseti: ones you made or collaborate on.
    func playlists() async throws -> [SpotifyPlaylist] {
        let me = try await currentUserID()
        let all = try await all(SpotifyPlaylist.self, "/me/playlists")
        return all.filter { $0.owner.id == me || $0.collaborative == true }
    }

    func savedAlbums() async throws -> [SpotifyAlbumRef] {
        try await all(SavedAlbum.self, "/me/albums").map(\.album)
    }

    func savedTracks(limit: Int = 500) async throws -> [SpotifyTrack] {
        try await all(SavedTrack.self, "/me/tracks", limit: limit).map(\.track)
    }

    func followedArtists() async throws -> [SpotifyArtist] {
        var answer = try await get(FollowedArtists.self, "/me/following", query: ["type": "artist", "limit": "50"])
        var found = answer.artists.items.compactMap(\.value)
        while let next = answer.artists.next, found.count < 500 {
            answer = try await get(FollowedArtists.self, next)
            found += answer.artists.items.compactMap(\.value)
        }
        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func artistAlbums(_ id: String) async throws -> [SpotifyAlbumRef] {
        let albums = try await all(SpotifyAlbumRef.self, "/artists/\(id)/albums",
                                   query: ["include_groups": "album,single"], limit: 200)
        return albums.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
    }

    /// The songs of an album, each told which album it is from.
    func albumTracks(_ album: SpotifyAlbumRef, limit: Int) async throws -> [SpotifyTrack] {
        var tracks = try await all(SpotifyTrack.self, "/albums/\(album.id)/tracks", limit: limit)
        for index in tracks.indices where tracks[index].album == nil { tracks[index].album = album }
        return tracks
    }

    func playlistTracks(_ id: String, limit: Int) async throws -> [SpotifyTrack] {
        do {
            let entries = try await all(PlaylistEntry.self, "/playlists/\(id)/items", limit: limit)
            return entries.compactMap { $0.item ?? $0.track }.filter { $0.isLocal != true }
        } catch let error as SpotifyError where error.kind == .other {
            throw SpotifyError(kind: .notOwnPlaylist)
        }
    }

    func search(_ term: String) async throws -> SpotifyFindings {
        let answer = try await get(SearchAnswer.self, "/search",
                                   query: ["q": term, "type": "artist,album,track", "limit": "10"])
        return SpotifyFindings(artists: answer.artists?.values ?? [], albums: answer.albums?.values ?? [],
                               tracks: answer.tracks?.values ?? [])
    }

    // MARK: Playback

    func playerState() async throws -> SpotifyPlayerState? {
        guard let data = try await call("GET", "/me/player") else { return nil }
        return try Self.decoder.decode(SpotifyPlayerState.self, from: data)
    }

    func devices() async throws -> [SpotifyDevice] {
        try await get(Devices.self, "/me/player/devices").devices
    }

    // MARK: Helpers

    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

extension Array where Element == SpotifyImage {
    /// The picture nearest a size, in points, on this screen.
    func best(for points: CGFloat) -> URL? {
        let wanted = Int(points * 3)
        let sorted = self.sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        let pick = sorted.first { ($0.width ?? 0) >= wanted } ?? sorted.last
        return pick.flatMap { URL(string: $0.url) }
    }
}
