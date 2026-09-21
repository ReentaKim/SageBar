import Foundation

enum PersonaMode: String, CaseIterable, Identifiable {
    case rotate, fixed, random
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rotate: return "매일 돌아가며"
        case .fixed: return "한 명 고정"
        case .random: return "매일 무작위"
        }
    }
}

enum LetterLength: String, CaseIterable, Identifiable {
    case short, normal, long
    var id: String { rawValue }
    var label: String {
        switch self {
        case .short: return "짧게 (약 3,000자)"
        case .normal: return "보통 (약 5,000자)"
        case .long: return "길게 (약 7,500자)"
        }
    }
    var minUpper: Int { switch self { case .short: return 1200; case .normal: return 2000; case .long: return 3000 } }
    var minLower: Int { switch self { case .short: return 1800; case .normal: return 3000; case .long: return 4500 } }
}

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus, sonnet
    var id: String { rawValue }
    var label: String {
        switch self {
        case .opus: return "Opus — 가장 정교함 (느림)"
        case .sonnet: return "Sonnet — 빠르고 가벼움"
        }
    }
}

/// UserDefaults 키. SwiftUI 뷰는 같은 키로 @AppStorage를 쓰고, 엔진은 여기서 읽는다.
enum SettingsKey {
    static let personaMode = "personaMode"
    static let fixedPersona = "fixedPersona"
    static let enabledPersonas = "enabledPersonas"
    static let showMinutes = "showMinutes"          // 자정 기준 분 (07:00 = 420)
    static let prebuildMinutes = "prebuildMinutes"  // 표시 시각 몇 분 전에 미리 지을지
    static let model = "model"
    static let length = "length"
    static let claudePath = "claudePath"
    static let lastShownDate = "lastShownDate"
    static let onboarded = "onboarded"
    static let recentDays = "recentDays"
    static let profileUpdatedAt = "profileUpdatedAt"
}

enum AppSettings {
    private static var d: UserDefaults { .standard }

    static func registerDefaults() {
        d.register(defaults: [
            SettingsKey.personaMode: PersonaMode.rotate.rawValue,
            SettingsKey.fixedPersona: PersonaID.zhuge.rawValue,
            SettingsKey.enabledPersonas: PersonaID.allCases.map(\.rawValue).joined(separator: ","),
            SettingsKey.showMinutes: 7 * 60,
            SettingsKey.prebuildMinutes: 20,
            SettingsKey.model: ClaudeModel.opus.rawValue,
            SettingsKey.length: LetterLength.normal.rawValue,
            SettingsKey.claudePath: "",
            SettingsKey.lastShownDate: "",
            SettingsKey.onboarded: false,
            SettingsKey.recentDays: 14,
            SettingsKey.profileUpdatedAt: "",
        ])
    }

    static var personaMode: PersonaMode { PersonaMode(rawValue: d.string(forKey: SettingsKey.personaMode) ?? "") ?? .rotate }
    static var fixedPersona: PersonaID { PersonaID(rawValue: d.string(forKey: SettingsKey.fixedPersona) ?? "") ?? .zhuge }
    static var enabledPersonas: [PersonaID] {
        let raw = d.string(forKey: SettingsKey.enabledPersonas) ?? ""
        let ids = raw.split(separator: ",").compactMap { PersonaID(rawValue: String($0)) }
        return ids.isEmpty ? PersonaID.allCases : ids
    }
    static var showMinutes: Int { d.integer(forKey: SettingsKey.showMinutes) }
    static var prebuildMinutes: Int { d.integer(forKey: SettingsKey.prebuildMinutes) }
    static var model: ClaudeModel { ClaudeModel(rawValue: d.string(forKey: SettingsKey.model) ?? "") ?? .opus }
    static var length: LetterLength { LetterLength(rawValue: d.string(forKey: SettingsKey.length) ?? "") ?? .normal }
    static var claudePath: String { d.string(forKey: SettingsKey.claudePath) ?? "" }
    static var recentDays: Int { max(1, d.integer(forKey: SettingsKey.recentDays)) }

    static var lastShownDate: String {
        get { d.string(forKey: SettingsKey.lastShownDate) ?? "" }
        set { d.set(newValue, forKey: SettingsKey.lastShownDate) }
    }
    static var onboarded: Bool {
        get { d.bool(forKey: SettingsKey.onboarded) }
        set { d.set(newValue, forKey: SettingsKey.onboarded) }
    }
    static var profileUpdatedAt: String {
        get { d.string(forKey: SettingsKey.profileUpdatedAt) ?? "" }
        set { d.set(newValue, forKey: SettingsKey.profileUpdatedAt) }
    }
}
