//
//  GameScene.swift
//  ZetanInvader Watch App
//
//  Created by aristides lintzeris on 5/2/2026.
//

import SpriteKit
import WatchKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Physics Categories
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let player: UInt32 = 0b1
        static let alien: UInt32 = 0b10
        static let obstacle: UInt32 = 0b100
        static let playerProjectile: UInt32 = 0b1000
        static let alienProjectile: UInt32 = 0b10000
    }
    
    // MARK: - Game State
    enum GameState {
        case menu
        case playing
        case gameOver
    }
    
    private var gameState: GameState = .menu
    private var isSetup = false
    private var isGameOver = false
    private var score = 0
    private var lives = 3
    
    // MARK: - Game Objects
    private var player: SKSpriteNode?
    private var aliens: [SKSpriteNode] = []
    private var bonusAliens: [SKSpriteNode] = []
    private var obstacles: [Obstacle] = []
    
    // MARK: - Alien Movement & Firing
    private var alienDirection: CGFloat = 1.0
    private var alienMoveInterval: TimeInterval = 0.8
    private var lastAlienMoveTime: TimeInterval = 0
    private var lastAlienFireTime: TimeInterval = 0
    private var alienFireInterval: TimeInterval = 2.0
    
    // MARK: - Bonus Alien
    private var lastBonusSpawnTime: TimeInterval = 0
    private var bonusSpawnInterval: TimeInterval = 15.0
    
    // MARK: - Colors (Dot Matrix Green)
    private let matrixGreen = SKColor(red: 0, green: 1, blue: 0, alpha: 1)
    private let matrixGreenDim = SKColor(red: 0, green: 0.7, blue: 0, alpha: 1)
    
    // MARK: - UI
    private let scoreLabel = SKLabelNode(fontNamed: "Helvetica")
    private let statusLabel = SKLabelNode(fontNamed: "Helvetica")
    private let livesLabel = SKLabelNode(fontNamed: "Helvetica")
    
    // MARK: - Lifecycle
    override func sceneDidLoad() {
        super.sceneDidLoad()
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = .black
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Only setup once we have reasonable dimensions
        if !isSetup && size.width > 100 && size.height > 100 {
            isSetup = true
            DispatchQueue.main.async { [weak self] in
                self?.setupGame()
            }
        }
    }
    
    // MARK: - Setup
    private func setupGame() {
        setupUI()
        resetGame()
    }
    
    private func setupUI() {
        // Score label
        scoreLabel.fontSize = 12
        scoreLabel.fontColor = matrixGreen
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 5, y: size.height - 5)
        scoreLabel.zPosition = 100
        scoreLabel.isHidden = true // Hidden until game starts
        addChild(scoreLabel)
        
        // Lives label
        livesLabel.fontSize = 12
        livesLabel.fontColor = matrixGreen
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.verticalAlignmentMode = .top
        livesLabel.position = CGPoint(x: size.width - 5, y: size.height - 5)
        livesLabel.zPosition = 100
        livesLabel.isHidden = true // Hidden until game starts
        addChild(livesLabel)
        
        // Status label (used for menu and game over)
        statusLabel.fontSize = 14
        statusLabel.fontColor = matrixGreen
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        statusLabel.zPosition = 100
        statusLabel.text = "TAP TO START"
        statusLabel.isHidden = false
        addChild(statusLabel)
    }
    
    private func resetGame() {
        // Clear existing game objects
        children.forEach { node in
            if node != scoreLabel && node != statusLabel {
                node.removeFromParent()
            }
        }
        
        aliens.removeAll()
        bonusAliens.removeAll()
        obstacles.removeAll()
        player = nil
        
        // Reset state
        isGameOver = false
        score = 0
        lives = 3
        alienDirection = 1.0
        alienMoveInterval = 0.8
        lastAlienMoveTime = 0
        lastAlienFireTime = 0
        lastBonusSpawnTime = 0
        
        updateScore()
        updateLives()
        scoreLabel.isHidden = false
        livesLabel.isHidden = false
        statusLabel.isHidden = true
        
        // Update game state
        gameState = .playing
        isGameOver = false
        
        // Create game objects
        createPlayer()
        createAliens()
        createObstacles()
    }
    
    private func createPlayer() {
        // Use ship texture with green tint
        let texture = SKTexture(imageNamed: "ship_1")
        player = SKSpriteNode(texture: texture)
        
        guard let player = player else { return }
        
        player.color = matrixGreen
        player.colorBlendFactor = 0.5
        player.size = CGSize(width: 20, height: 15)
        player.position = CGPoint(x: size.width / 2, y: 25)
        player.zPosition = 10
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = false
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.alien
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        
        addChild(player)
    }
    
    private func createAliens() {
        let rows = 3
        let cols = 5
        let alienWidth: CGFloat = 16
        let alienHeight: CGFloat = 12
        let spacingX: CGFloat = 24
        let spacingY: CGFloat = 18
        
        let totalWidth = CGFloat(cols - 1) * spacingX
        let startX = (size.width - totalWidth) / 2
        let startY = size.height - 40
        
        for row in 0..<rows {
            for col in 0..<cols {
                // Use alien textures with animation
                let alienType = (row % 5) + 1
                let texture1 = SKTexture(imageNamed: "alien_\(alienType * 2 - 1)")
                let texture2 = SKTexture(imageNamed: "alien_\(alienType * 2)")
                
                let alien = SKSpriteNode(texture: texture1)
                alien.color = matrixGreen
                alien.colorBlendFactor = 0.5
                alien.size = CGSize(width: alienWidth, height: alienHeight)
                alien.position = CGPoint(
                    x: startX + CGFloat(col) * spacingX,
                    y: startY - CGFloat(row) * spacingY
                )
                alien.zPosition = 5
                
                alien.physicsBody = SKPhysicsBody(rectangleOf: alien.size)
                alien.physicsBody?.isDynamic = false
                alien.physicsBody?.categoryBitMask = PhysicsCategory.alien
                alien.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.player
                alien.physicsBody?.collisionBitMask = PhysicsCategory.none
                
                // Animate between frames
                let animation = SKAction.repeatForever(
                    SKAction.animate(with: [texture1, texture2], timePerFrame: 0.5)
                )
                alien.run(animation)
                
                addChild(alien)
                aliens.append(alien)
            }
        }
    }
    
    private func createObstacles() {
        let count = 4
        let spacing = size.width / CGFloat(count + 1)
        
        for i in 1...count {
            let obstacle = Obstacle(matrixGreen: matrixGreen)
            obstacle.position = CGPoint(x: CGFloat(i) * spacing, y: 55)
            obstacle.zPosition = 5
            addChild(obstacle)
            obstacles.append(obstacle)
        }
    }
    
    // MARK: - Input Handling
    func setPlayerPosition(_ crownValue: Double) {
        guard !isGameOver, let player = player else { return }
        
        // Map crown value (-100 to 100) to screen position
        let normalizedValue = (crownValue + 100) / 200.0 // 0 to 1
        let minX: CGFloat = 15
        let maxX = size.width - 15
        let targetX = minX + (CGFloat(normalizedValue) * (maxX - minX))
        
        // Smooth movement
        let currentX = player.position.x
        let newX = currentX + (targetX - currentX) * 0.3
        player.position.x = newX
    }
    
    func handleTap() {
        if gameState == .menu || gameState == .gameOver {
            // Start or restart game
            resetGame()
        } else if gameState == .playing && !isGameOver {
            // Fire projectile
            fireProjectile()
        }
    }
    
    private func fireProjectile() {
        guard let player = player else { return }
        
        let projectile = SKSpriteNode(color: matrixGreen, size: CGSize(width: 2, height: 8))
        projectile.position = CGPoint(x: player.position.x, y: player.position.y + 10)
        projectile.zPosition = 8
        
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.playerProjectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.alien | PhysicsCategory.obstacle
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(projectile)
        
        let moveAction = SKAction.moveBy(x: 0, y: size.height, duration: 1.0)
        let removeAction = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([moveAction, removeAction]))
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard isSetup && gameState == .playing && !isGameOver else { return }
        
        if lastAlienMoveTime == 0 {
            lastAlienMoveTime = currentTime
            lastAlienFireTime = currentTime
            lastBonusSpawnTime = currentTime
        }
        
        // Move aliens
        if currentTime - lastAlienMoveTime >= alienMoveInterval {
            moveAliens()
            lastAlienMoveTime = currentTime
        }
        
        // Alien firing
        if currentTime - lastAlienFireTime >= alienFireInterval {
            alienFire()
            lastAlienFireTime = currentTime
        }
        
        // Spawn bonus alien
        if currentTime - lastBonusSpawnTime >= bonusSpawnInterval {
            spawnBonusAlien()
            lastBonusSpawnTime = currentTime
        }
        
        // Update bonus aliens
        updateBonusAliens()
    }
    
    private func moveAliens() {
        guard !aliens.isEmpty else { return }
        
        // Check if any alien will hit the edge
        var shouldMoveDown = false
        for alien in aliens {
            let nextX = alien.position.x + (10 * alienDirection)
            if nextX < 10 || nextX > size.width - 10 {
                shouldMoveDown = true
                break
            }
        }
        
        if shouldMoveDown {
            // Move down and reverse direction
            alienDirection *= -1
            for alien in aliens {
                alien.position.y -= 8
                
                // Check if aliens reached the player
                if alien.position.y <= 30 {
                    endGame(victory: false)
                    return
                }
            }
            
            // Speed up slightly
            alienMoveInterval = max(0.3, alienMoveInterval * 0.95)
        } else {
            // Move horizontally
            for alien in aliens {
                alien.position.x += (10 * alienDirection)
            }
        }
    }
    
    private func alienFire() {
        guard !aliens.isEmpty else { return }
        
        // Random alien fires
        if let randomAlien = aliens.randomElement() {
            let projectile = SKSpriteNode(color: matrixGreenDim, size: CGSize(width: 2, height: 6))
            projectile.position = CGPoint(x: randomAlien.position.x, y: randomAlien.position.y - 8)
            projectile.zPosition = 8
            
            projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
            projectile.physicsBody?.isDynamic = true
            projectile.physicsBody?.categoryBitMask = PhysicsCategory.alienProjectile
            projectile.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.obstacle
            projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
            
            addChild(projectile)
            
            let moveAction = SKAction.moveBy(x: 0, y: -size.height, duration: 1.5)
            let removeAction = SKAction.removeFromParent()
            projectile.run(SKAction.sequence([moveAction, removeAction]))
        }
    }
    
    private func spawnBonusAlien() {
        let bonusTexture = SKTexture(imageNamed: "alien_9")
        let bonus = SKSpriteNode(texture: bonusTexture)
        bonus.color = matrixGreen
        bonus.colorBlendFactor = 0.7
        bonus.size = CGSize(width: 14, height: 14)
        bonus.position = CGPoint(x: Bool.random() ? 0 : size.width, y: size.height - 20)
        bonus.zPosition = 6
        
        bonus.physicsBody = SKPhysicsBody(circleOfRadius: 7)
        bonus.physicsBody?.isDynamic = false
        bonus.physicsBody?.categoryBitMask = PhysicsCategory.alien
        bonus.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile
        bonus.physicsBody?.collisionBitMask = PhysicsCategory.none
        
        addChild(bonus)
        bonusAliens.append(bonus)
    }
    
    private func updateBonusAliens() {
        for bonus in bonusAliens {
            // Spiral movement
            let time = CGFloat(Date().timeIntervalSince1970)
            let speed: CGFloat = 2
            
            bonus.position.x += cos(time * speed) * 2
            bonus.position.y += sin(time * speed) * 1.5 - 0.5
            
            // Remove if off screen
            if bonus.position.y < 0 || bonus.position.x < -20 || bonus.position.x > size.width + 20 {
                bonus.removeFromParent()
                if let index = bonusAliens.firstIndex(of: bonus) {
                    bonusAliens.remove(at: index)
                }
            }
        }
    }
    
    // MARK: - Collision Detection
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == (PhysicsCategory.playerProjectile | PhysicsCategory.alien) {
            handleProjectileAlienCollision(contact)
        } else if collision == (PhysicsCategory.playerProjectile | PhysicsCategory.obstacle) {
            handleProjectileObstacleCollision(contact)
        } else if collision == (PhysicsCategory.alienProjectile | PhysicsCategory.obstacle) {
            handleAlienProjectileObstacleCollision(contact)
        } else if collision == (PhysicsCategory.player | PhysicsCategory.alien) {
            handlePlayerHit(contact)
        } else if collision == (PhysicsCategory.alienProjectile | PhysicsCategory.player) {
            handlePlayerHit(contact)
        }
    }
    
    private func handleProjectileAlienCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == PhysicsCategory.playerProjectile ? contact.bodyA.node : contact.bodyB.node
        let alienNode = contact.bodyA.categoryBitMask == PhysicsCategory.alien ? contact.bodyA.node : contact.bodyB.node
        
        projectileNode?.removeFromParent()
        
        // Check if it's a regular alien
        if let alien = alienNode as? SKSpriteNode, let index = aliens.firstIndex(of: alien) {
            // Explosion particle effect
            createExplosion(at: alien.position)
            
            alien.removeFromParent()
            aliens.remove(at: index)
            
            score += 10
            updateScore()
            
            // Check for victory
            if aliens.isEmpty {
                endGame(victory: true)
            }
        }
        // Check if it's a bonus alien
        else if let bonus = alienNode as? SKSpriteNode, let index = bonusAliens.firstIndex(of: bonus) {
            // Bigger explosion for bonus
            createExplosion(at: bonus.position, scale: 1.5)
            
            bonus.removeFromParent()
            bonusAliens.remove(at: index)
            
            score += 50 // Bonus points!
            updateScore()
        }
    }
    
    private func handleProjectileObstacleCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == PhysicsCategory.playerProjectile ? contact.bodyA.node : contact.bodyB.node
        let obstacleNode = contact.bodyA.categoryBitMask == PhysicsCategory.obstacle ? contact.bodyA.node : contact.bodyB.node
        
        // Small impact effect
        if let position = projectileNode?.position {
            createImpactEffect(at: position)
        }
        
        projectileNode?.removeFromParent()
        
        if let obstacle = obstacleNode as? Obstacle {
            obstacle.takeDamage()
        }
    }
    
    
    private func handleAlienProjectileObstacleCollision(_ contact: SKPhysicsContact) {
        let projectileNode = contact.bodyA.categoryBitMask == PhysicsCategory.alienProjectile ? contact.bodyA.node : contact.bodyB.node
        let obstacleNode = contact.bodyA.categoryBitMask == PhysicsCategory.obstacle ? contact.bodyA.node : contact.bodyB.node
        
        // Small impact effect
        if let position = projectileNode?.position {
            createImpactEffect(at: position, scale: 0.7)
        }
        
        projectileNode?.removeFromParent()
        
        if let obstacle = obstacleNode as? Obstacle {
            obstacle.takeDamage()
        }
    }
    
    private func handlePlayerHit(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }
        
        // Get the alien or projectile that hit the player
        let alienNode: SKNode?
        if contact.bodyA.categoryBitMask == PhysicsCategory.player {
            alienNode = contact.bodyB.node
        } else {
            alienNode = contact.bodyA.node
        }
        
        // Remove the alien/projectile that hit
        alienNode?.removeFromParent()
        
        // Player hit effect
        if let player = player {
            createImpactEffect(at: player.position, scale: 1.5)
            
            // Flash player
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            player.run(SKAction.repeat(flash, count: 3))
        }
        
        // Lose a life
        lives -= 1
        updateLives()
        
        WKInterfaceDevice.current().play(.directionDown)
        
        if lives <= 0 {
            endGame(victory: false)
        }
    }
    
    // MARK: - Visual Effects
    private func createExplosion(at position: CGPoint, scale: CGFloat = 1.0) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 50
        emitter.particleLifetime = 0.6
        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 30
        emitter.particleSpeed = 50 * scale
        emitter.particleSpeedRange = 30
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.08 * scale
        emitter.particleScaleRange = 0.04
        emitter.particleScaleSpeed = -0.1
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5
        emitter.particleColor = matrixGreen
        emitter.particleBlendMode = .add
        
        addChild(emitter)
        
        // Auto-remove
        let wait = SKAction.wait(forDuration: 1.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    private func createImpactEffect(at position: CGPoint, scale: CGFloat = 1.0) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 50
        emitter.particleLifetime = 0.3
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 10
        emitter.particleSpeed = 30 * scale
        emitter.particleSpeedRange = 15
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.05 * scale
        emitter.particleScaleSpeed = -0.15
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -2.5
        emitter.particleColor = matrixGreenDim
        emitter.particleBlendMode = .add
        
        addChild(emitter)
        
        let wait = SKAction.wait(forDuration: 0.5)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    // MARK: - Game Over
    private func updateScore() {
        scoreLabel.text = "SCORE: \(score)"
    }
    
    private func updateLives() {
        livesLabel.text = "LIVES: \(lives)"
    }
    
    private func endGame(victory: Bool) {
        isGameOver = true
        gameState = .gameOver
        
        // Hide game UI
        scoreLabel.isHidden = true
        livesLabel.isHidden = true
        
        // Show game over message
        statusLabel.text = victory ? "VICTORY!\n\nTAP TO MENU" : "GAME OVER\n\nTAP TO MENU"
        statusLabel.fontColor = matrixGreen
        statusLabel.isHidden = false
        
        WKInterfaceDevice.current().play(victory ? .success : .failure)
    }
}

