//
//  ContentView.swift
//  ZetanInvader Watch App
//
//  Created by aristides lintzeris on 5/2/2026.
//

import SwiftUI
import SpriteKit
import WatchKit

struct ContentView: View {
    @State private var scrollAmount = 0.0
    @State private var isGameRunning = false
    @State private var gameScene: GameScene = {
        let scene = GameScene(size: CGSize(width: 200, height: 200)) // Initial placeholder size
        scene.scaleMode = .resizeFill
        return scene
    }()
    @State private var showGameOver = false
    @State private var score = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isGameRunning {
                SpriteView(scene: gameScene)
                    .focusable()
                    .digitalCrownRotation($scrollAmount, from: -10.0, through: 10.0, by: 0.1, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
                    .onChange(of: scrollAmount) { oldValue, newValue in
                        self.gameScene.updatePlayerPosition(scrollAmount: newValue)
                    }
                    .onTapGesture {
                        self.gameScene.playerFire()
                    }
                    .onAppear {
                        setupSceneCallbacks()
                    }
                    .ignoresSafeArea()
            } else {
                // Start Menu
                VStack(spacing: 20) {
                    Text("ZETAN\nINVADER")
                        .font(.custom("Courier", size: 24))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.8), radius: 5)
                    
                    Button(action: startGame) {
                        Text("ENGAGE")
                            .font(.custom("Courier", size: 16))
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                    }
                    .background(Color.green)
                    .clipShape(Capsule())
                }
            }
            
            // Game Over Overlay
            if showGameOver {
                VStack(spacing: 15) {
                    Text("GAME OVER")
                        .font(.custom("Courier", size: 26))
                        .foregroundColor(.red)
                        .shadow(color: .red, radius: 10)
                    
                    Text("SCORE: \(score)")
                        .font(.custom("Courier", size: 18))
                        .foregroundColor(.green)
                    
                    Button("RETRY") {
                        restartGame()
                    }
                    .tint(.green)
                }
                .padding()
                .background(Color.black.opacity(0.85))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green, lineWidth: 2)
                )
            }
        }
    }
    
    func setupSceneCallbacks() {
        gameScene.gameOverAction = {
            WKInterfaceDevice.current().play(.failure)
            withAnimation {
                showGameOver = true
            }
        }
        gameScene.scoreUpdateAction = { newScore in
            self.score = newScore
        }
    }
    
    func startGame() {
        setupSceneCallbacks()
        withAnimation {
            isGameRunning = true
            showGameOver = false
            scrollAmount = 0
            gameScene.startGame()
        }
        WKInterfaceDevice.current().play(.start)
    }
    
    func restartGame() {
        showGameOver = false
        gameScene.startGame()
        WKInterfaceDevice.current().play(.click)
    }
}

#Preview {
    ContentView()
}
