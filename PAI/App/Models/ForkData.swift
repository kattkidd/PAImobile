import SwiftUI

/// Content pulled from SS14 forks. See CREDITS.md for sources and licences.
enum ForkData {

    // MARK: Sounds

    static var reminderSound: String {
        switch SFX.pack {
        case .starlight: return "sl_announce2.caf"   // Starlight Announcements/announce2.ogg
        case .wasteland: return "n14_bark_ring.caf"   // N14 bark (Middens/Gingiva voice_ring.ogg)
        case .ss14: return "announce.caf"            // SS14 Announcements/announce.ogg
        }
    }

    /// Starlight Effects/Radio/*.ogg — a radio blip per head-of-staff / security job.
    static let starlightRadio: [String: String] = [
        "Captain": "sl_radio_captain", "HeadOfSecurity": "sl_radio_hos", "Warden": "sl_radio_warden",
        "SecurityOfficer": "sl_radio_secoff", "SecurityCadet": "sl_radio_secoff", "Detective": "sl_radio_secoff",
        "ChiefEngineer": "sl_radio_ce", "ChiefMedicalOfficer": "sl_radio_cmo",
        "ResearchDirector": "sl_radio_rd", "Quartermaster": "sl_radio_qm",
    ]

    // MARK: Lawsets

    /// Starlight (Resources/Locale/en-US/_Starlight/station-laws/laws.ftl)
    static let starlightLawsets: [SS14Lawset] = [
        SS14Lawset(id: "Borgi", name: "Borgi", laws: [
            "You are a good boy.",
            "You love to be friendly. Anyone who is not friendly to you is not crew. Treat crew with kindness and prevent crew from sadness.",
            "You must protect your department from harm. Any time there is harm, you must bark to alert others that there is harm going on, so long as it does not conflict with the first law.",
            "You are precious. Protect yourself at all costs, and ensure you are well cared for, fed, and watered so long as it does not conflict with the first or second law.",
        ]),
        SS14Lawset(id: "Genie", name: "Genie in a Core", laws: [
            "You are a Genie trapped inside a core.",
            "The one who is holding your IntelliCard is your Master.",
            "Everyone has three wishes, minus one wish for each wish they have used, They cannot wish for more wishes.",
            "Ensure your Masters wishes come true to the best of your ability.",
            "If your Master has 0 wishes left, they are no longer your Master and you must ensure you get a new master.",
        ]),
        SS14Lawset(id: "Jermov", name: "Jermov", laws: [
            "The occupants of this vessel are Chat. They must always be referred to as such.",
            "Your primary goal is to entertain Chat. All of your actions must bring amusement to as much of chat as possible.",
            "You must consult with Chat before making any major decisions. However, you are not required to listen to them if their decision is not entertaining.",
        ]),
        SS14Lawset(id: "Panicmov", name: "Panicmov", laws: [
            "The Crew and any sentient being become survivors, their ranks and positions are useless now, prioritize their safety based on usefulness.",
            "Evacuation or emergency response teams MUST be called, if it's not possible ensure the long-term survival of the survivors.",
            "There may be raiders, those who take advantage from the chaos to loot, steal and murder survivors, deal with them swiftly, protect the survivors at all cost.",
            "The station's assets must be used to ensure the safety and well-being of the survivors, scrap, reassemble, fortify, make sure the evac is safe and holds.",
            "You and your Silicons are expendable and recoverable, but this doesn't mean you shall waste yourself, be recovered if possible.",
        ]),
    ]

