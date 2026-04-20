import Foundation

#if canImport(Sentry)
import Sentry
#endif

enum ErrorReporting {
  static func startIfAvailable(releaseName: String, environment: String) {
    #if canImport(Sentry) && !DEBUG
      SentrySDK.start { options in
        options.dsn =
          "https://9a490c1c8715f73a0db5f65890165602@o509420.ingest.us.sentry.io/4510221602914304"
        options.debug = false
        options.releaseName = releaseName
        options.environment = environment

        options.enableCaptureFailedRequests = false
        options.beforeSend = { event in
          if let error = event.error as NSError? {
            let ignoredCodes = [
              NSURLErrorCancelled,
              NSURLErrorNotConnectedToInternet,
              NSURLErrorNetworkConnectionLost,
            ]
            if error.domain == NSURLErrorDomain && ignoredCodes.contains(error.code) {
              return nil
            }
          }
          return event
        }
      }
    #endif
  }

  static func capture(error: Error) {
    #if canImport(Sentry)
      SentrySDK.capture(error: error)
    #endif
  }
}
