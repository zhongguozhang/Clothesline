import AppKit

@MainActor
func testMissionControlReplay() throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/mission-control-macos27.json"))
    let fixture = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let screens = (fixture["screens"] as! [[CGFloat]]).map {
        CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3])
    }
    let expected = fixture["expectedClearance"] as! [CGFloat]
    let owners: [pid_t: MissionControlAvoidance.Owner] = [42: .dock, 43: .windowManager]
    for phase in ["idle", "active", "idle"] {
        let windows = MissionControlAvoidance.systemWindows(in: fixture[phase] as! [[String: Any]], owners: owners)
        for (index, screen) in screens.enumerated() {
            let clearance = MissionControlAvoidance.clearance(for: screen, windows: windows)
            let target = phase == "active" ? expected[index] : 0
            guard clearance == target else {
                print("FAIL: captured macOS 27 \(phase), display \(index): expected \(target), got \(clearance)")
                throw NSError(domain: "MissionControlReplay", code: 1)
            }
        }
    }
    print("PASS: captured macOS 27 overview entry/exit, actual Spaces bar heights and both displays")
}
