import SwiftUI

struct SwiftSyntaxHighlighter {

    enum TokenType: Equatable {
        case plain, keyword, type, string, number, comment, attribute, dotAccess
    }

    private static let keywords: Set<String> = [
        "actor", "associatedtype", "class", "deinit", "enum", "extension",
        "func", "import", "init", "let", "macro", "operator", "precedencegroup",
        "protocol", "struct", "subscript", "typealias", "var",
        "break", "case", "catch", "continue", "default", "defer", "do",
        "else", "fallthrough", "for", "guard", "if", "in", "repeat",
        "return", "switch", "where", "while",
        "any", "as", "await", "borrowing", "consuming", "false", "is",
        "nil", "self", "Self", "super", "throw", "true", "try",
        "async", "convenience", "dynamic", "final", "infix", "indirect",
        "inout", "isolated", "lazy", "mutating", "nonisolated", "nonmutating",
        "open", "optional", "override", "postfix", "prefix", "required",
        "some", "static", "throws", "rethrows", "unowned", "weak",
        "fileprivate", "internal", "package", "private", "public",
        "didSet", "get", "set", "willSet",
    ]

    static func highlight(_ code: String, colorScheme: ColorScheme) -> AttributedString {
        let tokens = tokenize(code)
        var result = AttributedString()
        for (text, type) in tokens {
            var attr = AttributedString(text)
            attr.foregroundColor = color(for: type, colorScheme: colorScheme)
            result.append(attr)
        }
        return result
    }

    private static func tokenize(_ code: String) -> [(String, TokenType)] {
        var tokens: [(String, TokenType)] = []
        var i = code.startIndex

        while i < code.endIndex {
            let ch = code[i]

            // Line comment
            if ch == "/", code.index(after: i) < code.endIndex, code[code.index(after: i)] == "/" {
                let start = i
                while i < code.endIndex, code[i] != "\n" {
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .comment))
                continue
            }

            // Block comment
            if ch == "/", code.index(after: i) < code.endIndex, code[code.index(after: i)] == "*" {
                let start = i
                i = code.index(i, offsetBy: 2)
                while i < code.endIndex {
                    if code[i] == "*", code.index(after: i) < code.endIndex, code[code.index(after: i)] == "/" {
                        i = code.index(i, offsetBy: 2)
                        break
                    }
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .comment))
                continue
            }

