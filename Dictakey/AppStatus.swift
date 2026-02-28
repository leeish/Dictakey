import Observation

@Observable
class AppStatus {
    static let shared = AppStatus()
    var icon: String = "⏳"
    var tooltip: String = "Dictakey: Loading model..."
    /// Non-nil while a model is downloading (0–1). Nil when idle or loading from cache.
    var downloadProgress: Double? = nil
}
