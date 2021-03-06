import Foundation
import SourceKittenFramework

public struct TypeContentsOrderRule: ConfigurationProviderRule, OptInRule {
    private typealias TypeContentOffset = (typeContent: TypeContent, offset: Int)

    public var configuration = TypeContentsOrderConfiguration()

    public init() {}

    public static let description = RuleDescription(
        identifier: "type_contents_order",
        name: "Type Contents Order",
        description: "Specifies the order of subtypes, properties, methods & more within a type.",
        kind: .style,
        nonTriggeringExamples: TypeContentsOrderRuleExamples.nonTriggeringExamples,
        triggeringExamples: TypeContentsOrderRuleExamples.triggeringExamples
    )

    public func validate(file: File) -> [StyleViolation] {
        let substructures = file.structure.dictionary.substructure
        return substructures.reduce([StyleViolation]()) { violations, substructure -> [StyleViolation] in
            return violations + validateTypeSubstructure(substructure, in: file)
        }
    }

    private func validateTypeSubstructure(
        _ substructure: [String: SourceKitRepresentable],
        in file: File
    ) -> [StyleViolation] {
        let typeContentOffsets = self.typeContentOffsets(in: substructure)
        let orderedTypeContentOffsets = typeContentOffsets.sorted { lhs, rhs in lhs.offset < rhs.offset }

        var violations =  [StyleViolation]()

        var lastMatchingIndex = -1
        print(configuration.order)
        for expectedTypesContents in configuration.order {
            var potentialViolatingIndexes = [Int]()

            let startIndex = lastMatchingIndex + 1
            (startIndex..<orderedTypeContentOffsets.count).forEach { index in
                let typeContent = orderedTypeContentOffsets[index].typeContent

                if expectedTypesContents.contains(typeContent) {
                    lastMatchingIndex = index
                } else {
                    potentialViolatingIndexes.append(index)
                }
            }

            let violatingIndexes = potentialViolatingIndexes.filter { $0 < lastMatchingIndex }
            violatingIndexes.forEach { index in
                let typeContentOffset = orderedTypeContentOffsets[index]

                let content = typeContentOffset.typeContent.rawValue
                let expected = expectedTypesContents.map { $0.rawValue }.joined(separator: ",")
                let article = ["a", "e", "i", "o", "u"].contains(content.substring(from: 0, length: 1)) ? "An" : "A"

                let styleViolation = StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severityConfiguration.severity,
                    location: Location(file: file, byteOffset: typeContentOffset.offset),
                    reason: "\(article) '\(content)' should not be placed amongst the type content(s) '\(expected)'."
                )
                violations.append(styleViolation)
            }
        }

        return violations
    }

    private func typeContentOffsets(in typeStructure: [String: SourceKitRepresentable]) -> [TypeContentOffset] {
        return typeStructure.substructure.compactMap { typeContentStructure in
            guard let typeContent = self.typeContent(for: typeContentStructure) else { return nil }
            return (typeContent, typeContentStructure.offset!)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func typeContent(for typeContentStructure: [String: SourceKitRepresentable]) -> TypeContent? {
        guard let typeContentKind = SwiftDeclarationKind(rawValue: typeContentStructure.kind!) else { return nil }

        switch typeContentKind {
        case .enumcase, .enumelement:
            return .case

        case .typealias:
            return .typeAlias

        case .associatedtype:
            return .associatedType

        case .class, .enum, .extension, .protocol, .struct:
            return .subtype

        case .varClass, .varStatic:
            return .typeProperty

        case .varInstance:
            if typeContentStructure.enclosedSwiftAttributes.contains(.iboutlet) {
                return .ibOutlet
            } else if typeContentStructure.enclosedSwiftAttributes.contains(.ibinspectable) {
                return .ibInspectable
            } else {
                return .instanceProperty
            }

        case .functionMethodClass, .functionMethodStatic:
            return .typeMethod

        case .functionMethodInstance:
            let viewLifecycleMethodNames = [
                "loadView(",
                "loadViewIfNeeded(",
                "viewDidLoad(",
                "viewWillAppear(",
                "viewWillLayoutSubviews(",
                "viewDidLayoutSubviews(",
                "viewDidAppear(",
                "viewWillDisappear(",
                "viewDidDisappear("
            ]

            if typeContentStructure.name!.starts(with: "init") || typeContentStructure.name!.starts(with: "deinit") {
                return .initializer
            } else if viewLifecycleMethodNames.contains(where: { typeContentStructure.name!.starts(with: $0) }) {
                return .viewLifeCycleMethod
            } else if typeContentStructure.enclosedSwiftAttributes.contains(SwiftDeclarationAttributeKind.ibaction) {
                return .ibAction
            } else {
                return .otherMethod
            }

        case .functionSubscript:
            return .subscript

        default:
            return nil
        }
    }
}
