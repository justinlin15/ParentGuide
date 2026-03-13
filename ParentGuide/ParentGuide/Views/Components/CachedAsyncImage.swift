import SwiftUI
import CryptoKit

// MARK: - ImageCache

/// A lightweight image cache that checks memory (NSCache) first, then disk (Caches directory).
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()

    private let diskCacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("image-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let ioQueue = DispatchQueue(label: "com.parentguide.imagecache.io", qos: .utility)

    private init() {}

    // MARK: - Public API

    /// Returns a cached image for the given URL, checking memory then disk.
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Disk cache
        let filePath = diskCacheURL.appendingPathComponent(key)
        if let diskImage = await loadFromDisk(at: filePath) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        return nil
    }

    /// Stores an image in both memory and disk caches.
    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(image, forKey: key as NSString)

        let filePath = diskCacheURL.appendingPathComponent(key)
        ioQueue.async {
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: filePath, options: .atomic)
            }
        }
    }

    // MARK: - Helpers

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk(at url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - CachedAsyncImage

/// A drop-in replacement for AsyncImage that adds memory and disk caching.
///
/// Usage:
/// ```
/// CachedAsyncImage(url: imageURL) {
///     ProgressView()
/// }
/// ```
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var loadFailed = false
    @State private var isLoading = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }

        // Reset state for new URL
        uiImage = nil
        loadFailed = false
        isLoading = true
        defer { isLoading = false }

        let cache = ImageCache.shared

        // 1. Check caches (memory then disk)
        if let cached = await cache.image(for: url) {
            uiImage = cached
            return
        }

        // 2. Network fetch
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let downloaded = UIImage(data: data) else {
                loadFailed = true
                return
            }
            cache.store(downloaded, for: url)
            uiImage = downloaded
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Phase-based CachedAsyncImage

/// A phase-based variant that mirrors SwiftUI's `AsyncImage(url:) { phase in ... }` API.
///
/// Usage:
/// ```
/// CachedAsyncImage(url: imageURL) { phase in
///     switch phase {
///     case .success(let image):
///         image.resizable()
///     default:
///         placeholder
///     }
///  }
/// ```
struct CachedAsyncImagePhase<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty
    @State private var isLoading = false

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url, !isLoading else {
            phase = .empty
            return
        }

        phase = .empty
        isLoading = true
        defer { isLoading = false }

        let cache = ImageCache.shared

        // 1. Check caches (memory then disk)
        if let cached = await cache.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        // 2. Network fetch
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let downloaded = UIImage(data: data) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            cache.store(downloaded, for: url)
            phase = .success(Image(uiImage: downloaded))
        } catch {
            phase = .failure(error)
        }
    }
}
