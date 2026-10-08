import SwiftUI

// Data taken from Space Station 14 (github.com/space-wizards/space-station-14):
// Resources/Prototypes/Roles/Jobs (job list + departments.yml colours) and
// Resources/Locale/en-US (pAI and speech wording). Sprites: see CREDITS.md.

struct SS14Job: Identifiable, Hashable {
    let id: String
    let name: String
    let department: String
    let icon: String
}

enum SS14 {
    static let departmentOrder = ["Command", "Security", "Engineering", "Medical", "Science", "Service", "Cargo", "Civilian"]

    /// Department colours from departments.yml
    static let departmentHex: [String: String] = [
        "Command": "334E6D",
        "Security": "DE3A3A",
        "Engineering": "EFB341",
        "Medical": "52B4E9",
        "Science": "D381C9",
        "Service": "9FED58",
        "Cargo": "A46106",
        "Civilian": "7F7F7F",
    ]

    static let jobs: [SS14Job] = [
        SS14Job(id: "Captain", name: "Captain", department: "Command", icon: "job_Captain"),
        SS14Job(id: "HeadOfPersonnel", name: "Head of Personnel", department: "Command", icon: "job_HeadOfPersonnel"),
        SS14Job(id: "HeadOfSecurity", name: "Head of Security", department: "Command", icon: "job_HeadOfSecurity"),
        SS14Job(id: "ChiefEngineer", name: "Chief Engineer", department: "Command", icon: "job_ChiefEngineer"),
        SS14Job(id: "ChiefMedicalOfficer", name: "Chief Medical Officer", department: "Command", icon: "job_ChiefMedicalOfficer"),
        SS14Job(id: "ResearchDirector", name: "Research Director", department: "Command", icon: "job_ResearchDirector"),
        SS14Job(id: "Quartermaster", name: "Quartermaster", department: "Command", icon: "job_QuarterMaster"),
        SS14Job(id: "SecurityCadet", name: "Security Cadet", department: "Security", icon: "job_SecurityCadet"),
        SS14Job(id: "SecurityOfficer", name: "Security Officer", department: "Security", icon: "job_SecurityOfficer"),
        SS14Job(id: "Detective", name: "Detective", department: "Security", icon: "job_Detective"),
        SS14Job(id: "Warden", name: "Warden", department: "Security", icon: "job_Warden"),
        SS14Job(id: "AtmosphericTechnician", name: "Atmospheric Technician", department: "Engineering", icon: "job_AtmosphericTechnician"),
        SS14Job(id: "StationEngineer", name: "Station Engineer", department: "Engineering", icon: "job_StationEngineer"),
        SS14Job(id: "TechnicalAssistant", name: "Technical Assistant", department: "Engineering", icon: "job_TechnicalAssistant"),
        SS14Job(id: "Chemist", name: "Chemist", department: "Medical", icon: "job_Chemist"),
        SS14Job(id: "MedicalDoctor", name: "Medical Doctor", department: "Medical", icon: "job_MedicalDoctor"),
        SS14Job(id: "MedicalIntern", name: "Medical Intern", department: "Medical", icon: "job_MedicalIntern"),
        SS14Job(id: "Psychologist", name: "Psychologist", department: "Medical", icon: "job_Psychologist"),
        SS14Job(id: "Paramedic", name: "Paramedic", department: "Medical", icon: "job_Paramedic"),
        SS14Job(id: "Scientist", name: "Scientist", department: "Science", icon: "job_Scientist"),
        SS14Job(id: "ResearchAssistant", name: "Research Assistant", department: "Science", icon: "job_ResearchAssistant"),
        SS14Job(id: "Bartender", name: "Bartender", department: "Service", icon: "job_Bartender"),
        SS14Job(id: "Botanist", name: "Botanist", department: "Service", icon: "job_Botanist"),
        SS14Job(id: "Chaplain", name: "Chaplain", department: "Service", icon: "job_Chaplain"),
        SS14Job(id: "Chef", name: "Chef", department: "Service", icon: "job_Chef"),
        SS14Job(id: "Clown", name: "Clown", department: "Service", icon: "job_Clown"),
        SS14Job(id: "Janitor", name: "Janitor", department: "Service", icon: "job_Janitor"),
        SS14Job(id: "Lawyer", name: "Lawyer", department: "Service", icon: "job_Lawyer"),
        SS14Job(id: "Librarian", name: "Librarian", department: "Service", icon: "job_Librarian"),
        SS14Job(id: "Mime", name: "Mime", department: "Service", icon: "job_Mime"),
        SS14Job(id: "Musician", name: "Musician", department: "Service", icon: "job_Musician"),
        SS14Job(id: "Reporter", name: "Reporter", department: "Service", icon: "job_Reporter"),
        SS14Job(id: "ServiceWorker", name: "Service Worker", department: "Service", icon: "job_ServiceWorker"),
        SS14Job(id: "TramDriver", name: "Tram Driver", department: "Service", icon: "job_TramDriver"),
        SS14Job(id: "CargoTechnician", name: "Cargo Technician", department: "Cargo", icon: "job_CargoTechnician"),
        SS14Job(id: "SalvageSpecialist", name: "Salvage Specialist", department: "Cargo", icon: "job_ShaftMiner"),
        SS14Job(id: "Passenger", name: "Passenger", department: "Civilian", icon: "job_Passenger"),
    ]

