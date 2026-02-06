//
//  ContentView.swift
//  ZetanInvader Watch App
//
//  Created by aristides lintzeris on 5/2/2026.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var crownValue = 0.0
    @State private var gameController = GameController()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            SpriteView(scene: gameController.scene)
                .ignoresSafeArea()
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: -100,
            through: 100,
            by: 0.5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownValue) { oldValue, newValue in
            gameController.updatePlayerPosition(crownValue: newValue)
        }
        .onTapGesture {
            gameController.fire()
        }
    }
}

class GameController {
    let scene: GameScene
    
    init() {
        scene = GameScene(size: CGSize(width: 200, height: 200))
        scene.scaleMode = .aspectFill
    }
    
    func updatePlayerPosition(crownValue: Double) {
        scene.setPlayerPosition(crownValue)
    }
    
    func fire() {
        scene.handleTap()
    }
}

#Preview {
    ContentView()
}
