import Foundation

public enum GuardianContact {
    public static func normalizedEmail(_ input: String) -> String? {
        let email = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, email.count <= 254 else { return nil }

        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let local = String(parts[0])
        let domain = String(parts[1])
        guard
            !local.isEmpty,
            local.count <= 64,
            !local.hasPrefix("."),
            !local.hasSuffix("."),
            !local.contains("..")
        else {
            return nil
        }

        let localCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.!#$%&'*+-/=?^_`{|}~"
        )
        guard local.unicodeScalars.allSatisfy(localCharacters.contains) else { return nil }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.last?.count ?? 0 >= 2 else { return nil }

        let domainCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard
                !label.isEmpty,
                label.count <= 63,
                !label.hasPrefix("-"),
                !label.hasSuffix("-"),
                label.unicodeScalars.allSatisfy(domainCharacters.contains)
            else {
                return nil
            }
        }

        return email
    }

    public static func formattedUSPhone(_ input: String) -> String? {
        let allowedSeparators = CharacterSet(charactersIn: "+()- .")
        guard input.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.decimalDigits.contains(scalar) || allowedSeparators.contains(scalar)
        }) else {
            return nil
        }

        var digits = input.compactMap { $0.wholeNumberValue }.map(String.init).joined()
        if digits.count == 11, digits.hasPrefix("1") {
            digits.removeFirst()
        }
        guard digits.count == 10 else { return nil }

        let values = Array(digits)
        let areaCode = String(values[0..<3])
        let exchange = String(values[3..<6])
        let subscriber = String(values[6..<10])
        return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
    }
}
