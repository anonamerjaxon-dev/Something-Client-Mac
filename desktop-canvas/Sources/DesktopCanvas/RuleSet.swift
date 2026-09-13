import Foundation

public struct RuleSet: Codable, Equatable, Hashable {
    public var name: String
    public var birth: Set<Int>
    public var survival: Set<Int>

    public init(name: String, birth: Set<Int>, survival: Set<Int>) {
        self.name = name
        self.birth = birth
        self.survival = survival
    }

    public init?(bSNotation: String) {
        let parts = bSNotation.split(separator: "/")
        guard parts.count == 2 else { return nil }

        let birthPart = parts[0]
        let survivalPart = parts[1]

        guard birthPart.hasPrefix("B"), survivalPart.hasPrefix("S") else { return nil }

        let birthDigits = birthPart.dropFirst()
        let survivalDigits = survivalPart.dropFirst()

        let birthSet = Set(birthDigits.compactMap { Int(String($0)) })
        let survivalSet = Set(survivalDigits.compactMap { Int(String($0)) })

        guard birthSet.count == birthDigits.count,
              survivalSet.count == survivalDigits.count else { return nil }

        self.name = "Custom"
        self.birth = birthSet
        self.survival = survivalSet
    }

    public var bSNotation: String {
        let b = birth.sorted().map(String.init).joined()
        let s = survival.sorted().map(String.init).joined()
        return "B\(b)/S\(s)"
    }

    public static let conway   = RuleSet(name: "Conway",      birth: [3],             survival: [2, 3])
    public static let highLife = RuleSet(name: "HighLife",    birth: [3, 6],          survival: [2, 3])
    public static let dayNight = RuleSet(name: "Day & Night", birth: [3, 6, 7, 8],    survival: [3, 4, 6, 7, 8])
    public static let seeds    = RuleSet(name: "Seeds",       birth: [2],             survival: [])
    public static let maze     = RuleSet(name: "Maze",        birth: [3],             survival: [1, 2, 3, 4, 5])
    public static let anneal   = RuleSet(name: "Anneal",      birth: [4, 6, 7, 8],    survival: [3, 5, 6, 7, 8])
    public static let twoByTwo = RuleSet(name: "2x2",         birth: [3, 6],          survival: [1, 2, 5])
    public static let morley   = RuleSet(name: "Morley",      birth: [3, 6, 8],       survival: [2, 4, 5])
    public static let diamoeba = RuleSet(name: "Diamoeba",    birth: [3, 5, 6, 7, 8], survival: [5, 6, 7, 8])

    public static let presets: [RuleSet] = [
        .conway, .highLife, .dayNight, .seeds, .maze,
        .anneal, .twoByTwo, .morley, .diamoeba
    ]
}