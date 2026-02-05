//
//  GameScene.swift
//  ZetanInvader Watch App
//
//  Created by aristides lintzeris on 5/2/2026.
//

import SpriteKit
import SwiftUI
import WatchKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    var player: SKSpriteNode?
    var scoreLabel: SKLabelNode!
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var gameTimer: Timer?
    var isGameOver = false
    
    // Binding for game over state to communicate back to SwiftUI
    var gameOverAction: (() -> Void)?
    var scoreUpdateAction: ((Int) -> Void)?
    
    // Difficulty
    var difficultyLevel = 1
    var spawnInterval = 1.0
    
    // Category BitMasks
    let playerCategory: UInt32 = 0x1 << 0
    let alienCategory: UInt32 = 0x1 << 1
    let asteroidCategory: UInt32 = 0x1 << 2
    let projectileCategory: UInt32 = 0x1 << 3
    
    // MARK: - Lifecycle
    override func sceneDidLoad() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor.black
        
        if player == nil {
            setupPlayer()
            setupScore()
        }
    }
    
    // MARK: - Setup
    func setupPlayer() {
        // Placeholder: Green Triangle for Spaceship
        guard let uiImage = UIImage(systemName: "arrow.up.circle.fill") else { return }
        let texture = SKTexture(image: uiImage)
        let playerNode = SKSpriteNode(texture: texture)
        playerNode.color = .green
        playerNode.colorBlendFactor = 1.0
        playerNode.size = CGSize(width: 40, height: 40)
        playerNode.position = CGPoint(x: frame.midX, y: frame.minY + 50)
        
        playerNode.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        playerNode.physicsBody?.isDynamic = true
        playerNode.physicsBody?.categoryBitMask = playerCategory
        playerNode.physicsBody?.contactTestBitMask = alienCategory | asteroidCategory
        playerNode.physicsBody?.collisionBitMask = 0 // No physical bounce
        
        self.player = playerNode
        addChild(playerNode)
    }
    
    func setupScore() {
        scoreLabel = SKLabelNode(fontNamed: "Courier") // Retro font
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .green
        scoreLabel.position = CGPoint(x: frame.minX + 10, y: frame.maxY - 30)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)
    }
    
    func startGame() {
        isGameOver = false
        score = 0
        difficultyLevel = 1
        spawnInterval = 1.0
        
        // Clear existing game objects
        enumerateChildNodes(withName: "enemy") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "projectile") { node, _ in node.removeFromParent() }
        
        // Reset player position
        player?.position = CGPoint(x: frame.midX, y: frame.minY + 50)
        
        // Spawn timer
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(timeInterval: spawnInterval, target: self, selector: #selector(spawnEnemy), userInfo: nil, repeats: true)
    }
    
    // MARK: - Game Logic
    
    // Called from SwiftUI to update player position
    func updatePlayerPosition(scrollAmount: Double) {
        guard !isGameOver else { return }
        
        // Map scroll amount to x position.
        // Assuming scrollAmount is continuous, we might interpret it as delta or absolute position.
        // For absolute control feeling:
        
        let newX = frame.midX + (CGFloat(scrollAmount) * 20) // Sensitivity multiplier
        
        // Clamp to screen bounds
        let clampedX = max(frame.minX + 20, min(frame.maxX - 20, newX))
        
        player?.position.x = clampedX
    }

    func playerFire() {
        guard !isGameOver, let player = player else { return }
        
        let projectile = SKSpriteNode(color: SKColor.green, size: CGSize(width: 3, height: 10))
        projectile.name = "projectile"
        projectile.position = CGPoint(x: player.position.x, y: player.position.y + 25)
        
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = projectileCategory
        projectile.physicsBody?.contactTestBitMask = alienCategory
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(projectile)
        
        let moveAction = SKAction.moveBy(x: 0, y: frame.height, duration: 1.0)
        let removeAction = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([moveAction, removeAction]))
    }
    
    @objc func spawnEnemy() {
        guard !isGameOver else { return }
        
        let isAsteroid = Bool.random()
        
        let enemy = isAsteroid ? createAsteroid() : createAlien()
        enemy.name = "enemy"
        
        // Random X position
        let randomX = CGFloat.random(in: frame.minX + 20...frame.maxX - 20)
        enemy.position = CGPoint(x: randomX, y: frame.maxY + 20)
        
        addChild(enemy)
        
        // Move downwards
        let duration = Double.random(in: 2.0...4.0)
        let moveAction = SKAction.moveTo(y: frame.minY - 50, duration: duration)
        let removeAction = SKAction.removeFromParent()
        let scoreAction = SKAction.run { [weak self] in
            guard let self = self, !self.isGameOver else { return }
            self.score += 1
            self.scoreUpdateAction?(self.score)
            
            // Difficulty Progression
            if self.score % 5 == 0 {
                self.increaseDifficulty()
            }
        }
        
        enemy.run(SKAction.sequence([moveAction, scoreAction, removeAction]))
    }
    
    func createAlien() -> SKSpriteNode {
        // Placeholder: Green Square/Invader
        let uiImage = UIImage(systemName: "ant.fill") ?? UIImage()
        let texture = SKTexture(image: uiImage)
        let node = SKSpriteNode(texture: texture)
        node.color = SKColor.green
        node.colorBlendFactor = 1.0
        node.size = CGSize(width: 30, height: 30)
        
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.categoryBitMask = alienCategory
        node.physicsBody?.contactTestBitMask = playerCategory
        node.physicsBody?.collisionBitMask = 0
        
        return node
    }
    
    func createAsteroid() -> SKSpriteNode {
        // Placeholder: Green Circle/Rock
        let uiImage = UIImage(systemName: "circle.fill") ?? UIImage()
        let texture = SKTexture(image: uiImage)
        let node = SKSpriteNode(texture: texture)
        node.color = SKColor.green
        node.colorBlendFactor = 1.0
        node.size = CGSize(width: 35, height: 35)
        
        node.physicsBody = SKPhysicsBody(circleOfRadius: 17)
        node.physicsBody?.categoryBitMask = asteroidCategory
        node.physicsBody?.contactTestBitMask = playerCategory
        node.physicsBody?.collisionBitMask = 0
        
        return node
    }
    
    // MARK: - Collision Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        
        // Player Collision
        let isPlayerA = maskA == playerCategory
        let isPlayerB = maskB == playerCategory
        let isEnemyA = (maskA == alienCategory || maskA == asteroidCategory)
        let isEnemyB = (maskB == alienCategory || maskB == asteroidCategory)
        
        if (isPlayerA && isEnemyB) || (isPlayerB && isEnemyA) {
            gameOver()
        }
        
        // Projectile Collision
        if (maskA == projectileCategory && maskB == alienCategory) || (maskA == alienCategory && maskB == projectileCategory) {
            if let projectile = (maskA == projectileCategory ? contact.bodyA.node : contact.bodyB.node),
               let alien = (maskA == alienCategory ? contact.bodyA.node : contact.bodyB.node) {
                
                createExplosion(at: alien.position)
                projectile.removeFromParent()
                alien.removeFromParent()
                
                // Bonus score for shooting
                score += 5
                scoreUpdateAction?(score)
            }
        }
    }
    
    func increaseDifficulty() {
        difficultyLevel += 1
        spawnInterval = max(0.4, spawnInterval * 0.9)
        
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(timeInterval: spawnInterval, target: self, selector: #selector(spawnEnemy), userInfo: nil, repeats: true)
    }

    func gameOver() {
        isGameOver = true
        gameTimer?.invalidate()
        removeAllActions()
        
        // Explosion Effect
        if let player = player {
            createExplosion(at: player.position)
        }
        
        // Screen Shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -10, y: 0, duration: 0.05),
            SKAction.moveBy(x: 20, y: 0, duration: 0.1),
            SKAction.moveBy(x: -20, y: 0, duration: 0.1),
            SKAction.moveBy(x: 10, y: 0, duration: 0.05)
        ])
        scene?.anchorPoint = CGPoint(x: 0.5, y: 0.5) // Ensure shake works from center
        scene?.run(shake)
        
        // Delay Game Over wrapper to show explosion
        run(SKAction.wait(forDuration: 0.5)) { [weak self] in
            self?.gameOverAction?()
        }
    }
    
    func createExplosion(at position: CGPoint) {
        if let emitter = SKEmitterNode(fileNamed: "Explosion") {
            emitter.position = position
            addChild(emitter)
        } else {
            // Fallback programmatic particle
            let emitter = SKEmitterNode()
            if let uiImage = UIImage(systemName: "sparkles") {
                emitter.particleTexture = SKTexture(image: uiImage)
            }
            emitter.particleBirthRate = 100
            emitter.numParticlesToEmit = 50
            emitter.particleLifetime = 0.5
            emitter.particleSpeed = 100
            emitter.particleSpeedRange = 50
            emitter.emissionAngle = 0
            emitter.emissionAngleRange = 360 * (.pi / 180)
            emitter.particleAlpha = 1.0
            emitter.particleAlphaSpeed = -2.0
            emitter.particleScale = 0.5
            emitter.particleScaleSpeed = -0.5
            emitter.particleColor = .green
            emitter.particleColorBlendFactor = 1.0
            emitter.position = position
            addChild(emitter)
        }
    }
}
