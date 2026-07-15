//
//  SplashScreenView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/10/26.
//

import SwiftUI

struct SplashScreenView: View {
    
    @State private var isAnimating: Bool = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Spacer()
                
                Image(systemName: "engine.combustion")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.7)
                
                VStack(spacing: 8) {
                    Text("OBD-II Scanner")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Bluetooth Vehicle Diagnostics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .tint(.blue)
                        .padding(.top, 16)
                }
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
