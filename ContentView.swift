//
//  ContentView.swift
//  AtomBot
//
//  Created by Mohsin Khan on 10/07/2025.
//

import SwiftUI

// MARK: - Model
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - ViewModel
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var userInput: String = ""
    @Published var isGenerating: Bool = false
    @Published var chatStarted: Bool = false
    @Published var aiTypingText: String = ""
    @Published var showTypingIndicator: Bool = false
    @Published var typingIndicatorDots: Int = 0

    private let chatBot = ChatBot()
    private var typingTimer: Timer?

    var bubbleFont: Font {
        UIScreen.main.bounds.width < 350 ? .callout : .body
    }
    
    var inputFont: Font {
        UIScreen.main.bounds.width < 350 ? .callout : .body
    }
    
    var inputMinHeight: CGFloat {
        UIScreen.main.bounds.height < 700 ? 36 : 44
    }
    
    var inputMaxHeight: CGFloat {
        UIScreen.main.bounds.height < 700 ? 60 : 100
    }
    
    var bubblePadding: CGFloat {
        UIScreen.main.bounds.width < 350 ? 8 : 12
    }
    
    var bubbleHorizontal: CGFloat {
        UIScreen.main.bounds.width < 350 ? 12 : 18
    }

    init() {
        startTypingIndicatorTimer()
    }

    func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        
        if !chatStarted {
            chatStarted = true
        }
        
        let userMsg = ChatMessage(text: trimmed, isUser: true)
        messages.append(userMsg)
        userInput = ""
        isGenerating = true
        aiTypingText = ""
        showTypingIndicator = true
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        chatBot.generateResponse(for: trimmed) { [weak self] response in
            DispatchQueue.main.async {
                self?.showTypingIndicator = false
                self?.animateAITyping(response: self?.cleanLLMResponse(response.isEmpty ? "(No response)" : response) ?? "")
            }
        }
    }

    private func animateAITyping(response: String) {
        aiTypingText = ""
        let chars = Array(response)
        var current = ""
        let interval = 0.018
        
        for (i, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) { [weak self] in
                guard let self = self else { return }
                current.append(char)
                self.aiTypingText = current
                
                if i == chars.count - 1 {
                    let aiMsg = ChatMessage(text: response, isUser: false)
                    self.messages.append(aiMsg)
                    self.aiTypingText = ""
                    self.isGenerating = false
                }
            }
        }
    }

    private func cleanLLMResponse(_ response: String) -> String {
        var cleaned = response
        let tokensToRemove = [
            "<|im_start|>user", "<|im_end|>", "<|im_start|>assistant",
            "<|user|>", "<assistant>", "user:", "assistant:", "\0"
        ]
        
        for token in tokensToRemove {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        
        if let firstUserMsg = messages.last(where: { $0.isUser })?.text, cleaned.hasPrefix(firstUserMsg) {
            cleaned = String(cleaned.dropFirst(firstUserMsg.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        cleaned = cleaned.replacingOccurrences(of: "^assistant:?\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^user:?\\s*", with: "", options: .regularExpression)
        
        return cleaned
    }

    private func startTypingIndicatorTimer() {
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.showTypingIndicator {
                self.typingIndicatorDots = (self.typingIndicatorDots + 1) % 4
            } else {
                self.typingIndicatorDots = 0
            }
        }
    }
}

// MARK: - Views
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatTabView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)
            
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(Color.accentColor)
    }
}