// MARK: - Obstacle Class
class Obstacle: SKSpriteNode {
    private var health = 3
    
    init(matrixGreen: SKColor) {
        // Use asteroid texture with green tint
        let texture = SKTexture(imageNamed: "asteroid_1")
        super.init(texture: texture, color: matrixGreen, size: CGSize(width: 18, height: 18))
        
        self.colorBlendFactor = 0.5
        
        self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
        self.physicsBody?.isDynamic = false
        self.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.obstacle
        self.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.playerProjectile
        self.physicsBody?.collisionBitMask = GameScene.PhysicsCategory.none
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func takeDamage() {
        health -= 1
        
        if health <= 0 {
            // Create destruction animation with slices
            createDestructionEffect()
            removeFromParent()
        } else {
            // Update texture based on damage
            let textureIndex = 4 - health // 3->2, 2->3, 1->4
            self.texture = SKTexture(imageNamed: "asteroid_\(textureIndex)")
        }
    }
    
    private func createDestructionEffect() {
        guard let parent = self.parent else { return }
        
        // Create 4 asteroid slice pieces that fly apart
        for i in 1...4 {
            let slice = SKSpriteNode(texture: SKTexture(imageNamed: "asteroid_4"))
            slice.color = self.color
            slice.colorBlendFactor = self.colorBlendFactor
            slice.size = CGSize(width: 8, height: 8)
            slice.position = self.position
            slice.zPosition = self.zPosition
            
            parent.addChild(slice)
            
            // Random direction for each piece
            let angle = CGFloat(i) * (.pi / 2) + CGFloat.random(in: -0.3...0.3)
            let distance: CGFloat = 20
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            
            // Fly apart and fade
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.5)
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -.pi...(.pi)), duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            
            let group = SKAction.group([move, rotate, fade])
            slice.run(SKAction.sequence([group, remove]))
        }
    }
}
