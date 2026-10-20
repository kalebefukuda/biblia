import Testing
@testable import Biblia

struct SmokeTests {
    @Test func appTabsExist() {
        #expect(AppTab.ler != AppTab.ajustes)
    }
}
