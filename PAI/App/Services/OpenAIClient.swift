import Foundation

/// Talks to OpenAI's Responses API (https://api.openai.com/v1/responses).
/// Handles the tool loop: the model can call our local functions (reminders, timers)
/// and OpenAI's built-in web_search tool.
struct OpenAIResult {
    var text: String
    var sources: [ChatSource]
    var responseID: String
}

enum OpenAIError: LocalizedError {
    case http(Int, String)
    case badResponse
    case tooManySteps

    var errorDescription: String? {
        switch self {
        case .http(let code, let message):
            if code == 401 { return "Your API key was rejected (401). Check it in Settings." }
            if code == 429 { return "OpenAI says: \(message) (429). You may need to add credit at platform.openai.com." }
            return "OpenAI error \(code): \(message)"
        case .badResponse: return "Got an unreadable reply from OpenAI."
        case .tooManySteps: return "I got stuck in a loop running tools. Try asking again."
        }
    }
}

typealias ToolHandler = (_ name: String, _ arguments: [String: Any]) async -> String

final class OpenAIClient {
    let apiKey: String
    let model: String
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func respond(userText: String,
                 instructions: String,
                 previousResponseID: String?,
                 tools: [[String: Any]],
                 toolHandler: ToolHandler) async throws -> OpenAIResult {
        var input: [[String: Any]] = [["role": "user", "content": userText]]
        var previousID = previousResponseID
        var sources: [ChatSource] = []

        for _ in 0..<8 {
            var body: [String: Any] = [
                "model": model,
                "instructions": instructions,
                "input": input,
                "tools": tools,
                "store": true,
            ]
            if let previousID { body["previous_response_id"] = previousID }

            let json = try await post(body)
            guard let id = json["id"] as? String,
                  let output = json["output"] as? [[String: Any]] else {
                throw OpenAIError.badResponse
            }
            previousID = id

            var calls: [(callID: String, name: String, arguments: String)] = []
            var text = ""

            for item in output {
                switch item["type"] as? String {
                case "function_call":
                    calls.append((item["call_id"] as? String ?? "",
                                  item["name"] as? String ?? "",
                                  item["arguments"] as? String ?? "{}"))
                case "message":
                    for part in item["content"] as? [[String: Any]] ?? [] {
                        guard part["type"] as? String == "output_text" else { continue }
                        text += part["text"] as? String ?? ""
                        for ann in part["annotations"] as? [[String: Any]] ?? [] {
                            if ann["type"] as? String == "url_citation", let url = ann["url"] as? String {
                                let title = (ann["title"] as? String) ?? url
                                let src = ChatSource(title: title, url: url)
                                if !sources.contains(src) { sources.append(src) }
                            }
                        }
                    }
                default:
                    break
                }
            }

            if calls.isEmpty {
                return OpenAIResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                    sources: sources,
                                    responseID: id)
            }

            // Run our local tools and send the results back.
            input = []
            for call in calls {
                let data = call.arguments.data(using: .utf8) ?? Data()
                let args = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                let result = await toolHandler(call.name, args)
                input.append([
                    "type": "function_call_output",
                    "call_id": call.callID,
                    "output": result,
                ])
            }
        }
        throw OpenAIError.tooManySteps
    }

    /// Quick key check used by Settings.
    func test() async throws -> String {
        let json = try await post(["model": model, "input": "Reply with exactly: ONLINE", "store": false])
        for item in json["output"] as? [[String: Any]] ?? [] {
            for part in item["content"] as? [[String: Any]] ?? [] {
                if let t = part["text"] as? String { return t }
            }
        }
        return "Connected."
    }

    private func post(_ body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.http(code, message)
        }
        return json
    }
}

// MARK: - Tool definitions the AI can use

enum PAITools {
    static func definitions(webSearch: Bool) -> [[String: Any]] {
        func fn(_ name: String, _ description: String,
                _ properties: [String: Any] = [:], required: [String] = []) -> [String: Any] {
            [
                "type": "function",
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ] as [String: Any],
            ]
        }
        func str(_ d: String) -> [String: Any] { ["type": "string", "description": d] }

        var tools: [[String: Any]] = [
            fn("get_current_time", "Get the user's current local date, time and time zone."),
            fn("create_reminder",
               "Add a reminder to the user's PAI calendar. Their phone will get a notification at that time.",
               [
                "title": str("Short reminder text, e.g. 'Call mom'"),
                "datetime": str("Local date and time, ISO 8601 without time zone, e.g. 2026-10-08T17:30:00"),
                "notes": str("Optional extra details"),
                "repeat": ["type": "string", "enum": ["none", "daily", "weekly", "monthly"],
                           "description": "How often it repeats. Default none."] as [String: Any],
               ],
               required: ["title", "datetime"]),
            fn("list_reminders", "List the user's reminders for the next 30 days (with ids)."),
            fn("delete_reminder", "Delete a reminder by id (get ids from list_reminders).",
               ["id": str("Reminder id")], required: ["id"]),
            fn("start_timer", "Start a countdown timer. The phone notifies the user when it ends.",
               [
                "seconds": ["type": "integer", "description": "Length of the timer in seconds"],
                "label": str("Short name, e.g. 'Pasta'"),
               ],
               required: ["seconds"]),
            fn("list_timers", "List the user's running and paused timers (with ids)."),
            fn("cancel_timer", "Cancel/delete a timer by id.", ["id": str("Timer id")], required: ["id"]),
            fn("emote", "Do an SS14 silicon emote. Shows an italic line like \"PAI beeps.\" and plays the matching SS14 sound.",
               ["emote": ["type": "string", "enum": ["beep", "boop", "chime", "ping", "buzz", "buzz-two", "blink"],
                          "description": "Which emote"] as [String: Any]],
               required: ["emote"]),
        ]
        if webSearch { tools.append(["type": "web_search"]) }
        return tools
    }
}
