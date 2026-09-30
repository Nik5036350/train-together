import Testing
@testable import TrainTogether

struct SyncSettingsTests {
    @Test func serverURLsAreNormalized() {
        #expect(SyncSettingsStore.normalizedURL("gym.example.com")?.absoluteString == "https://gym.example.com")
        #expect(SyncSettingsStore.normalizedURL(" https://gym.example.com/ ")?.absoluteString == "https://gym.example.com")
        #expect(SyncSettingsStore.normalizedURL("http://localhost:8080")?.absoluteString == "http://localhost:8080")
        #expect(SyncSettingsStore.normalizedURL("") == nil)
        #expect(SyncSettingsStore.normalizedURL("https://") == nil)
    }
}
