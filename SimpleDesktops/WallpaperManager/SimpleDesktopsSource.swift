//
//  SimpleDesktopsSource.swift
//  SimpleDesktops
//
//  Created by Jiaxin Shou on 2020/1/30.
//  Copyright © 2020 Jiaxin Shou. All rights reserved.
//

import Cocoa
import SwiftSoup

class SimpleDesktopsSource: WallpaperImageSource {
    public class SDImage: WallpaperImage {
        var fullUrl: URL? {
            get {
                guard let lastComponent = previewUrl?.lastPathComponent,
                    let re = try? NSRegularExpression(pattern: "^.+\\.[a-z]{2,4}\\.", options: .caseInsensitive),
                    let range = re.matches(in: lastComponent, options: .anchored, range: NSRange(location: 0, length: lastComponent.count)).first?.range else {
                    return nil
                }

                let imageName = String(lastComponent[Range(range, in: lastComponent)!].dropLast())
                return previewUrl?.deletingLastPathComponent().appendingPathComponent(imageName)
            }
            set {}
        }

        var name: String? {
            get {
                guard let components = fullUrl?.pathComponents,
                    let index = components.firstIndex(of: "desktops") else {
                    return nil
                }

                return components[(index + 1)...].joined(separator: "-")
            }
            set {}
        }

        var previewUrl: URL?

        func download(to path: URL, completionHandler: @escaping (Error?) -> Void) {
            if let link = fullUrl {
                WallpaperImageLoader.shared.downloadImage(from: link.absoluteString, to: path, completionHandler: completionHandler)
            }
        }

        func fullImage(completionHandler: @escaping (NSImage?, Error?) -> Void) {
            if let link = fullUrl {
                WallpaperImageLoader.shared.fetchImage(from: link.absoluteString, completionHandler: completionHandler)
            }
        }

        func previewImage(completionHandler: @escaping (NSImage?, Error?) -> Void) {
            if let link = previewUrl {
                WallpaperImageLoader.shared.fetchImage(from: link.absoluteString, completionHandler: completionHandler)
            }
        }
    }

    var entity: HistoryImageEntity = HistoryImageEntity(name: "SDImage")

    var images: [WallpaperImage] = []

    init() {
        // Load history images to array
        for object in HistoryImageManager.shared.retrieveAll(fromEntity: entity, timeAscending: false) {
            if let url = object.value(forKey: entity.property.previewUrl) as? URL {
                let image = SDImage()
                image.previewUrl = url
                images.append(image)
            }
        }

        SimpleDesktopsSource.updateMaxPage()
    }

    func removeImage(at index: Int) -> WallpaperImage {
        if let imageName = images[index].name, let object = HistoryImageManager.shared.retrieve(byName: imageName, fromEntity: entity) {
            HistoryImageManager.shared.managedObjectContext.delete(object)
            try? HistoryImageManager.shared.managedObjectContext.save()
        }

        return images.remove(at: index)
    }

    func updateImage() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)

        var links: [String] = []
        var success = false

        let page = Int.random(in: 1 ... Options.shared.simpleDesktopsMaxPage)
        let url = URL(string: "http://simpledesktops.com/browse/\(page)/")!
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: url) { data, _, error in
            if error != nil {
                semaphore.signal()
                return
            }

            if let doc = try? SwiftSoup.parse(String(data: data!, encoding: .utf8)!), let imgTags = try? doc.select("img") {
                for tag in imgTags {
                    try? links.append(tag.attr("src"))
                }
            }

            if let link = links.randomElement() {
                let image = SDImage()
                image.previewUrl = URL(string: link)

                // The image is already loaded, remove it first to avoid duplicates
                if let index = self.images.firstIndex(where: { $0.name == image.name }) {
                    _ = self.removeImage(at: index)
                }

                self.images.insert(image, at: self.images.startIndex)
                HistoryImageManager.shared.insert(image, toEntity: self.entity)

                success = true
            }

//            while !links.isEmpty {
//                let index = Int.random(in: links.startIndex ..< links.endIndex)
//                let image = SDImage()
//                image.previewLink = links[index]
//
//                // Check if duplicate
//                if self.images.contains(where: { $0.name == image.name }) {
//                    links.remove(at: index)
//                } else {
//                    self.images.insert(image, at: self.images.startIndex)
//                    self.addToDatabase(image: image)
//
//                    success = true
//                    break
//                }
//            }

            semaphore.signal()
        }

        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)

        return success
    }

    // MARK: Private Methods

    /// Return true if the page contains images
    /// - Parameter page: Number of the page to be checked
    private static func isPageAvailable(page: Int) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)

        var isAvailable = false

        let url = URL(string: "http://simpledesktops.com/browse/\(page)/")!
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: url) { data, _, error in
            if error != nil {
                semaphore.signal()
                return
            }

            if let doc = try? SwiftSoup.parse(String(data: data!, encoding: .utf8)!), let imgTags = try? doc.select("img"), imgTags.count > 0 {
                isAvailable = true
            }

            semaphore.signal()
        }

        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)

        return isAvailable
    }

    /// Update max page number for Simple Desktops
    private static func updateMaxPage() {
        let queue = DispatchQueue(label: "SimpleDesktopsSource.updateMaxPage")
        queue.async {
            while isPageAvailable(page: Options.shared.simpleDesktopsMaxPage + 1) {
                Options.shared.simpleDesktopsMaxPage += 1
            }

            Options.shared.saveOptions()
        }
    }
}