            // Multi-line string
            if ch == "\"",
               code.index(i, offsetBy: 2, limitedBy: code.endIndex) != nil,
               code[code.index(after: i)] == "\"",
               code.index(i, offsetBy: 2) < code.endIndex,
               code[code.index(i, offsetBy: 2)] == "\"" {
                let start = i
                i = code.index(i, offsetBy: 3)
                while i < code.endIndex {
                    if code[i] == "\"",
                       code.index(i, offsetBy: 2, limitedBy: code.endIndex) != nil,
                       code.index(after: i) < code.endIndex, code[code.index(after: i)] == "\"",
                       code.index(i, offsetBy: 2) < code.endIndex, code[code.index(i, offsetBy: 2)] == "\"" {
                        i = code.index(i, offsetBy: 3)
                        break
                    }
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .string))
                continue
            }

            // String literal
            if ch == "\"" {
                let start = i
                i = code.index(after: i)
                while i < code.endIndex, code[i] != "\"", code[i] != "\n" {
                    if code[i] == "\\" {
                        i = code.index(after: i)
                        guard i < code.endIndex else { break }
                    }
                    i = code.index(after: i)
                }
                if i < code.endIndex, code[i] == "\"" {
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .string))
                continue
            }

            // Attribute
            if ch == "@" {
                let start = i
                i = code.index(after: i)
                while i < code.endIndex, code[i].isLetter || code[i].isNumber || code[i] == "_" {
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .attribute))
                continue
            }

            // Dot access
            if ch == "." {
                let next = code.index(after: i)
                if next < code.endIndex, code[next].isLetter || code[next] == "_" {
                    let start = i
                    i = next
                    while i < code.endIndex, code[i].isLetter || code[i].isNumber || code[i] == "_" {
                        i = code.index(after: i)
                    }
                    tokens.append((String(code[start..<i]), .dotAccess))
                    continue
                }
            }

            // Number
            if ch.isNumber {
                let start = i
                while i < code.endIndex, code[i].isNumber || code[i] == "." || code[i] == "_" {
                    i = code.index(after: i)
                }
                tokens.append((String(code[start..<i]), .number))
                continue
            }

            // Identifier or keyword
            if ch.isLetter || ch == "_" {
                let start = i
                while i < code.endIndex, code[i].isLetter || code[i].isNumber || code[i] == "_" {
                    i = code.index(after: i)
                }
                let word = String(code[start..<i])
                if keywords.contains(word) {
                    tokens.append((word, .keyword))
                } else if let first = word.first, first.isUppercase {
                    tokens.append((word, .type))
                } else {
                    tokens.append((word, .plain))
                }
                continue
            }

            // Other characters
            let start = i
            i = code.index(after: i)
            tokens.append((String(code[start..<i]), .plain))
        }

        return tokens
    }

    static func color(for type: TokenType, colorScheme: ColorScheme) -> Color {
        let isDark = colorScheme == .dark
        switch type {
        case .plain:
            return isDark ? .white : .black
        case .keyword, .attribute:
            return isDark
                ? Color(red: 0.99, green: 0.37, blue: 0.64)
                : Color(red: 0.61, green: 0.14, blue: 0.58)
        case .type:
            return isDark
                ? Color(red: 0.36, green: 0.85, blue: 1.0)
                : Color(red: 0.04, green: 0.31, blue: 0.47)
        case .dotAccess:
            return isDark
                ? Color(red: 0.64, green: 0.82, blue: 0.94)
                : Color(red: 0.15, green: 0.39, blue: 0.56)
        case .string:
            return isDark
                ? Color(red: 0.99, green: 0.42, blue: 0.36)
                : Color(red: 0.77, green: 0.10, blue: 0.09)
        case .number:
            return isDark
                ? Color(red: 0.82, green: 0.75, blue: 0.41)
                : Color(red: 0.11, green: 0.00, blue: 0.81)
        case .comment:
            return isDark
                ? Color(red: 0.42, green: 0.47, blue: 0.53)
                : Color(red: 0.36, green: 0.42, blue: 0.47)
        }
    }
}

// MARK: - __tokenize Stripping

extension String {
    var strippingTokenize: String {
        guard contains("__tokenize(") else { return self }

        var result = self
        while let startRange = result.range(of: "__tokenize(") {
            let exprStart = startRange.upperBound
            var depth = 0
            var i = exprStart
            var inString = false
            var foundComma: String.Index?

            while i < result.endIndex {
                let c = result[i]

                if c == "\\" && inString {
                    i = result.index(after: i)
                    guard i < result.endIndex else { break }
                    i = result.index(after: i)
                    continue
                }

                if c == "\"" {
                    inString.toggle()
                } else if !inString {
                    if c == "(" {
                        depth += 1
                    } else if c == ")" {
                        if depth == 0 { break }
                        depth -= 1
                    } else if c == "," && depth == 0 {
                        let remaining = result[i...]
                        if remaining.hasPrefix(", as:") || remaining.hasPrefix(", as :") {
                            foundComma = i
                            break
                        }
                    }
                }

                i = result.index(after: i)
            }

            let exprEnd = foundComma ?? i
            let expression = String(result[exprStart..<exprEnd])

            if foundComma != nil {
                var j = exprEnd
                while j < result.endIndex && result[j] != ")" {
                    j = result.index(after: j)
                }
                if j < result.endIndex {
                    j = result.index(after: j)
                }
                result.replaceSubrange(startRange.lowerBound..<j, with: expression)
            } else {
                let end = i < result.endIndex ? result.index(after: i) : i
                result.replaceSubrange(startRange.lowerBound..<end, with: expression)
            }
        }

        return result
    }
}
