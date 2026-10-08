import Foundation
import SwiftUI
import UIKit

// SS14 character customisation, generated from Space Station 14 + Goob Station + Starlight + Nuclear 14
// prototypes (species, markings, loadouts) by tools in the project. See CREDITS.md.

// MARK: - Saved character

struct MarkingPick: Codable, Equatable, Hashable {
    var id: String
    var colors: [String]
}

struct CharacterProfile: Codable, Equatable, Hashable {
    var species = "Human"
    var sex = "Male"
    var skin = "#D9B39B"
    var skinTone: Double = 20            // HumanToned slider (0 = pale gold, 100 = dark)
    var eyes = "#5A3A22"
    var hair = "#4E3628"
    var facialHair = "#4E3628"
    var markings: [MarkingPick] = []
    var outfitJob: String? = nil         // nil = wear your ID job's loadout
    var loadout: [String: String] = [:]  // loadout group id → option id ("none" for nothing)
    var wardrobe: [String: String] = [:] // slot → item id ("none" hides the slot)
    var showClothes = true
    var height: Double = 1
    var width: Double = 1
    var voice: String? = nil             // speech sounds id, nil = species default
    var setUp = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decodeIfPresent(String.self, forKey: .species) ?? "Human"
        sex = try c.decodeIfPresent(String.self, forKey: .sex) ?? "Male"
        skin = try c.decodeIfPresent(String.self, forKey: .skin) ?? "#D9B39B"
        skinTone = try c.decodeIfPresent(Double.self, forKey: .skinTone) ?? 20
        eyes = try c.decodeIfPresent(String.self, forKey: .eyes) ?? "#5A3A22"
        hair = try c.decodeIfPresent(String.self, forKey: .hair) ?? "#4E3628"
        facialHair = try c.decodeIfPresent(String.self, forKey: .facialHair) ?? "#4E3628"
        markings = try c.decodeIfPresent([MarkingPick].self, forKey: .markings) ?? []
        outfitJob = try c.decodeIfPresent(String.self, forKey: .outfitJob)
        loadout = try c.decodeIfPresent([String: String].self, forKey: .loadout) ?? [:]
        wardrobe = try c.decodeIfPresent([String: String].self, forKey: .wardrobe) ?? [:]
        showClothes = try c.decodeIfPresent(Bool.self, forKey: .showClothes) ?? true
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 1
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 1
        voice = try c.decodeIfPresent(String.self, forKey: .voice)
        setUp = try c.decodeIfPresent(Bool.self, forKey: .setUp) ?? false
    }
}

// MARK: - Database (GameData/Character/character.json)

struct CharacterDB: Decodable {
    struct Part: Decodable {
        let layer: String
        let color: String           // skin | eyes | none
        let sprite: String?
        let bySex: [String: String?]?
        let alpha: Double?
        func sprite(for sex: String) -> String? { (bySex?[sex] ?? nil) ?? sprite }
    }
    struct Limit: Decodable {
        let cat: String
        let limit: Int
        let required: Bool
        let defaults: [String]
    }
    struct Appearance: Decodable { let alpha: Double; let matchSkin: Bool }
    struct Skin: Decodable { let mode: String; let `default`: String }
    struct Species: Decodable, Identifiable {
        let id: String
        let name: String
        let source: String
        let sexes: [String]
        let skin: Skin
        let parts: [Part]
        let eyes: Part?
        let limits: [Limit]
        let markings: [String]
        let clothingSuffix: String?
        let displace: [String: String]
        let displaceMale: [String: String]
        let displaceFemale: [String: String]
        let bodyDisplace: String?
        let appearances: [String: Appearance]
        let size: [String: Double]

