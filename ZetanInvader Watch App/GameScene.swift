//
//  GameScene.swift
//  ZetanInvader Watch App
//
//  Created by aristides lintzeris on 5/2/2026.
//

import SpriteKit
import SwiftUI
import WatchKit

// MARK: - Collision Categories
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0x1 << 0
    static let alien: UInt32 = 0x1 << 1
    static let obstacle: UInt32 = 0x1 << 2
    static let projectile: UInt32 = 0x1 << 3
    static let alienProjectile: UInt32 = 0x1 << 4
    static let floor: UInt32 = 0x1 << 5
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    var player: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    
    var aliens: [SKSpriteNode] = []
    var alienDirection: CGFloat = 1.0 // 1.0 for right, -1.0 for left
    var alienMoveSpeed: CGFloat = 10.0
    var lastAlienMoveTime: TimeInterval = 0
    var alienMoveInterval: TimeInterval = 0.8 // Move every 0.8 seconds (stepped movement)
    
    var score: Int = 0 {
        didSet {
            scoreLabel?.text = "Score: \(score)"
            scoreUpdateAction?(score)
        }
    }
    
    var isGameOver = false
    
    // Binding callbacks
    var gameOverAction: (() -> Void)?
    var scoreUpdateAction: ((Int) -> Void)?
    
    // MARK: - Lifecycle
    override func sceneDidLoad() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor.black
        
        // Initial setup for static elements if needed, 
        // but main setup happens in didMove(to:) or startGame()
        if player == nil {
            setupUI()
        }
    }
    
    // MARK: - Setup
    func setupUI() {
        // Score Label
        scoreLabel = SKLabelNode(fontNamed: "Courier")
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 16
        scoreLabel.fontColor = .green
        scoreLabel.position = CGPoint(x: frame.minX + 10, y: frame.maxY - 25)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.zPosition = 100
        addChild(scoreLabel)
    }
    
    func setupPlayer() {
        // Ship Texture
        let texture = SKTexture(imageNamed: "ship_1")
        player = SKSpriteNode(texture: texture)
        player.color = .green
        player.colorBlendFactor = 1.0 // Apply tint if needed, or rely on texture
        player.size = CGSize(width: 30, height: 20)
        player.position = CGPoint(x: frame.midX, y: frame.minY + 30)
        player.name = "player"
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.alien | PhysicsCategory.alienProjectile
        player.physicsBody?.collisionBitMask = 0
        
        addChild(player)
    }
    
    func setupAliens() {
        aliens.removeAll()
        alienDirection = 1.0
        alienMoveInterval = 0.8
        
        let startX = frame.minX + 30
        let startY = frame.maxY - 40
        let xSpacing: CGFloat = 25
        let ySpacing: CGFloat = 20
        
        // 4 rows, 5 columns (adjust based on watch screen size)
        for row in 0..<4 {
            for col in 0..<5 {
                let alien = createAlien(row: row, col: col)
                let x = startX + CGFloat(col) * xSpacing
                let y = startY - CGFloat(row) * ySpacing
                alien.position = CGPoint(x: x, y: y)
                addChild(alien)
                aliens.append(alien)
            }
        }
    }
    
    func createAlien(row: Int, col: Int) -> SKSpriteNode {
        // Cycles through alien textures for rows
        // alien_1...10 mapped to rows/types
        let textureIndex = (row % 5) * 2 + 1 // e.g. row 0 uses alien_1 & alien_2
        let textureName = "alien_\(textureIndex)"
        let texture = SKTexture(imageNamed: textureName)
        
        let node = SKSpriteNode(texture: texture)
        node.name = "alien"
        node.color = .green
        node.colorBlendFactor = 1.0
        node.size = CGSize(width: 20, height: 16)
        
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.categoryBitMask = PhysicsCategory.alien
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.obstacle | PhysicsCategory.projectile
        node.physicsBody?.collisionBitMask = 0
        
        // Animation
        let nextTextureName = "alien_\(textureIndex + 1)"
        let nextTexture = SKTexture(imageNamed: nextTextureName)
        let animation = SKAction.animate(with: [texture, nextTexture], timePerFrame: 0.5)
        node.run(SKAction.repeatForever(animation))
        
        return node
    }
    
    func setupObstacles() {
        // Place 4 obstacles
        let count = 4
        let spacing = frame.width / CGFloat(count)
        let startX = frame.minX + spacing / 2
        let yPos = frame.minY + 60
        
        for i in 0..<count {
            let obstacle = ObstacleNode()
            obstacle.position = CGPoint(x: startX + CGFloat(i) * spacing, y: yPos)
            addChild(obstacle)
        }
    }
    
    // MARK: - Game Loop
    
    func startGame() {
        isGameOver = false
        score = 0
        
        // Clean up
        enumerateChildNodes(withName: "alien") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "obstacle") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "projectile") { node, _ in node.removeFromParent() }
        player?.removeFromParent()
        
        setupPlayer()
        setupAliens()
        setupObstacles()
        
        lastAlienMoveTime = 0
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        // Initial time check
        if lastAlienMoveTime == 0 {
            lastAlienMoveTime = currentTime
        }
        
        // Step movement
        if currentTime - lastAlienMoveTime > alienMoveInterval {
            moveAliens()
            lastAlienMoveTime = currentTime
            
            // Random alien fire
            if Bool.random() && !aliens.isEmpty {
                // alienFire() // TODO: Implement if needed
            }
        }
    }
    
    func moveAliens() {
        var hitEdge = false
        
        // Check edges
        for alien in aliens {
            let nextX = alien.position.x + (alienMoveSpeed * alienDirection)
            if nextX > frame.maxX - 10 || nextX < frame.minX + 10 {
                hitEdge = true
                break
            }
        }
        
        if hitEdge {
            // Move down and reverse
            alienDirection *= -1
            for alien in aliens {
                alien.position.y -= 10
                
                // Game Over check
                if alien.position.y < frame.minY + 60 { // Reached obstacle line
                    gameOver()
                }
            }
            
            // Speed up
            alienMoveInterval = max(0.1, alienMoveInterval * 0.9)
            
        } else {
            // Move sideways
            for alien in aliens {
                alien.position.x += (alienMoveSpeed * alienDirection)
            }
        }
    }
    
    // MARK: - Inputs
    
    func updatePlayerPosition(scrollDelta: Double) {
        guard !isGameOver, let player = player else { return }
        
        // Move by delta * speed
        let moveSpeed: CGFloat = 20.0
        let newX = player.position.x + (CGFloat(scrollDelta) * moveSpeed)
        
        let clampedX = max(frame.minX + 15, min(frame.maxX - 15, newX))
        player.position.x = clampedX
    }
    
    func playerFire() {
        guard !isGameOver, let player = player else { return }
        
        // Simple limit: Max 1 projectile on screen? (Optional classic feel)
        // For now, allow fire.
        
        let projectile = SKSpriteNode(color: .green, size: CGSize(width: 2, height: 8))
        projectile.name = "projectile"
        projectile.position = CGPoint(x: player.position.x, y: player.position.y + 15)
        
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.alien | PhysicsCategory.obstacle
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(projectile)
        
        let move = SKAction.moveBy(x: 0, y: frame.height, duration: 1.0)
        let remove = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([move, remove]))
    }
    
    // MARK: - Collision Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        
        let nodeA = contact.bodyA.node
        let nodeB = contact.bodyB.node
        
        // Projectile vs Alien
        if (maskA == PhysicsCategory.projectile && maskB == PhysicsCategory.alien) ||
           (maskB == PhysicsCategory.projectile && maskA == PhysicsCategory.alien) {
            
            let projectile = maskA == PhysicsCategory.projectile ? nodeA : nodeB
            let alien = maskA == PhysicsCategory.alien ? nodeA : nodeB
            
            if let alien = alien, let projectile = projectile {
                alienHit(alien: alien, projectile: projectile)
            }
        }
        
        // Projectile vs Obstacle
        if (maskA == PhysicsCategory.projectile && maskB == PhysicsCategory.obstacle) ||
           (maskB == PhysicsCategory.projectile && maskA == PhysicsCategory.obstacle) {
            
            let projectile = maskA == PhysicsCategory.projectile ? nodeA : nodeB
            let obstacle = maskA == PhysicsCategory.obstacle ? nodeA : nodeB
            
            if let obstacle = obstacle as? ObstacleNode, let projectile = projectile {
                obstacle.takeDamage()
                projectile.removeFromParent()
            }
        }
    }
    
    func alienHit(alien: SKNode, projectile: SKNode) {
        createExplosion(at: alien.position)
        
        alien.removeFromParent()
        projectile.removeFromParent()
        
        if let index = aliens.firstIndex(of: alien as! SKSpriteNode) {
            aliens.remove(at: index)
        }
        
        score += 10
        
        if aliens.isEmpty {
            // Next Level or Respawns?
            // For now, respawn faster
            setupAliens()
            alienMoveInterval *= 0.8
        }
    }
    
    func gameOver() {
        guard !isGameOver else { return }
        isGameOver = true
        removeAllActions()
        
        createExplosion(at: player.position)
        
        run(SKAction.wait(forDuration: 1.0)) { [weak self] in
            self?.gameOverAction?()
        }
    }
    
    func createExplosion(at position: CGPoint) {
        let emitter = SKEmitterNode()
        // Use system image for localized small particles
        if let uiImage = UIImage(systemName: "sparkles") {
            emitter.particleTexture = SKTexture(image: uiImage)
        }
        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 15
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 10
        emitter.emissionAngleRange = 360 * (.pi / 180)
        emitter.particleScale = 0.05 // Much smaller
        emitter.particleScaleRange = 0.02
        emitter.particleColor = .green
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -2.0
        emitter.position = position
        addChild(emitter)
    }
}

