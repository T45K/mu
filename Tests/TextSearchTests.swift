import Foundation

@main
struct TextSearchTests {
    static func main() {
        var failures = 0

        func expect(_ name: String, _ actual: NSRange?, _ expected: NSRange?) {
            if actual != expected {
                failures += 1
                print("FAIL: \(name): expected \(describe(expected)), got \(describe(actual))")
            }
        }

        expect(
            "forward search starts at cursor",
            TextSearch.match(
                in: "alpha beta alpha",
                query: "beta",
                from: NSRange(location: 0, length: 0),
                direction: .forward
            ),
            NSRange(location: 6, length: 4)
        )

        expect(
            "forward search skips current selection",
            TextSearch.match(
                in: "alpha beta alpha",
                query: "alpha",
                from: NSRange(location: 0, length: 5),
                direction: .forward
            ),
            NSRange(location: 11, length: 5)
        )

        expect(
            "forward search wraps to beginning",
            TextSearch.match(
                in: "alpha beta alpha",
                query: "alpha",
                from: NSRange(location: 16, length: 0),
                direction: .forward
            ),
            NSRange(location: 0, length: 5)
        )

        expect(
            "backward search starts before selection",
            TextSearch.match(
                in: "alpha beta alpha",
                query: "alpha",
                from: NSRange(location: 11, length: 5),
                direction: .backward
            ),
            NSRange(location: 0, length: 5)
        )

        expect(
            "backward search wraps to end",
            TextSearch.match(
                in: "alpha beta alpha",
                query: "alpha",
                from: NSRange(location: 0, length: 0),
                direction: .backward
            ),
            NSRange(location: 11, length: 5)
        )

        expect(
            "search is case insensitive",
            TextSearch.match(
                in: "Alpha beta",
                query: "alpha",
                from: NSRange(location: 0, length: 0),
                direction: .forward
            ),
            NSRange(location: 0, length: 5)
        )

        expect(
            "empty query has no match",
            TextSearch.match(
                in: "alpha",
                query: "",
                from: NSRange(location: 0, length: 0),
                direction: .forward
            ),
            nil
        )

        expect(
            "missing query has no match",
            TextSearch.match(
                in: "alpha",
                query: "gamma",
                from: NSRange(location: 0, length: 0),
                direction: .forward
            ),
            nil
        )

        if failures > 0 {
            exit(1)
        }
    }

    private static func describe(_ range: NSRange?) -> String {
        guard let range else {
            return "nil"
        }

        return "{\(range.location), \(range.length)}"
    }
}