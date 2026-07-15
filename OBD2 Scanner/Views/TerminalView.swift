//
//  TerminalView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType
    
    enum LineType {
        case command, response
    }
    
    var color: Color {
        switch type {
            case .command: return .blue
            case .response: return .gray
        }
    }
}

struct TerminalView: View {
    
    @State private var prompt: String = ""
    @State private var consoleLogs: [TerminalLine] = []
    @FocusState private var isInputFocused: Bool
    @ObservedObject private var obdService: OBDService
    
    init(obdService: OBDService) {
        _obdService = ObservedObject(wrappedValue: obdService)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(consoleLogs) { line in
                                Text(line.text)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(line.color)
                                    .id(line.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color.black)
                    .onChange(of: consoleLogs.count) { _, _ in
                        if let lastId = consoleLogs.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
                
                Divider()
                    .background(Color.gray)
                
                HStack(spacing: 4) {
                    Text(">")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .bold()
                    
                    TextField("", text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .accentColor(.blue)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task {
                                await executeCommand()
                            }
                        }
                }
                .padding()
                .background(Color.black)
            }
            .navigationTitle("Terminal")
        }
    }
    
    @MainActor
    private func executeCommand() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        
        consoleLogs.append(TerminalLine(text: "> \(trimmed)", type: .command))
        let response = await obdService.sendRaw(trimmed)
        consoleLogs.append(TerminalLine(text: response, type: .response))
        prompt = ""
    }
}