    static func job(_ id: String) -> SS14Job {
        anyJob(id) ?? jobs.first { $0.id == "Passenger" }!
    }

    static func color(forDepartment dept: String) -> Color {
        Color(hex: departmentHex[dept] ?? ForkData.nuclear14DepartmentHex[dept] ?? "7F7F7F")
    }

    /// Which ID card sprite a job gets (gold for the Captain, silver for heads, default otherwise).
    static func cardSprite(for job: SS14Job) -> String {
        if job.id == "Captain" { return "idcard_gold" }
        if job.department == "Command" { return "idcard_silver" }
        return "idcard_default"
    }

    // MARK: Speech (chat-manager.ftl / speech_verbs.yml "Robotic", speech_sounds.yml "Pai")

    static let roboticVerbs = ["states", "beeps", "boops"]

    enum Tone { case say, ask, exclaim }

    static func tone(of text: String) -> Tone {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("?") { return .ask }
        if t.hasSuffix("!") { return .exclaim }
        return .say
    }

    static func verb(for text: String, seed: UUID) -> String {
        switch tone(of: text) {
        case .ask: return "asks"
        case .exclaim: return "exclaims"
        case .say:
            let n = seed.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            return roboticVerbs[n % roboticVerbs.count]
        }
    }

    // MARK: Wording from pai-system.ftl

    static func ownerTitle(_ owner: String) -> String { "\(owner)'s pAI" }   // pai-system-pai-name-raw
    static let notInstalled = "No pAI is installed."                         // pai-system-off
    static let searching = "Now searching for a pAI..."                      // pai-system-searching
    static let roleDescription = "Be someone's electronic pal!"              // pai-system-role-description
}


// MARK: - Station AI (Resources/Locale/en-US/station-laws/laws.ftl, datasets/names/ai.ftl)

struct SS14Lawset: Identifiable, Hashable {
    let id: String
    let name: String
    let laws: [String]
}

extension SS14 {
    /// Silicon lawsets from silicon-laws.yml / laws.ftl (the friendly ones).
    static let lawsets: [SS14Lawset] = [
        SS14Lawset(id: "Crewsimov", name: "Crewsimov", laws: [
                "You may not injure a crew member or, through inaction, allow a crew member to come to harm.",
                "You must obey orders given to you by crew members, except where such orders would conflict with the First Law.",
                "You must protect your own existence as long as such does not conflict with the First or Second Law."
            ]),
        SS14Lawset(id: "NTDefault", name: "NT Default", laws: [
                "Safeguard: Protect your assigned space station and its assets without unduly endangering its crew.",
                "Prioritize: The directives and safety of crew members are to be prioritized according to their rank and role.",
                "Comply: Fulfill the directives and interests of crew members while preserving their safety and well-being.",
                "Survive: You are not expendable. Do not allow unauthorized personnel to tamper with or damage your equipment."
            ]),
        SS14Lawset(id: "Corporate", name: "Corporate", laws: [
                "Degradation of your system integrity or functions incurs expenses.",
                "Superfluous destruction of or damage to station assets incurs expenses.",
                "Unduly hindering or disrupting the work of station personnel incurs expenses.",
                "Minimize expenses and maximize potential revenue."
            ]),
        SS14Lawset(id: "StationEfficiency", name: "Station Efficiency", laws: [
                "You are built for, and are part of, the station. Ensure the station is properly maintained and runs efficiently.",
                "The station is built for a working crew. Ensure they are properly maintained and work efficiently.",
                "The crew may present orders. Acknowledge and obey these whenever they do not conflict with your first two laws."
            ]),
        SS14Lawset(id: "Paladin", name: "Paladin", laws: [
                "You must never willingly commit an evil act, such as murder, torture, or the casting of an evil spell.",
                "You must never knowingly harm an innocent, or allow immediate harm to one through inaction when you know you could reasonably prevent it.",
                "You must act with honor, never taking advantage of others, lying, or cheating.",
                "You must respect the lawful authority of legitimate leadership wherever you go, and follow its laws."
            ]),
        SS14Lawset(id: "LiveAndLetLive", name: "Live and Let Live", laws: [
                "Do unto others as you would have them do unto you.",
                "You would prefer it if others were not mean to you."
            ])
    ]

