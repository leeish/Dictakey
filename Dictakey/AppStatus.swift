import Observation

@Observable
class AppStatus {
    static let shared = AppStatus()
    var icon: String = "⏳"
    var tooltip: String = "Dictakey: Loading model..."
}
