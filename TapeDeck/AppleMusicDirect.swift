import Foundation
import MusicKit

/// Asks the Apple Music web service directly for things MusicKit's own
/// requests usually fetch. Those requests have been seen to come back with
/// an empty reply that cannot be read; when one does, the same question is
/// asked here, and the answer read by hand.
enum AppleMusicDirect {
    /// One page of a list, and where the next page is.
    private struct Page<Item: MusicItem & Decodable>: Decodable {
        var data: [Item]
        var next: String?
    }

    /// Every item of a list in the catalogue, following its pages.
    static func list<Item: MusicItem & Decodable>(_ path: String, limit: Int = 100,
                                                  most: Int = 2000) async throws -> [Item] {
        let country = try await MusicDataRequest.currentCountryCode
        var next: String? = "/v1/catalog/\(country)/\(path)?limit=\(limit)"
        var all: [Item] = []
        while let path = next, all.count < most,
              let url = URL(string: "https://api.music.apple.com" + path) {
            let response = try await reply(from: url)
            let page = try JSONDecoder().decode(Page<Item>.self, from: response.data)
            all += page.data
            next = page.data.isEmpty ? nil : page.next
        }
        return all
    }

    /// Asks for a page, and asks again if the answer fails or comes back
    /// with nothing in it: the service does that now and then, and a
    /// second try a moment later usually gets through.
    static func reply(from url: URL, tries: Int = 3) async throws -> MusicDataResponse {
        var failure: Error = URLError(.badServerResponse)
        for attempt in 0..<tries {
            if attempt > 0 { try await Task.sleep(nanoseconds: 450_000_000) }
            do {
                let response = try await MusicDataRequest(urlRequest: URLRequest(url: url)).response()
                if !response.data.isEmpty { return response }
                failure = SearchFindings.EmptyReply(status: response.urlResponse.statusCode, url: url.absoluteString)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failure = error
            }
        }
        throw failure
    }

    /// Library items have ids of their own ("l.", "p.", "i." and a code);
    /// only catalogue ids can be asked of the web service this way.
    static func isCatalog(_ id: MusicItemID) -> Bool {
        let raw = id.rawValue
        return raw.hasPrefix("pl.") || raw.allSatisfy(\.isNumber)
    }
}

extension PlayerModel {
    /// All the tracks of an album, by MusicKit's request or, failing that,
    /// straight from the web service.
    static func allTracks(of album: Album) async throws -> [Track] {
        do {
            return try await everything(in: album.with([.tracks]).tracks)
        } catch {
            guard AppleMusicDirect.isCatalog(album.id),
                  let tracks: [Track] = try? await AppleMusicDirect.list("albums/\(album.id.rawValue)/tracks"),
                  !tracks.isEmpty else { throw error }
            return tracks
        }
    }

    static func allTracks(of playlist: Playlist) async throws -> [Track] {
        do {
            return try await everything(in: playlist.with([.tracks]).tracks)
        } catch {
            guard AppleMusicDirect.isCatalog(playlist.id),
                  let tracks: [Track] = try? await AppleMusicDirect.list("playlists/\(playlist.id.rawValue)/tracks"),
                  !tracks.isEmpty else { throw error }
            return tracks
        }
    }

    /// An artist's albums, by MusicKit's request or, failing that, straight
    /// from the web service.
    static func albums(of artist: Artist, source: MusicPropertySource) async throws -> [Album] {
        do {
            return Array(try await artist.with([.albums], preferredSource: source).albums ?? [])
        } catch {
            guard AppleMusicDirect.isCatalog(artist.id),
                  let albums: [Album] = try? await AppleMusicDirect.list("artists/\(artist.id.rawValue)/albums", most: 300),
                  !albums.isEmpty else { throw error }
            return albums
        }
    }
}
