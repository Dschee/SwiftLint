import Foundation
import SourceKittenFramework

public struct MultilineLiteralBracketsRule: ASTRule, OptInRule, ConfigurationProviderRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "multiline_literal_brackets",
        name: "Multiline Literal Brackets",
        description: "Multiline literals should have their surrounding brackets in a new line.",
        kind: .style,
        nonTriggeringExamples: [
            """
            let trio = ["harry", "ronald", "hermione"]
            let houseCup = ["gryffinder": 460, "hufflepuff": 370, "ravenclaw": 410, "slytherin": 450]
            """,
            """
            let trio = [
                "harry",
                "ronald",
                "hermione"
            ]
            let houseCup = [
                "gryffinder": 460,
                "hufflepuff": 370,
                "ravenclaw": 410,
                "slytherin": 450
            ]
            """,
            """
            let trio = [
                "harry", "ronald", "hermione"
            ]
            let houseCup = [
                "gryffinder": 460, "hufflepuff": 370,
                "ravenclaw": 410, "slytherin": 450
            ]
            """,
            """
                _ = [
                    1,
                    2,
                    3,
                    4,
                    5, 6,
                    7, 8, 9
                ]
            """
        ],
        triggeringExamples: [
            """
            let trio = [↓"harry",
                        "ronald",
                        "hermione"
            ]
            """,
            """
            let houseCup = [↓"gryffinder": 460, "hufflepuff": 370,
                            "ravenclaw": 410, "slytherin": 450
            ]
            """,
            """
            let trio = [
                "harry",
                "ronald",
                "hermione"↓]
            """,
            """
            let houseCup = [
                "gryffinder": 460, "hufflepuff": 370,
                "ravenclaw": 410, "slytherin": 450↓]
            """,
            """
            class Hogwarts {
                let houseCup = [
                    "gryffinder": 460, "hufflepuff": 370,
                    "ravenclaw": 410, "slytherin": 450↓]
            }
            """,
            """
                _ = [
                    1,
                    2,
                    3,
                    4,
                    5, 6,
                    7, 8, 9↓]
            """,
            """
                _ = [↓1, 2, 3,
                     4, 5, 6,
                     7, 8, 9
                ]
            """
        ]
    )

    public func validate(file: File,
                         kind: SwiftExpressionKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        var violations = [StyleViolation]()

        guard
            kind == .array || kind == .dictionary,
            let bodyOffset = dictionary.bodyOffset,
            let bodyLength = dictionary.bodyLength,
            let range = file.contents.bridge().byteRangeToNSRange(start: bodyOffset, length: bodyLength)
        else {
            return []
        }

        let body = file.contents.substring(from: range.location, length: range.length)
        let isMultiline = body.contains("\n")

        let expectedBodyBeginRegex = regex("\\A[ \\t]*\\n")
        let expectedBodyEndRegex = regex("\\n[ \\t]*\\z")

        if isMultiline {
            if expectedBodyBeginRegex.firstMatch(in: body, options: [], range: body.fullNSRange) == nil {
                violations.append(StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severity,
                    location: Location(file: file, byteOffset: bodyOffset)
                ))
            }

            if expectedBodyEndRegex.firstMatch(in: body, options: [], range: body.fullNSRange) == nil {
                violations.append(StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severity,
                    location: Location(file: file, byteOffset: bodyOffset + bodyLength)
                ))
            }
        }

        return violations
    }
}