// MARK: - Obstacle Node
class ObstacleNode: SKSpriteNode {
    var health: Int = 4
    var healthBar: SKShapeNode!
    
    init() {
        let texture = SKTexture(imageNamed: "asteroid_1")
        super.init(texture: texture, color: .green, size: CGSize(width: 25, height: 25))
        
        self.name = "obstacle"
        self.color = .green
        self.colorBlendFactor = 1.0
        
        self.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        self.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        self.physicsBody?.contactTestBitMask = 0
        self.physicsBody?.collisionBitMask = 0
        self.physicsBody?.isDynamic = false
        
        setupHealthBar()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupHealthBar() {
        let barSize = CGSize(width: 20, height: 3)
        healthBar = SKShapeNode(rectOf: barSize)
        healthBar.fillColor = .green
        healthBar.strokeColor = .clear
        healthBar.position = CGPoint(x: 0, y: self.size.height / 2 + 5)
        addChild(healthBar)
    }
    
    func takeDamage() {
        health -= 1
        
        // Update Health Bar
        let healthPercent = CGFloat(health) / 4.0
        healthBar.xScale = max(0, healthPercent)
        
        if health <= 0 {
            // Destroyed
            createDebris()
            removeFromParent()
        } else {
            let textureName = "asteroid_\(5 - health)" // 4->1, 3->2, 2->3, 1->4
            self.texture = SKTexture(imageNamed: textureName)
        }
    }
    
    func createDebris() {
        // Small explosion effect
    }
}
