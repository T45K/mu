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

        expectLineLocation("line 1 starts at beginning", LineNavigator.location(ofLine: 1, in: "alpha\nbeta"), 0)
        expectLineLocation("line 2 starts after newline", LineNavigator.location(ofLine: 2, in: "alpha\nbeta"), 6)
        expectLineLocation("trailing newline creates empty line", LineNavigator.location(ofLine: 2, in: "alpha\n"), 6)
        expectLineLocation("CRLF is one line break", LineNavigator.location(ofLine: 2, in: "alpha\r\nbeta"), 7)
        expectLineLocation("line zero is invalid", LineNavigator.location(ofLine: 0, in: "alpha"), nil)
        expectLineLocation("line past end is invalid", LineNavigator.location(ofLine: 3, in: "alpha\nbeta"), nil)

        expectLineNumber("line number at beginning", LineNavigator.lineNumber(at: 0, in: "alpha\nbeta"), 1)
        expectLineNumber("line number after newline", LineNavigator.lineNumber(at: 6, in: "alpha\nbeta"), 2)
        expectLineNumber("line number clamps beyond end", LineNavigator.lineNumber(at: 99, in: "alpha\nbeta"), 2)

        expectLineCount("empty text has one line", LineNavigator.lineCount(in: ""), 1)
        expectLineCount("counts LF lines", LineNavigator.lineCount(in: "alpha\nbeta\ngamma"), 3)
        expectLineCount("counts CRLF lines", LineNavigator.lineCount(in: "alpha\r\nbeta"), 2)
        expectLineCount("trailing LF counts empty final line", LineNavigator.lineCount(in: "alpha\n"), 2)
        expectLineCount("trailing CRLF counts empty final line", LineNavigator.lineCount(in: "alpha\r\n"), 2)
        expectBoolean("detects trailing LF", LineNavigator.hasTrailingLineBreak(in: "alpha\n"), true)
        expectBoolean("detects trailing CRLF", LineNavigator.hasTrailingLineBreak(in: "alpha\r\n"), true)
        expectBoolean("detects no trailing line break", LineNavigator.hasTrailingLineBreak(in: "alpha"), false)

        if failures > 0 {
            exit(1)
        }
    }

    private static func expectLineLocation(_ name: String, _ actual: Int?, _ expected: Int?) {
        if actual != expected {
            print("FAIL: \(name): expected \(describe(expected)), got \(describe(actual))")
            exit(1)
        }
    }

    private static func expectLineNumber(_ name: String, _ actual: Int, _ expected: Int) {
        if actual != expected {
            print("FAIL: \(name): expected \(expected), got \(actual)")
            exit(1)
        }
    }

    private static func expectLineCount(_ name: String, _ actual: Int, _ expected: Int) {
        if actual != expected {
            print("FAIL: \(name): expected \(expected), got \(actual)")
            exit(1)
        }
    }

    private static func expectBoolean(_ name: String, _ actual: Bool, _ expected: Bool) {
        if actual != expected {
            print("FAIL: \(name): expected \(expected), got \(actual)")
            exit(1)
        }
    }

    private static func describe(_ range: NSRange?) -> String {
        guard let range else {
            return "nil"
        }

        return "{\(range.location), \(range.length)}"
    }

    private static func describe(_ value: Int?) -> String {
        guard let value else {
            return "nil"
        }

        return "\(value)"
    }
}