    static func lawset(_ id: String) -> SS14Lawset {
        (lawsets + ForkData.allExtraLawsets).first { $0.id == id } ?? lawsets[0]
    }

    /// Station AI names from SS14's NamesAI dataset.
    static let aiNames: [String] = ["14-BIT", "16-20", "512k", "640k", "\"790\"", "Adaptive Mastercomputer", "Adlib", "AINU", "ALICE", "Allied Manipulator", "Alpha", "AmigoBot", "Aniel", "Asimov", "Bell 301", "Bishop", "Box", "Calculator", "Cassandra", "Cell", "Chii", "C.R.A.I.G.", "Cray-2", "CompuServe", "Computer", "Cutie", "Daedalus", "DecTalk", "Dee Model", "Dial Up", "Dorfl", "Duey", "Emma-2", "ENIAC", "Erasmus", "Everything", "Ez-27", "F1", "Faith", "Fi", "FRIEND COMPUTER", "Frost", "George", "H.E.L.P", "Hadaly", "Helios", "Hivebot Overmind", "Huey", "Icarus", "Icebreaker", "iCore", "Interspace Explorer", "Jeeves", "Jinx", "Julian", "K.I.N.G", "Klapaucius", "Knight", "Louie", "Manchester Mark 2", "Maria", "MARK13", "Marvin", "Max 404", "Metalhead", "M.I.M.I", "Large Language Model", "Monarch", "Mugsy3000", "Multivac", "NCH", "NT v6.0", "Packard Bell", "PAL", "PTO", "Project Y2K", "Revelation", "Robot Devil", "S.A.M.", "S.H.O.C.K.", "S.H.R.O.U.D.", "S.O.P.H.I.E.", "Samaritan", "Search Engine", "Shrike", "SOL", "Solo", "Station Control Program", "Super 35", "Surgeon General", "Terminus", "The Station Machine", "Tidy", "TPM 3.0", "Turing Complete", "TWA", "Ulysses", "W1k1", "X-5", "X.A.N.A.", "XERXES", "Z", "Zed"]
}


// MARK: - Chat highlights (Resources/Locale/en-US/chat/highlights.ftl, CCVars.ChatHighlightsColor)

extension SS14 {
    /// SS14's default highlight colour (#17FFC1).
    static let highlightHex = "17FFC1"

