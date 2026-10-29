import SwiftUI
import SwiftData
import GoogleGenerativeAI

// A simple struct to track our chat bubbles
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct AdvisorView: View {
    @Query private var assets: [Asset]
    @Environment(\.dismiss) private var dismiss
    
    // Chat State
    @State private var messages: [ChatMessage] = []
    @State private var userInput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var chatSession: Chat?

    var body: some View {
        VStack(spacing: 0) {
            
            // 1. HEADER
            HStack {
                Text("Gemini AI Advisor")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 2. CHAT HISTORY (The scrolling messages)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(alignment: .center, spacing: 10) {
                                Image(systemName: "sparkles.tv")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                Text("Ask Gemini a question about your portfolio, or click 'Auto-Analyze' for a full breakdown.")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        }
                        
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() } // Pushes user messages to the right
                                
                                Text(message.text)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .background(message.isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
                                    .foregroundColor(message.isUser ? .white : .primary)
                                    .cornerRadius(12)
                                    .frame(maxWidth: 400, alignment: message.isUser ? .trailing : .leading)
                                
                                if !message.isUser { Spacer() } // Pushes AI messages to the left
                            }
                        }
                        
                        if isAnalyzing {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Gemini is typing...")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.top, 5)
                        }
                    }
                    .padding()
                }
                // Auto-scroll to the bottom when a new message appears
                .onChange(of: messages.count) { 
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            Divider()
            
            // 3. INPUT AREA
            HStack {
                TextField("Ask about specific stocks, risk, or rebalancing...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { // Allows pressing "Enter" to send
                        Task { await sendMessage(userInput) }
                    }
                    .disabled(isAnalyzing)
                
                Button(action: {
                    Task { await sendMessage(userInput) }
                }) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(userInput.isEmpty || isAnalyzing)
                
                // Keep the original one-click analysis button!
                Button("Auto-Analyze") {
                    Task { await generateInitialAnalysis() }
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzing || !messages.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 550, height: 600) // Taller frame to fit the chat history
        .onAppear {
            // Start a fresh memory session every time you open the window
            chatSession = AIAdvisorService.model.startChat()
        }
    }
    
    // MARK: - Chat Functions
    
    private func generateInitialAnalysis() async {
        let prompt = "Please review my portfolio and give me a concise, actionable analysis on asset concentration, performance, and what I should do next."
        await sendMessage(prompt, isHiddenContext: true)
    }

    private func sendMessage(_ text: String, isHiddenContext: Bool = false) async {
        guard !text.isEmpty, let chat = chatSession else { return }
        
        // 1. Add user message to UI (unless it's the auto-analyze hidden prompt)
        if !isHiddenContext {
            messages.append(ChatMessage(text: text, isUser: true))
            userInput = "" // Clear the text box
        }
        
        isAnalyzing = true
        
        do {
            // 2. If this is the very first message in the chat, silently inject the portfolio data so Gemini knows what you own!
            let fullPrompt = messages.count <= 1 ? AIAdvisorService.buildPortfolioContext(from: assets) + "\n\nUser Question: " + text : text
            
            // 3. Send to Gemini
            let response = try await chat.sendMessage(fullPrompt)
            
            // 4. Add AI response to UI
            if let responseText = response.text {
                messages.append(ChatMessage(text: responseText, isUser: false))
            }
        } catch {
            messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            print("🚨 GEMINI REJECTION REASON: \(error)")
        }
        
        isAnalyzing = false
    }
}
