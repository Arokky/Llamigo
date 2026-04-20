import Foundation

enum Logging {
  #if DEBUG
    static let subsystem = "app.llamigo.Llamigo.dev"
  #else
    static let subsystem = "app.llamigo.Llamigo"
  #endif
}
