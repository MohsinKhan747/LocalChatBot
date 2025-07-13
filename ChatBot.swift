//
//  ChatBot.swift
//  AtomBot
//
//  Created by Mohsin Khan on 11/07/2025.
//

import LLM
import Foundation

class ChatBot: ObservableObject {
    let llm: LLM

    init() {
        guard let modelURL = Bundle.main.url(forResource: "tinyllama-1.1b-chat-v1.0.Q4_K_M", withExtension: "gguf") else {
            print("Model not found in bundle.")
            fatalError("Model not found in bundle.")
        }
        let systemPrompt = "You are a helpful assistant."
        guard let llm = LLM(from: modelURL, template: .chatML(systemPrompt)) else {
            print("Failed to load model from \(modelURL)")
            fatalError("Failed to load model.")
        }
        print("Model loaded successfully from \(modelURL)")
        self.llm = llm
    }

    func generateResponse(for prompt: String, completion: @escaping (String) -> Void) {
        Task {
            let templates: [(String, Template)] = [
                ("chatML", .chatML("You are a helpful assistant.")),
                ("llama", .llama("You are a helpful assistant.")),
                ("alpaca", .alpaca("You are a helpful assistant."))
            ]
            var response: String = ""
            for (templateName, template) in templates {
                print("Trying template: \(templateName)")
                guard let modelURL = Bundle.main.url(forResource: "tinyllama-1.1b-chat-v1.0.Q4_K_M", withExtension: "gguf") else {
                    print("Model not found in bundle.")
                    continue
                }
                guard let llm = LLM(from: modelURL, template: template) else {
                    print("Failed to load model from \(modelURL) with template \(templateName)")
                    continue
                }
                let processedPrompt = llm.preprocess(prompt, llm.history)
                print("Prompt sent to model (\(templateName)): \n\(processedPrompt)")
                response = await llm.getCompletion(from: prompt)
                if !response.isEmpty && response != "LLM is being used" {
                    print("LLM response (\(templateName)): \(response)")
                    break
                } else {
                    print("LLM returned empty or busy for template \(templateName)")
                }
            }
            completion(response)
        }
    }
}

