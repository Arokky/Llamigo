import Foundation

enum ModelStorageSource: String {
  case legacy
  case hfCache
  case externalFolder
}

/// Resolved file paths for a downloaded model.
/// Separates "what is this model" (CatalogEntry) from "where is it on disk".
struct ResolvedPaths {
  /// Absolute path to the main model file
  let modelFile: String
  /// Absolute paths to additional shard files (multi-part models)
  let additionalParts: [String]
  /// Absolute path to the mmproj file (vision models), nil if not applicable
  let mmprojFile: String?
  /// Where this model is stored.
  let source: ModelStorageSource
  /// HF cache repo directory name (e.g. "models--bartowski--Llama-3.2-1B-Instruct-GGUF").
  /// Set for sideloaded models discovered in the cache; nil for catalog models
  /// (which derive it from their download URL). Used for deletion.
  let hfRepoDirName: String?

  init(
    modelFile: String,
    additionalParts: [String],
    mmprojFile: String?,
    source: ModelStorageSource,
    hfRepoDirName: String? = nil
  ) {
    self.modelFile = modelFile
    self.additionalParts = additionalParts
    self.mmprojFile = mmprojFile
    self.source = source
    self.hfRepoDirName = hfRepoDirName
  }

  var isLegacy: Bool {
    source == .legacy
  }

  var isExternalFolder: Bool {
    source == .externalFolder
  }

  /// All file paths this model occupies on disk
  var allPaths: [String] {
    var paths = [modelFile]
    paths.append(contentsOf: additionalParts)
    if let mmproj = mmprojFile {
      paths.append(mmproj)
    }
    return paths
  }
}