        var heightRange: ClosedRange<Double> { (size["minHeight"] ?? 0.9)...(size["maxHeight"] ?? 1.1) }
        var widthRange: ClosedRange<Double> { (size["minWidth"] ?? 0.9)...(size["maxWidth"] ?? 1.1) }
        func limit(_ cat: String) -> Limit? { limits.first { $0.cat == cat } }
        func displacement(slot: String, sex: String) -> String? {
            if sex == "Female", let d = displaceFemale[slot] { return d }
            if sex == "Male", let d = displaceMale[slot] { return d }
            return displace[slot]
        }
    }
    struct Marking: Decodable, Identifiable {
        let id: String
        let name: String
        let layer: String
        let cat: String
        let sprites: [String]
        let colors: [[String]]
        let sex: String?
        let source: String

        enum CodingKeys: String, CodingKey { case id, name, layer, cat, sprites, colors, sex, source }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            layer = (try? c.decode(String.self, forKey: .layer)) ?? "Special"
            cat = (try? c.decode(String.self, forKey: .cat)) ?? layer
            sprites = try c.decode([String].self, forKey: .sprites)
            colors = (try? c.decode([[String]].self, forKey: .colors)) ?? []
            sex = try? c.decodeIfPresent(String.self, forKey: .sex)
            source = (try? c.decode(String.self, forKey: .source)) ?? "Space Station 14"
        }
    }
    struct ItemLayer: Decodable { let sprite: String; let color: String? }
    struct Item: Decodable, Identifiable {
        let id: String
        let name: String
        let slot: String
        let layers: [ItemLayer]
        let species: [String: String]
        let icon: String?
    }
    struct LoadoutOption: Decodable, Identifiable { let id: String; let name: String; let items: [String: String] }
    struct LoadoutGroup: Decodable, Identifiable { let id: String; let name: String; let min: Int; let options: [LoadoutOption] }
    struct Job: Decodable { let base: [String: String]; let groups: [LoadoutGroup] }

    let layers: [String]
    let species: [Species]
    let markings: [String: Marking]
    let items: [String: Item]
    let jobs: [String: Job]
    let wardrobe: [String: [String]]

    static let shared: CharacterDB = {
        guard let url = Bundle.main.url(forResource: "character", withExtension: "json", subdirectory: "Character")
                ?? Bundle.main.url(forResource: "character", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let db = try? JSONDecoder().decode(CharacterDB.self, from: data) else {
            return CharacterDB(layers: [], species: [], markings: [:], items: [:], jobs: [:], wardrobe: [:])
        }
        return db
    }()

    init(layers: [String], species: [Species], markings: [String: Marking], items: [String: Item],
         jobs: [String: Job], wardrobe: [String: [String]]) {
        self.layers = layers; self.species = species; self.markings = markings
        self.items = items; self.jobs = jobs; self.wardrobe = wardrobe
    }

    func species(_ id: String) -> Species? { species.first { $0.id == id } }

    /// Markings this species may wear in a category, respecting body type.
    func markings(for sp: Species, cat: String, sex: String) -> [Marking] {
        sp.markings.compactMap { markings[$0] }
            .filter { $0.cat == cat && ($0.sex == nil || $0.sex == sex) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static let slotOrder = ["head", "eyes", "mask", "ears", "neck", "outerClothing", "jumpsuit", "gloves", "belt", "back", "shoes"]
    static func slotLabel(_ slot: String) -> String {
        switch slot {
        case "head": return "Head"
        case "eyes": return "Eyes"
        case "mask": return "Mask"
        case "ears": return "Ears"
        case "neck": return "Neck"
        case "outerClothing": return "Suit"
        case "jumpsuit": return "Jumpsuit"
        case "gloves": return "Gloves"
        case "belt": return "Belt"
        case "back": return "Back"
        case "shoes": return "Shoes"
        default: return slot.capitalized
        }
    }

    /// Category names as shown in SS14's markings picker.
    static func categoryLabel(_ cat: String) -> String {
        switch cat {
        case "Hair": return "Hair"
        case "FacialHair": return "Facial hair"
        case "HeadTop": return "Head (top)"
        case "HeadSide": return "Head (side)"
        case "Head": return "Head"
        case "Snout": return "Snout"
        case "SnoutCover": return "Snout cover"
        case "Chest": return "Chest"
        case "Tail": return "Tail"
        case "Overlay": return "Overlay"
        case "UndergarmentTop": return "Undershirt"
        case "UndergarmentBottom": return "Underwear"
        case "LArm", "LeftArm": return "Left arm"
        case "RArm", "RightArm": return "Right arm"
        case "LHand", "LeftHand": return "Left hand"
        case "RHand", "RightHand": return "Right hand"
        case "LLeg", "LeftLeg": return "Left leg"
        case "RLeg", "RightLeg": return "Right leg"
        case "LFoot", "LeftFoot": return "Left foot"
        case "RFoot", "RightFoot": return "Right foot"
        case "Eyes": return "Eyes"
        case "OverEyes": return "Over eyes"
        case "Wings": return "Wings"
        case "Face": return "Face"
        case "Special": return "Special"
        default: return cat.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        }
    }
    static let categoryOrder = ["Hair", "FacialHair", "HeadTop", "HeadSide", "Head", "Face", "Snout", "SnoutCover", "Eyes", "OverEyes",
                                "Chest", "Wings", "Tail", "Overlay", "UndergarmentTop", "UndergarmentBottom",
                                "LArm", "LeftArm", "RArm", "RightArm", "LHand", "LeftHand", "RHand", "RightHand",
                                "LLeg", "LeftLeg", "RLeg", "RightLeg", "LFoot", "LeftFoot", "RFoot", "RightFoot", "Special"]
}

// MARK: - Colours

struct RGBA { var r, g, b: Float }

enum Hex {
    static func rgb(_ s: String) -> RGBA {
        var v: UInt64 = 0
        Scanner(string: s.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        return RGBA(r: Float((v >> 16) & 0xFF) / 255, g: Float((v >> 8) & 0xFF) / 255, b: Float(v & 0xFF) / 255)
    }
    static func string(_ c: RGBA) -> String {
        String(format: "#%02X%02X%02X", Int(max(0, min(1, c.r)) * 255), Int(max(0, min(1, c.g)) * 255), Int(max(0, min(1, c.b)) * 255))
    }
    static func from(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return string(RGBA(r: Float(r), g: Float(g), b: Float(b)))
    }
    static func color(_ s: String) -> Color {
        let c = rgb(s); return Color(red: Double(c.r), green: Double(c.g), blue: Double(c.b))
    }
}

/// SS14 skin colouration strategies (Content.Shared/Humanoid/SkinColorationPrototype.cs).
enum SkinTone {
    /// HumanTonedSkinColoration.FromUnary
    static func human(_ tone: Double) -> String {
        let t = max(0, min(100, tone))
        let offset = t - 20
        var hue = 25.0, sat = 20.0, val = 100.0
        if offset <= 0 { hue += abs(offset) } else { sat += offset; val -= offset }
        let c = UIColor(hue: hue / 360, saturation: sat / 100, brightness: val / 100, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Hex.string(RGBA(r: Float(r), g: Float(g), b: Float(b)))
    }

    /// Clamp a picked colour the way the species' strategy does.
    static func clamp(_ hex: String, mode: String) -> String {
        let c = Hex.rgb(hex)
        let ui = UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        switch mode {
        case "hue": v = max(0.175, v)                                 // ClampedHsvColoration value [0.175, 1]
        case "tinted": s = min(0.1, s); v = max(0.85, v)              // near-white tints
        case "fixed": return "#FFFFFF"
        default: break
        }
        let out = UIColor(hue: h, saturation: s, brightness: v, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        out.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Hex.string(RGBA(r: Float(r), g: Float(g), b: Float(b)))
    }

    static func tattoo(_ skin: String) -> String {
        let c = Hex.rgb(skin)
        let ui = UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        let out = UIColor(hue: h, saturation: s, brightness: 0.4, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        out.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Hex.string(RGBA(r: Float(r), g: Float(g), b: Float(b)))
    }
}

// MARK: - Editing helpers

extension CharacterProfile {
    var db: CharacterDB { .shared }
    var speciesDef: CharacterDB.Species? { db.species(species) ?? db.species("Human") ?? db.species.first }

    /// Default colours for a marking (MarkingColoring.GetMarkingLayerColors).
    func defaultColors(for m: CharacterDB.Marking) -> [String] {
        if m.cat == "Hair" { return Array(repeating: hair, count: m.sprites.count) }
        if m.cat == "FacialHair" { return Array(repeating: facialHair, count: m.sprites.count) }
        return m.sprites.indices.map { i in resolve(i < m.colors.count ? m.colors[i] : ["skin"]) }
    }

    func resolve(_ rules: [String]) -> String {
        for rule in rules {
            let neg = rule.hasPrefix("neg:")
            let r = neg ? String(rule.dropFirst(4)) : rule
            var out: String?
            switch r {
            case "none": out = "#FFFFFF"
            case "skin": out = skin
            case "eyes": out = eyes
            case "tattoo": out = SkinTone.tattoo(skin)
            default:
                if r.hasPrefix("cat:") {
                    let cat = String(r.dropFirst(4))
                    if let pick = markings.first(where: { db.markings[$0.id]?.cat == cat }) {
                        out = cat == "Hair" ? hair : cat == "FacialHair" ? facialHair : pick.colors.first
                    }
                } else if r.hasPrefix("#") { out = r }
            }
            if var o = out {
                if neg { let c = Hex.rgb(o); o = Hex.string(RGBA(r: 1 - c.r, g: 1 - c.g, b: 1 - c.b)) }
                return o
            }
        }
        return "#FFFFFF"
    }

    func picks(in cat: String) -> [MarkingPick] {
        markings.filter { db.markings[$0.id]?.cat == cat }
    }

    mutating func add(_ m: CharacterDB.Marking) {
        guard let sp = speciesDef, let lim = sp.limit(m.cat) else { return }
        var current = picks(in: m.cat)
        if current.count >= lim.limit, let first = current.first {
            markings.removeAll { $0 == first }
            current.removeFirst()
        }
        markings.append(MarkingPick(id: m.id, colors: defaultColors(for: m)))
    }

    mutating func remove(_ id: String) { markings.removeAll { $0.id == id } }

    /// Switch species: keep what still fits, add the species' required defaults.
    mutating func changeSpecies(to id: String) {
        guard let sp = db.species(id) else { return }
        species = id
        if !sp.sexes.contains(sex) { sex = sp.sexes.first ?? "Male" }
        skin = sp.skin.mode == "human" ? SkinTone.human(skinTone) : sp.skin.default
        markings = markings.filter { sp.markings.contains($0.id) }
        applyDefaults()
        height = min(max(height, sp.heightRange.lowerBound), sp.heightRange.upperBound)
        width = min(max(width, sp.widthRange.lowerBound), sp.widthRange.upperBound)
        voice = nil
    }

    /// Required marking categories (tails, snouts, wings…) get their species defaults.
    mutating func applyDefaults() {
        guard let sp = speciesDef else { return }
        for lim in sp.limits where lim.required && picks(in: lim.cat).isEmpty {
            for d in lim.defaults { if let m = db.markings[d] { add(m) } }
        }
    }

    /// Refresh colours that follow skin/eyes/hair after those change.
    mutating func refreshFollowingColors(oldSkin: String? = nil) {
        markings = markings.map { pick in
            guard let m = db.markings[pick.id] else { return pick }
            if m.cat == "Hair" { return MarkingPick(id: pick.id, colors: pick.colors.map { _ in hair }) }
            if m.cat == "FacialHair" { return MarkingPick(id: pick.id, colors: pick.colors.map { _ in facialHair }) }
            guard let oldSkin else { return pick }
            var p = pick
            for i in p.colors.indices where i < m.colors.count {
                if p.colors[i] == oldSkin || (m.colors[i].first == "tattoo") { p.colors[i] = resolve(m.colors[i]) }
            }
            return p
        }
    }

    /// SS14's "Randomize" (keeps species).
    mutating func randomize() {
        guard let sp = speciesDef else { return }
        sex = sp.sexes.randomElement() ?? sex
        if sp.skin.mode == "human" {
            skinTone = Double.random(in: 0...100); skin = SkinTone.human(skinTone)
        } else if sp.skin.mode != "fixed" {
            skin = SkinTone.clamp(Hex.string(RGBA(r: .random(in: 0...1), g: .random(in: 0...1), b: .random(in: 0...1))), mode: sp.skin.mode)
        }
        let natural = ["#2B1B12", "#4E3628", "#7A4E2D", "#B5875A", "#D9C08C", "#1A1A1A", "#8C2F1B", "#C9C9C9"]
        hair = natural.randomElement()!
        facialHair = hair
        eyes = ["#5A3A22", "#3B6E8F", "#4A7A3A", "#7A6A3A", "#2E2E2E", "#8F3B3B"].randomElement()!
        markings = []
        for lim in sp.limits {
            let options = db.markings(for: sp, cat: lim.cat, sex: sex)
            if lim.required {
                if let m = options.randomElement() ?? lim.defaults.compactMap({ db.markings[$0] }).first { add(m) }
            } else if ["Hair", "FacialHair"].contains(lim.cat) {
                if lim.cat == "FacialHair" && (sex == "Female" || Bool.random()) { continue }
                if let m = options.randomElement() { add(m) }
            }
        }
        height = Double.random(in: sp.heightRange)
        width = Double.random(in: sp.widthRange)
    }

    static func starter(job: String = "Passenger") -> CharacterProfile {
        var p = CharacterProfile()
        p.skin = SkinTone.human(p.skinTone)
        if let sp = p.speciesDef {
            let hairs = p.db.markings(for: sp, cat: "Hair", sex: p.sex)
            if let m = hairs.first(where: { $0.name.lowercased().contains("short") }) ?? hairs.first { p.add(m) }
            p.applyDefaults()
        }
        p.setUp = true
        return p
    }

    /// What's actually worn, slot → item id.
    func outfit(idJob: String) -> [String: String] {
        guard showClothes else { return [:] }
        let jobID = outfitJob ?? idJob
        let job = db.jobs[jobID] ?? db.jobs["Passenger"]
        var out = job?.base ?? [:]
        for g in job?.groups ?? [] {
            let chosen = loadout[g.id]
            if chosen == "none" { continue }
            if let opt = g.options.first(where: { $0.id == chosen }) ?? g.options.first {
                out.merge(opt.items) { _, new in new }
            }
        }
        for (slot, item) in wardrobe {
            if item == "none" { out[slot] = nil } else if db.items[item] != nil { out[slot] = item }
        }
        return out
    }
}

// MARK: - Renderer (same layering as SS14: BaseSpeciesLayers + displacement maps)

final class SpriteStrips {
    static let shared = SpriteStrips()
    private var cache: [String: [Float]] = [:]
    private let lock = NSLock()

    /// 32×128 RGBA premultiplied floats (S, N, E, W).
    func strip(_ key: String) -> [Float]? {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        guard let url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Character/Sprites"),
              let img = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let w = 128, h = 32
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let floats = bytes.map { Float($0) / 255 }
        cache[key] = floats
        return floats
    }
}

enum CharacterRenderer {
    private static let imageCache = NSCache<NSString, CGImage>()

    /// dir: 0 south, 1 north, 2 east, 3 west.
    static func image(_ p: CharacterProfile, idJob: String, dir: Int, only: Set<String>? = nil) -> CGImage? {
        let key = "\(p.hashValue)|\(idJob)|\(dir)|\(only?.sorted().joined(separator: ",") ?? "")" as NSString
        if let c = imageCache.object(forKey: key) { return c }
        guard let img = render(p, idJob: idJob, dir: dir, only: only) else { return nil }
        imageCache.setObject(img, forKey: key)
        return img
    }

    static func render(_ p: CharacterProfile, idJob: String, dir: Int, only: Set<String>? = nil) -> CGImage? {
        let db = CharacterDB.shared
        guard let sp = p.speciesDef else { return nil }
        var canvas = [Float](repeating: 0, count: 32 * 32 * 4)
        let outfit = p.outfit(idJob: idJob)
        let skin = Hex.rgb(p.skin), eyes = Hex.rgb(p.eyes), white = RGBA(r: 1, g: 1, b: 1)

        func draw(_ key: String?, _ tint: RGBA, disp: String? = nil, alpha: Float = 1) {
            guard let key, let s = SpriteStrips.shared.strip(key) else { return }
            let dmap = disp.flatMap { SpriteStrips.shared.strip($0) }
            let x0 = dir * 32
            for y in 0..<32 {
                for x in 0..<32 {
                    var sx = x, sy = y, k: Float = 1
                    if let dmap {
                        let di = (y * 128 + x0 + x) * 4
                        let da = dmap[di + 3]
                        if da <= 0 { continue }
                        // stored premultiplied — recover the straight R/G offsets
                        let dx = Int((dmap[di] / da * 255 - 128).rounded())
                        let dy = Int((dmap[di + 1] / da * 255 - 128).rounded())
                        sx = x + dx; sy = y + dy; k = da
                        if sx < 0 || sx >= 32 || sy < 0 || sy >= 32 { continue }
                    }
                    let si = (sy * 128 + x0 + sx) * 4
                    let a = s[si + 3] * alpha * k
                    if a <= 0 { continue }
                    let r = s[si] * tint.r * alpha * k, g = s[si + 1] * tint.g * alpha * k, b = s[si + 2] * tint.b * alpha * k
                    let ci = (y * 32 + x) * 4
                    let inv = 1 - a
                    canvas[ci] = r + canvas[ci] * inv
                    canvas[ci + 1] = g + canvas[ci + 1] * inv
                    canvas[ci + 2] = b + canvas[ci + 2] * inv
                    canvas[ci + 3] = a + canvas[ci + 3] * inv
                }
            }
        }

        for layer in db.layers {
            if let only, !only.contains(layer) { continue }
            if layer.hasPrefix("slot:") {
                let slot = String(layer.dropFirst(5))
                guard let iid = outfit[slot], let item = db.items[iid] else { continue }
                if let suffix = sp.clothingSuffix, let special = item.species[suffix] {
                    draw(special, white)
                    continue
                }
                let disp = sp.displacement(slot: slot, sex: p.sex)
                for l in item.layers { draw(l.sprite, l.color.map(Hex.rgb) ?? white, disp: disp) }
                continue
            }
            for part in sp.parts where part.layer == layer {
                draw(part.sprite(for: p.sex), part.color == "none" ? white : skin, disp: sp.bodyDisplace, alpha: Float(part.alpha ?? 1))
            }
            if let e = sp.eyes, e.layer == layer {
                draw(e.sprite(for: p.sex), eyes, disp: sp.bodyDisplace)
            }
            let app = sp.appearances[layer]
            for pick in p.markings {
                guard let m = db.markings[pick.id], m.layer == layer else { continue }
                for (i, key) in m.sprites.enumerated() {
                    let hex = app?.matchSkin == true ? p.skin : (i < pick.colors.count ? pick.colors[i] : pick.colors.last ?? "#FFFFFF")
                    draw(key, Hex.rgb(hex), disp: sp.bodyDisplace, alpha: Float(app?.alpha ?? 1))
                }
            }
        }

        var bytes = canvas.map { UInt8(max(0, min(255, ($0 * 255).rounded()))) }
        return bytes.withUnsafeMutableBytes { buf -> CGImage? in
            guard let ctx = CGContext(data: buf.baseAddress, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
    }
}