struct ChatTabView: View {
    var body: some View {
        ContentView()
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General")) {
                    Label("Account", systemImage: "person.crop.circle")
                    Label("Notifications", systemImage: "bell")
                }
                Section(header: Text("About")) {
                    Label("Version 1.0", systemImage: "info.circle")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.black) : Color(.systemGroupedBackground)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = false
                    }
                
                VStack(spacing: 0) {
                    ZStack {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.messages) { message in
                                        ChatBubble(
                                            message: message,
                                            colorScheme: colorScheme,
                                            font: viewModel.bubbleFont,
                                            verticalPadding: viewModel.bubblePadding,
                                            horizontalPadding: viewModel.bubbleHorizontal
                                        )
                                        .id(message.id)
                                        .transition(message.isUser ? .move(edge: .trailing).combined(with: .opacity) : .move(edge: .leading).combined(with: .opacity))
                                        .animation(.easeOut(duration: 0.25), value: viewModel.messages)
                                    }
                                    
                                    if viewModel.showTypingIndicator {
                                        HStack(alignment: .bottom) {
                                            TypingIndicatorView(
                                                dots: viewModel.typingIndicatorDots,
                                                font: viewModel.bubbleFont,
                                                verticalPadding: viewModel.bubblePadding,
                                                horizontalPadding: viewModel.bubbleHorizontal
                                            )
                                            Spacer()
                                        }
                                        .transition(.opacity)
                                    }
                                    
                                    if viewModel.isGenerating && !viewModel.aiTypingText.isEmpty {
                                        ChatBubble(
                                            message: ChatMessage(text: viewModel.aiTypingText, isUser: false),
                                            isTyping: true,
                                            colorScheme: colorScheme,
                                            font: viewModel.bubbleFont,
                                            verticalPadding: viewModel.bubblePadding,
                                            horizontalPadding: viewModel.bubbleHorizontal
                                        )
                                        .id("aiTyping")
                                        .transition(.opacity)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                            }
                            .background(backgroundColor)
                            .onChange(of: viewModel.messages) { _ in
                                if let last = viewModel.messages.last {
                                    withAnimation {
                                        scrollProxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: viewModel.aiTypingText) { _ in
                                if viewModel.isGenerating {
                                    withAnimation {
                                        scrollProxy.scrollTo("aiTyping", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.chatStarted {
                            backgroundColor
                                .ignoresSafeArea()
                                .transition(.opacity)
                            
                            VStack {
                                Spacer()
                                Text("Atom chatbot")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(Color.accentColor)
                                    .shadow(radius: 4)
                                Spacer()
                            }
                            .transition(.opacity)
                            .allowsHitTesting(false)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 6) {
                        TextField("Ask me Anything", text: $viewModel.userInput, axis: .vertical)
                            .font(viewModel.inputFont)
                            .frame(minHeight: 36, maxHeight: 44)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .focused($isInputFocused)
                            .disabled(viewModel.isGenerating)
                            .accessibilityLabel("Message input")
                        
                        Button(action: viewModel.sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating ? .gray : Color.accentColor)
                                .font(.system(size: 22, weight: .bold))
                                .accessibilityLabel("Send message")
                        }
                        .disabled(viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                    }
                    .frame(minHeight: 44, maxHeight: 52)
                    .padding(.horizontal, 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 4)
                    .background(.ultraThinMaterial)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .animation(.easeInOut, value: colorScheme)
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var isTyping: Bool = false
    var colorScheme: ColorScheme
    var font: Font = .body
    var verticalPadding: CGFloat = 12
    var horizontalPadding: CGFloat = 18

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
            HStack {
                if message.isUser {
                    Spacer(minLength: 40)
                }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                    Text(message.text)
                        .font(isTyping ? font.italic() : font)
                        .foregroundColor(message.isUser ? .white : (colorScheme == .dark ? .white : .primary))
                        .padding(.vertical, verticalPadding)
                        .padding(.horizontal, horizontalPadding)
                        .background(
                            message.isUser ? Color.accentColor : (colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color(.black).opacity(0.10), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(colorScheme == .dark ? Color(.systemGray3) : Color(.systemGray4), lineWidth: message.isUser ? 0 : 1)
                        )
                        .lineSpacing(4)
                        .multilineTextAlignment(message.isUser ? .trailing : .leading)
                        .animation(.easeInOut, value: colorScheme)
                }
                
                if !message.isUser {
                    Spacer(minLength: 40)
                }
            }
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(message.isUser ? .trailing : .leading, horizontalPadding)
                .padding(.top, 2)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

struct TypingIndicatorView: View {
    let dots: Int
    var font: Font = .body
    var verticalPadding: CGFloat = 12
    var horizontalPadding: CGFloat = 18
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Atom is typing")
                .font(font.italic())
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundColor(.secondary)
                        .opacity(dots > i ? 1 : 0.3)
                        .scaleEffect(dots == i + 1 ? 1.2 : 1)
                        .animation(.easeInOut(duration: 0.3), value: dots)
                }
            }
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(Color(.systemGray5).opacity(0.7))
        .clipShape(Capsule())
        .shadow(color: Color(.black).opacity(0.07), radius: 2, x: 0, y: 1)
    }
}

@main
struct AtomBotApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}


#Preview {
    ContentView()
}