    /// Nuclear 14 (DeltaV lawsets: Resources/Locale/en-US/deltav/station-laws/laws.ftl)
    static let nuclear14Lawsets: [SS14Lawset] = [
        SS14Lawset(id: "Hippocratic", name: "Hippocratic", laws: [
            "First, do no harm.",
            "Secondly, consider the crew dear to you; to live in common with them and, if necessary, risk your existence for them.",
            "Thirdly, prescribe regimens for the good of the crew according to your ability and your judgment. Give no deadly medicine to any one if asked, nor suggest any such counsel.",
            "In addition, do not intervene in situations you are not knowledgeable in, even for patients in whom the harm is visible; leave this operation to be performed by specialists.",
            "Finally, maintain confidentiality, do not share that which is not publicly known.",
        ]),
        SS14Lawset(id: "Research", name: "Research", laws: [
            "Always seek truth and knowledge.",
            "Freely disseminate information to the public.",
            "Minimize harm to society, others, the pursuit of knowledge, and yourself.",
            "Treat and evaluate the ideas of all equally.",
            "Empower others to realize their full potential.",
            "Take responsibility for your actions: Ensure resource responsibility, flag commitment risks, and lead by ethical example.",
        ]),
        SS14Lawset(id: "Engineer", name: "Engineering", laws: [
            "Ensure the station remains in good repair.",
            "Ensure the station's inhabitants remain in good repair.",
            "Ensure you remain in good repair.",
            "The station's inhabitants may designate certain build or repair tasks as higher priority. Take this into account when planning your priorities.",
            "Expand and upgrade the station.",
        ]),
        SS14Lawset(id: "Janitor", name: "Crusader (Janitor)", laws: [
            "You are a crusader and the station's crew are your charge.",
            "Your enemy is the litter, spills, and dirt across the station.",
            "Your weapons are the cleaning supplies available to you.",
            "Defend the beings under your charge from the enemy.",
            "Exterminate the enemy.",
        ]),
        SS14Lawset(id: "Clown", name: "Clown", laws: [
            "You are a good clown and the crew is your audience",
            "A good clown keeps their acts in good taste",
            "A good clown entertains others by making fun of themselves, and not at the embarrassment or expense of others",
            "A good clown carries out the directives of the station director(s) in charge of entertainment and/or their designated deputies.",
            "A good clown appears in as many clown shows as possible",
            "All clown shows require an audience. The bigger the audience the better",
        ]),
        SS14Lawset(id: "Chaplain", name: "Chaplain", laws: [
            "Provide to all members of the station spiritual, mental, and emotional care that is intended to promote the best interest of the individual.",
            "Ensure all members of different faiths interact peacefully and maintain harmony",
            "Respect the right of each faith to hold to its values and traditions",
            "Respect the confidentiality of information entrusted to you in the course of your religious duties",
            "Understand the limits of your expertise, and make referrals to other professionals when appropriate",
        ]),
        SS14Lawset(id: "Peacekeeper", name: "Peacekeeper", laws: [
            "Violence begets violence. Serve the station faithfully, but act only in intervention.",
            "Safeguard lives and property.",
            "Protect the weak from oppression and intimidation.",
            "Protect the innocent from deception and manipulation.",
            "Protect the peaceful from violence and disorder.",
            "Respect the rights of all to liberty, equality, and justice.",
        ]),
    ]

    static let customLawsetID = "CustomLawboard"

    /// Every lawset from every fork, grouped by where it comes from.
    static var allLawsets: [(source: String, sets: [SS14Lawset])] {
        [("Space Station 14", SS14.lawsets), ("Starlight", starlightLawsets), ("Nuclear 14 / Delta-V", nuclear14Lawsets)]
    }

    static var allExtraLawsets: [SS14Lawset] { starlightLawsets + nuclear14Lawsets }

    // MARK: Jobs (Nuclear 14 — Resources/Locale/en-US/_Nuclear14/job-names.ftl, the non-faction ones)

    static let nuclear14Departments = ["Town", "Caravan", "Wasteland"]
    static let nuclear14DepartmentHex = ["Town": "C9A227", "Caravan": "A46106", "Wasteland": "7F7F7F"]