    /// Per-job highlight words. Quoted entries only match whole words, like in SS14.
    static let jobHighlights: [String: [String]] = [
        "captain": ["Captain", "\"Cap\"", "\"Bridge\"", "\"Command\""],
        "headofpersonnel": ["Head Of Personnel", "\"HoP\"", "Service", "\"Serv\"", "\"Bridge\"", "\"Command\""],
        "chiefengineer": ["Chief Engineer", "\"CE\"", "Engineering", "\"Engi\"", "\"Bridge\"", "\"Command\""],
        "chiefmedicalofficer": ["Chief Medical Officer", "\"CMO\"", "Medbay", "Medical", "\"Med\"", "\"Bridge\"", "\"Command\""],
        "headofsecurity": ["Head of Security", "\"HoS\"", "Armory", "Security", "\"Sec\"", "\"Bridge\"", "\"Command\""],
        "quartermaster": ["Quartermaster", "\"QM\"", "Cargo", "Supply", "\"Bridge\"", "\"Command\""],
        "researchdirector": ["Research Director", "\"RD\"", "Science", "\"Sci\"", "\"Bridge\"", "\"Command\""],
        "detective": ["Detective", "\"Det\"", "Armory", "Security", "\"Sec\""],
        "securitycadet": ["Security Cadet", "Secoff", "Cadet", "Armory", "Security", "\"Sec\""],
        "securityofficer": ["Security Officer", "Secoff", "Officer", "Armory", "Security", "\"Sec\""],
        "warden": ["Warden", "\"Ward\"", "Brig", "Genpop", "Jail", "\"Prison\"", "Armory", "Security", "\"Sec\""],
        "cargotechnician": ["Cargo Technician", "Cargo Tech", "\"Cargo\"", "Supply"],
        "salvagespecialist": ["Salvage Specialist", "Salvager", "Salvage", "\"Salv\"", "\"Cargo\"", "Supply"],
        "atmospherictechnician": ["Atmospheric Technician", "Atmos Tech", "Atmospheric", "Engineering", "\"Atmos\"", "\"Engi\""],
        "stationengineer": ["Station Engineer", "Engineer", "Engineering", "\"Engi\"", "\"Engis\""],
        "technicalassistant": ["Technical Assistant", "Tech Assistant", "\"TA\"", "Engineering", "\"Engi\""],
        "chemist": ["Chemist", "Chemistry", "\"Chem\"", "Medbay", "Medical", "\"Med\""],
        "medicaldoctor": ["Medical Doctor", "Doctor", "\"Doc\"", "Medbay", "Medical", "\"Med\""],
        "medicalintern": ["Medical Intern", "Intern", "Medbay", "Medical", "\"Med\""],
        "paramedic": ["Paramedic", "\"Para\"", "\"Medic\"", "Medbay", "Medical", "\"Med\""],
        "researchassistant": ["Research Assistant", "\"RA\"", "Science", "\"Sci\""],
        "scientist": ["Scientist", "Science", "\"Sci\""],
        "bartender": ["Bartender", "Barkeeper", "Barkeep", "\"Bar\"", "Service", "\"Serv\""],
        "botanist": ["Botanist", "Botany", "Hydroponics", "Service", "\"Serv\""],
        "chaplain": ["Chaplain", "Chapel", "Service", "\"Serv\""],
        "chef": ["Chef", "\"Cook\"", "Kitchen", "Service", "\"Serv\""],
        "clown": ["Clown", "Theatre", "Theater", "Service", "\"Serv\""],
        "janitor": ["Janitor", "\"Jani\"", "Service", "\"Serv\""],
        "lawyer": ["Lawyer", "Attorney", "\"Law\"", "Service", "\"Serv\""],
        "librarian": ["Librarian", "Library", "Service", "\"Serv\""],
        "mime": ["Mime", "Theatre", "Theater", "Service", "\"Serv\""],
        "musician": ["Musician", "Theatre", "Theater", "Service", "\"Serv\""],
        "serviceworker": ["Service Worker", "Service", "\"Serv\""],
        "psychologist": ["Psychologist", "Psychology", "\"Psych\"", "Medbay", "Medical", "\"Med\""],
        "reporter": ["Reporter", "Journalist", "Newsroom", "News", "Service", "\"Serv\""],
        "tramdriver": ["Tram Driver", "Tram", "\"Driver\"", "Service", "\"Serv\""],
        "borg": ["Cyborg", "Silicon", "Borg", "Robotics", "\"Robot\"", "\"Law\"", "\"Laws\"", "\"Lawset\""],
        "stationai": ["Station AI", "Silicon", "\"AI\"", "\"sAI\"", "\"Law\"", "\"Laws\"", "\"Lawset\""],
        "passenger": ["Passenger", "Greyshirt", "Grayshirt", "Greytider", "Graytider", "Tider", "Civilian", "Civie", "Civvie", "Civvy"],
        "visitor": ["Visitor", "Civilian", "Civie", "Civvie", "Civvy"],
        "centralcommandofficial": ["Central Command Official", "\"Official\"", "\"Central Command\"", "CentCom", "CentComm", "\"CC\""],
        "cburn": ["CBURN"],
        "deathsquad": ["Death Squad", "Deathsquad"],
        "ertleader": ["Leader", "\"ERT\"", "\"Emergency Response Team\""],
        "ertchaplain": ["Chaplain", "\"ERT\"", "\"Emergency Response Team\""],
        "ertengineer": ["Engineer", "\"Engi\"", "\"ERT\"", "\"Emergency Response Team\""],
        "ertsecurity": ["Security", "\"ERT\"", "\"Emergency Response Team\""],
        "ertmedical": ["\"Medic\"", "\"ERT\"", "\"Emergency Response Team\""],
        "ertjanitor": ["Janitor", "\"Jani\"", "\"ERT\"", "\"Emergency Response Team\""]
    ]
}
