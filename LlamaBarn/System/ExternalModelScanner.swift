import Foundation

enum ExternalModelScanner {
  static func scan(folder: URL) -> [(entry: CatalogEntry, paths: ResolvedPaths)] {
    let fm = FileManager.default
    var results: [(entry: CatalogEntry, paths: ResolvedPaths)] = []
    var seenIds: Set<String> = []

    guard fm.fileExists(atPath: folder.path) else { return results }

    let enumerator = fm.enumerator(
      at: folder,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )

    var ggufFiles: [URL] = []
    while let item = enumerator?.nextObject() as? URL {
      let values = try? item.resourceValues(forKeys: [.isRegularFileKey])
      guard values?.isRegularFile == true else { continue }

      let lower = item.lastPathComponent.lowercased()
      guard lower.hasSuffix(".gguf"), !lower.hasPrefix("mmproj") else { continue }
      ggufFiles.append(item)
    }

    var shardGroups: [String: [URL]] = [:]
    var standalone: [URL] = []

    for file in ggufFiles {
      let relative = file.path.replacingOccurrences(of: folder.path + "/", with: "")
      if HFRepoParser.isSplitShard(relative), let baseName = HFRepoParser.splitShardBaseName(relative)
      {
        shardGroups[baseName, default: []].append(file)
      } else {
        standalone.append(file)
      }
    }

    for file in standalone.sorted(by: { $0.path < $1.path }) {
      if let result = buildEntry(mainFile: file, shardFiles: nil, folder: folder),
        seenIds.insert(result.entry.id).inserted
      {
        results.append(result)
      }
    }

    for (_, shardFiles) in shardGroups {
      let sorted = shardFiles.sorted(by: { $0.path < $1.path })
      guard let first = sorted.first else { continue }
      let relative = first.path.replacingOccurrences(of: folder.path + "/", with: "")
      guard HFRepoParser.isFirstShard(relative) else { continue }

      if let result = buildEntry(mainFile: first, shardFiles: sorted, folder: folder),
        seenIds.insert(result.entry.id).inserted
      {
        results.append(result)
      }
    }

    return results.sorted { CatalogEntry.displayOrder($0.entry, $1.entry) }
  }

  private static func buildEntry(
    mainFile: URL,
    shardFiles: [URL]?,
    folder: URL
  ) -> (entry: CatalogEntry, paths: ResolvedPaths)? {
    let allFiles = shardFiles ?? [mainFile]
    let mainFilename = mainFile.lastPathComponent
    let quant = HFRepoParser.parseQuant(filename: mainFilename) ?? "unknown"
    let displayName = prettyDisplayName(from: mainFilename, quant: quant)
    let family = displayName.isEmpty ? mainFilename : displayName
    let sizeLabel = quant == "unknown" ? "GGUF" : quant
    let totalFileSize = allFiles.reduce(Int64(0)) { sum, url in
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
      return sum + ((attrs?[.size] as? NSNumber)?.int64Value ?? 0)
    }

    let relativePath = mainFile.path.replacingOccurrences(of: folder.path + "/", with: "")
    let stableBase = relativePath
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "/", with: "--")
    let modelId = "external/\(stableBase)"

    let entry = CatalogEntry(
      id: modelId,
      family: family,
      parameterCount: 0,
      size: sizeLabel,
      ctxWindow: 131_072,
      fileSize: totalFileSize,
      ctxBytesPer1kTokens: 0,
      downloadUrl: URL(fileURLWithPath: mainFile.path),
      serverArgs: [],
      icon: "sideloaded",
      quantization: quant,
      isFullPrecision: false,
      isSideloaded: true,
      org: "local",
      tags: ["external"]
    )

    let paths = ResolvedPaths(
      modelFile: mainFile.path,
      additionalParts: Array((shardFiles ?? []).dropFirst()).map(\.path),
      mmprojFile: nil,
      source: .externalFolder
    )

    return (entry: entry, paths: paths)
  }

  private static func prettyDisplayName(from filename: String, quant: String) -> String {
    var base = filename
    if base.lowercased().hasSuffix(".gguf") {
      base.removeLast(5)
    }

    if HFRepoParser.isSplitShard(filename), let shardBase = HFRepoParser.splitShardBaseName(filename) {
      base = shardBase
    }

    if quant != "unknown" {
      let suffix = "-\(quant)"
      if base.uppercased().hasSuffix(suffix.uppercased()) {
        base = String(base.dropLast(suffix.count))
      }
    }

    return base
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