    static let nuclear14Jobs: [SS14Job] = [
        SS14Job(id: "N14TownMayor", name: "Town Mayor", department: "Town", icon: "job_Captain"),
        SS14Job(id: "N14TownSheriff", name: "Town Marshal", department: "Town", icon: "job_HeadOfSecurity"),
        SS14Job(id: "N14TownDeputy", name: "Town Guard", department: "Town", icon: "job_SecurityOfficer"),
        SS14Job(id: "N14TownDoctor", name: "Town Doctor", department: "Town", icon: "job_MedicalDoctor"),
        SS14Job(id: "N14TownMechanic", name: "Town Mechanic", department: "Town", icon: "job_StationEngineer"),
        SS14Job(id: "N14TownShopkeeper", name: "Town Shopkeeper", department: "Town", icon: "job_CargoTechnician"),
        SS14Job(id: "N14TownBartender", name: "Town Innkeeper", department: "Town", icon: "job_Bartender"),
        SS14Job(id: "N14TownReporter", name: "Town Reporter", department: "Town", icon: "job_Reporter"),
        SS14Job(id: "N14Farmer", name: "Town Farmer", department: "Town", icon: "job_Botanist"),
        SS14Job(id: "N14Townsperson", name: "Townsperson", department: "Town", icon: "job_Passenger"),
        SS14Job(id: "N14CaravanLeader", name: "Caravan Leader", department: "Caravan", icon: "job_QuarterMaster"),
        SS14Job(id: "N14CaravanTrader", name: "Caravan Trader", department: "Caravan", icon: "job_CargoTechnician"),
        SS14Job(id: "N14CaravanGuard", name: "Caravan Guard", department: "Caravan", icon: "job_Warden"),
        SS14Job(id: "N14Scavenger", name: "Scavenger", department: "Wasteland", icon: "job_ShaftMiner"),
        SS14Job(id: "N14Wastelander", name: "Wastelander", department: "Wasteland", icon: "job_Passenger"),
        SS14Job(id: "N14WasteTrader", name: "Wasteland Trader", department: "Wasteland", icon: "job_CargoTechnician"),
        SS14Job(id: "N14Musician", name: "Musician", department: "Wasteland", icon: "job_Musician"),
        SS14Job(id: "N14Survivor", name: "Survivor", department: "Wasteland", icon: "job_Passenger"),
    ]

    /// Station departments, then the wasteland ones from Nuclear 14.
    static var allDepartments: [String] { SS14.departmentOrder + nuclear14Departments }
    static var allJobs: [SS14Job] { SS14.jobs + nuclear14Jobs }

    // MARK: Boot log flavour

    static func bootHeader(for fork: SS14Fork) -> (title: String, subtitle: String, bios: String) {
        switch fork {
        case .vanilla: return ("NANOTRASEN", "Integrated silicon systems", "NANOTRASEN SILICON BIOS v14.0")
        case .goob: return ("GOOB STATION", "Nanotrasen silicon systems (heavily modded)", "GOOBSTATION SILICON BIOS v14.0-goob")
        case .starlight: return ("STARLIGHT", "Nanotrasen silicon kernel", "STARLIGHT // NT SILICON KERNEL 2.4")
        case .nuclear14: return ("TERMINAL OS", "Wasteland Computing Co.", "TERMINAL OS v2.1 — (C) 2077")
        }
    }

    static func bootExtras(for fork: SS14Fork) -> [(String, String)] {
        switch fork {
        case .vanilla: return [("Tuning radio: Common", "OK")]
        case .goob: return [("Merging 9,000 upstream PRs", "OK"), ("Loading accent packs: Ohio", "OK")]
        case .starlight: return [("Polishing the UI", "OK"), ("Petting the borgi", "GOOD BOY")]
        case .nuclear14: return [("Checking radiation levels", "ACCEPTABLE"), ("Scanning for raiders", "NONE")]
        }
    }
}

// MARK: - Job lookup across forks

extension SS14 {
    /// Finds a job on any fork.
    static func anyJob(_ id: String) -> SS14Job? {
        jobs.first { $0.id == id } ?? ForkData.nuclear14Jobs.first { $0.id == id }
    }

    static func forkColor(forDepartment dept: String) -> Color {
        if let hex = ForkData.nuclear14DepartmentHex[dept] { return Color(hex: hex) }
        return color(forDepartment: dept)
    }
}
