//
//  GameScene.swift
//  CatNap
//
//  Created by Marin Todorov on 4/9/15.
//  Copyright (c) 2015 Razeware ltd. All rights reserved.
//

import SpriteKit
protocol ImageCaptureDelegate {
    func requestImagePicker()
}

struct PhysicsCategory {
    static let None:  UInt32 = 0
    static let Cat:   UInt32 = 0b1   // 1
    static let Block: UInt32 = 0b10  // 2
    static let Bed:   UInt32 = 0b100 // 4
    static let Edge:  UInt32 = 0b1000 // 8
    static let Label: UInt32 = 0b10000 // 16
    static let Spring:UInt32 = 0b100000 // 32
    static let Hook:  UInt32 = 0b1000000 // 64
}

class GameScene: SKScene, SKPhysicsContactDelegate {

  
  var bedNode: SKSpriteNode!
  var catNode: SKSpriteNode!
    
    var imageCaptureDelegate: ImageCaptureDelegate?
    var photoChanged: Bool = false
  
  override func didMoveToView(view: SKView) {
    
    let backgroundDesat =
    SKSpriteNode(imageNamed: "background-desat")
    
    let label = SKLabelNode(fontNamed: "Zapfino")
    label.text = "Cat Nap"
    label.fontSize = 296

    let cropNode = SKCropNode()
    cropNode.addChild(backgroundDesat)
    cropNode.maskNode = label

    if let background = childNodeWithName("Background") {
      background.addChild(cropNode)
    }
    
    // Calculate playable margin
    let maxAspectRatio: CGFloat = 16.0/9.0 // iPhone 5
    let maxAspectRatioHeight = size.width / maxAspectRatio
    let playableMargin: CGFloat =
    (size.height - maxAspectRatioHeight)/2
    let playableRect = CGRect(x: 0, y: playableMargin,
      width: size.width, height: size.height-playableMargin*2)
    
    physicsBody = SKPhysicsBody(edgeLoopFromRect: playableRect)
    
    physicsWorld.contactDelegate = self
    physicsBody!.categoryBitMask = PhysicsCategory.Edge
    
    bedNode = childNodeWithName("bed") as! SKSpriteNode
    catNode = childNodeWithName("cat") as! SKSpriteNode
    
    //bedNode.setScale(1.5)
    //catNode.setScale(1.5)
    
    let bedBodySize = CGSize(width: 40, height: 30)
    bedNode.physicsBody = SKPhysicsBody(
      rectangleOfSize: bedBodySize)
    bedNode.physicsBody!.dynamic = false
    
    let catBodyTexture = SKTexture(imageNamed: "cat_body")
    catNode.physicsBody =
      SKPhysicsBody(texture: catBodyTexture, size: catNode.size)
    
    SKTAudio.sharedInstance().playBackgroundMusic(
      "backgroundMusic.mp3")
    
    bedNode.physicsBody!.categoryBitMask = PhysicsCategory.Bed
    bedNode.physicsBody!.collisionBitMask = PhysicsCategory.None
    
    catNode.physicsBody!.categoryBitMask = PhysicsCategory.Cat
    catNode.physicsBody!.collisionBitMask = PhysicsCategory.Block |
      PhysicsCategory.Edge | PhysicsCategory.Spring
    
    catNode.physicsBody!.contactTestBitMask = PhysicsCategory.Bed |
      PhysicsCategory.Edge
    
    addHook()
    
    //    let rotationConstraint =
    //    SKConstraint.zRotation(
    //      SKRange(lowerLimit: -π/4, upperLimit: π/4))
    //    catNode.constraints = [rotationConstraint]
    
    makeCompoundNode()
    
    //createPhotoFrameAtPosition(CGPointMake(250, 820))
    enumerateChildNodesWithName("PhotoFrameNode") {node, _ in
        self.addPhotoToFrame(node as! SKSpriteNode)
    }
    
//    let tvNode = OldTVNode(frame: CGRectMake(20, 500, 300, 300))
//    addChild(tvNode)
    
    let tvNodes = (children as! [SKNode]).filter ({node in
        return node.name == .Some("TVNode")
    })
    
    for node in tvNodes {
        let tvNode = OldTVNode(frame: node.frame)
        self.addChild(tvNode)
        node.removeFromParent()
    }
    
    
    let shapeNodes = (children as! [SKNode]).filter ({node in
        return node.name == .Some("Shape")
        })
    for node in shapeNodes {
            let shapeNode = makeWonkyBlockFromShapeNode(node as! SKShapeNode)
            addChild(shapeNode)
            node.removeFromParent()
    }
    
    
    
  }
  
  func sceneTouched(location: CGPoint) {
    //1
    var targetNode = self.nodeAtPoint(location)
    
    let nodes = self.nodesAtPoint(location) as! [SKNode]
    for node in nodes {
        if let nodeName = node.name {
            if nodeName == "PhotoFrameNode" || nodeName == "TVNode"{
                //1
                targetNode = node
        
            if nodeName == "TVNode" {
                break
            }
        
                //2
                if !photoChanged { //3
                    imageCaptureDelegate?.requestImagePicker()
                    return
                }
        
            }
        }
    }
    

    if targetNode.parent?.name == "compoundNode" {
      targetNode.parent!.removeFromParent()
    }

    //2
    if targetNode.physicsBody == nil {
      return
    }
    //3
    if targetNode.physicsBody!.categoryBitMask ==
      PhysicsCategory.Block {
        
        targetNode.removeFromParent()
        //4
        runAction(SKAction.playSoundFileNamed("pop.mp3",
          waitForCompletion: false))
        
        return
    }
    
    if targetNode.physicsBody!.categoryBitMask ==
      PhysicsCategory.Spring {
        
        let spring = targetNode as! SKSpriteNode
        spring.physicsBody!.applyImpulse(CGVector(dx: 0, dy: 190),
          atPoint: CGPoint(x: spring.size.width/2,
            y: spring.size.height))
        
        targetNode.runAction(SKAction.sequence([
          SKAction.waitForDuration(1),
          SKAction.removeFromParent()]))
        
        return
    }
    
    if targetNode.physicsBody?.categoryBitMask == PhysicsCategory.Cat
      && hookJoint != nil {
        releaseHook()
    }
    
  }
  
  override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
    let touch: UITouch = touches.first as! UITouch
    sceneTouched(touch.locationInNode(self))
  }
  
  func didBeginContact(contact: SKPhysicsContact) {
    let collision: UInt32 = contact.bodyA.categoryBitMask |
      contact.bodyB.categoryBitMask
    
    if collision == PhysicsCategory.Cat | PhysicsCategory.Bed {
      //println("SUCCESS")
      win()
    } else if collision == PhysicsCategory.Cat | PhysicsCategory.Edge {
      //println("FAIL")
      lose()
    }
    
    //
    // MARK: Challenge 1 code
    //
    if collision == PhysicsCategory.Label | PhysicsCategory.Edge {
      let labelNode = contact.bodyA.categoryBitMask == PhysicsCategory.Label ? contact.bodyA.node as! SKLabelNode: contact.bodyB.node as! SKLabelNode
      
      if var userData = labelNode.userData {
        //consequent bounce, keep counting
        userData["bounceCount"] = (userData["bounceCount"] as! Int) + 1
        if userData["bounceCount"] as! Int == 4 {
          labelNode.removeFromParent()
        }
      } else {
        //first bounce, start counting
        labelNode.userData = NSMutableDictionary(object: 1 as Int, forKey: "bounceCount")
      }
    }
    
    if collision == PhysicsCategory.Cat | PhysicsCategory.Hook {
      catNode.physicsBody!.velocity = CGVector(dx: 0, dy: 0)
      catNode.physicsBody!.angularVelocity = 0
      
      let pinPoint = CGPoint(
        x: hookNode.position.x,
        y: hookNode.position.y + hookNode.size.height/2)
      
      hookJoint = SKPhysicsJointFixed.jointWithBodyA(contact.bodyA,
        bodyB: contact.bodyB, anchor: pinPoint)
      physicsWorld.addJoint(hookJoint)
    }
    
  }
  
  func inGameMessage(text:String) {
    //1
    let label: SKLabelNode = SKLabelNode(
      fontNamed: "AvenirNext-Regular")
    label.text = text
    label.fontSize = 128.0
    label.color = SKColor.whiteColor()
    //2
    label.position = CGPoint(x: frame.size.width/2,
      y: frame.size.height/2)
    
    label.physicsBody = SKPhysicsBody(circleOfRadius: 10)
    label.physicsBody!.collisionBitMask = PhysicsCategory.Edge
    label.physicsBody!.categoryBitMask = PhysicsCategory.Label
    label.physicsBody!.contactTestBitMask = PhysicsCategory.Edge
    label.physicsBody!.restitution = 0.7
    //3
    addChild(label)
    //4
    runAction(SKAction.sequence([
      SKAction.waitForDuration(3),
      SKAction.removeFromParent()
      ]))
  }
  
    func newGame() {
        if let newScene = GameScene.level(currentLevel) {
        newScene.imageCaptureDelegate = imageCaptureDelegate
        newScene.scaleMode = scaleMode
        view!.presentScene(newScene)
        }
    }
  
  func lose() {
    if (currentLevel > 1) {
      currentLevel--
    }
    
    //1
    catNode.physicsBody!.contactTestBitMask = PhysicsCategory.None
    catNode.texture = SKTexture(imageNamed: "cat_awake")
    //2
    SKTAudio.sharedInstance().pauseBackgroundMusic()
    runAction(SKAction.playSoundFileNamed("lose.mp3",
      waitForCompletion: false))
    //3
    inGameMessage("Try again...")
    //4
    runAction(SKAction.sequence([
      SKAction.waitForDuration(5),
      SKAction.runBlock(newGame)
      ]))
  }
  
  func win() {
    if (currentLevel < 6) {
      currentLevel++
    }
    
    //1
    catNode.physicsBody = nil
    //2
    let curlY = bedNode.position.y + catNode.size.height/3
    let curlPoint = CGPoint(x: bedNode.position.x, y: curlY)
    //3
    catNode.runAction(SKAction.group([
      SKAction.moveTo(curlPoint, duration: 0.66),
      SKAction.rotateToAngle(0, duration: 0.5)]))
    //4
    inGameMessage("Nice job!")
    //5
    runAction(SKAction.sequence([SKAction.waitForDuration(5),
      SKAction.runBlock(newGame)]))
    //6
    catNode.runAction(SKAction.animateWithTextures([
      SKTexture(imageNamed: "cat_curlup1"),
      SKTexture(imageNamed: "cat_curlup2"),
      SKTexture(imageNamed: "cat_curlup3")], timePerFrame: 0.25))
    //7
    SKTAudio.sharedInstance().pauseBackgroundMusic()
    runAction(SKAction.playSoundFileNamed("win.mp3",
      waitForCompletion: false))
  }
  
  override func didSimulatePhysics() {
    if let body = catNode.physicsBody {
      if body.contactTestBitMask != PhysicsCategory.None &&
        fabs(catNode.zRotation) > CGFloat(45).degreesToRadians() {
          if hookJoint == nil {
            lose()
          }
      }
    }
  }
  
  //1
  var currentLevel: Int = 0
  //2
  class func level(levelNum: Int) -> GameScene? {
    let scene = GameScene(fileNamed: "Level\(levelNum)")
    scene.currentLevel = levelNum
    scene.scaleMode = .AspectFill
    return scene
  }
  
  var hookBaseNode: SKSpriteNode!
  var hookNode: SKSpriteNode!
  var hookJoint: SKPhysicsJoint!
  var ropeNode: SKSpriteNode!
  
  func addHook() {
    hookBaseNode = childNodeWithName("hookBase") as? SKSpriteNode
    if hookBaseNode == nil {
      return
    }
    
    let ceilingFix =
    SKPhysicsJointFixed.jointWithBodyA(hookBaseNode.physicsBody,
      bodyB: physicsBody, anchor: CGPointZero)
    physicsWorld.addJoint(ceilingFix)
    
    ropeNode = SKSpriteNode(imageNamed: "rope")
    ropeNode.anchorPoint = CGPoint(x: 0, y: 0.5)
    ropeNode.zRotation = CGFloat(270).degreesToRadians()
    ropeNode.position = hookBaseNode.position
    addChild(ropeNode)
    
    hookNode = SKSpriteNode(imageNamed: "hook")
    hookNode.position = CGPoint(
      x: hookBaseNode.position.x,
      y: hookBaseNode.position.y - ropeNode.size.width )
    
    hookNode.physicsBody =
      SKPhysicsBody(circleOfRadius: hookNode.size.width/2)
    hookNode.physicsBody!.categoryBitMask = PhysicsCategory.Hook
    hookNode.physicsBody!.contactTestBitMask = PhysicsCategory.Cat
    hookNode.physicsBody!.collisionBitMask = PhysicsCategory.None
    
    addChild(hookNode)
    
    let ropeJoint =
    SKPhysicsJointSpring.jointWithBodyA(hookBaseNode.physicsBody,
      bodyB: hookNode.physicsBody,
      anchorA: hookBaseNode.position,
      anchorB:
      CGPoint(x: hookNode.position.x,
      y: hookNode.position.y+hookNode.size.height/2))
    physicsWorld.addJoint(ropeJoint)
    
    let range = SKRange(lowerLimit: 0.0, upperLimit: 0.0)
    let orientConstraint =
    SKConstraint.orientToNode(hookNode, offset: range)
    ropeNode.constraints = [orientConstraint]
    
    hookNode.physicsBody!.applyImpulse(CGVector(dx: 50, dy: 0))
  }
  
  func releaseHook() {
    catNode.zRotation = 0
    hookNode.physicsBody!.contactTestBitMask = PhysicsCategory.None
    physicsWorld.removeJoint(hookJoint)
    hookJoint = nil
  }
  
  func makeCompoundNode() {
    let compoundNode = SKNode()
    compoundNode.zPosition = -1
    compoundNode.name = "compoundNode"
    
    var bodies:[SKPhysicsBody]  = [SKPhysicsBody]()
    
    enumerateChildNodesWithName("stone") {node, _ in
      node.removeFromParent()
      compoundNode.addChild(node)
      
      let body = SKPhysicsBody(rectangleOfSize: node.frame.size,
        center: node.position)
      bodies.append(body)
    }
      
    compoundNode.physicsBody = SKPhysicsBody(bodies: bodies)
    
    compoundNode.physicsBody!.collisionBitMask = PhysicsCategory.Edge | PhysicsCategory.Cat | PhysicsCategory.Block
    addChild(compoundNode)
  }
    
    
    func addPhotoToFrame(photoFrame: SKSpriteNode) {
        let pictureNode = SKSpriteNode(imageNamed: "picture")
        pictureNode.name = "PictureNode"
        
        let maskNode = SKSpriteNode(imageNamed: "picture-frame-mask")
        maskNode.name = "Mask"
        
        let cropNode = SKCropNode()
        cropNode.addChild(pictureNode)
        cropNode.maskNode = maskNode
        photoFrame.addChild(cropNode)
        
        photoFrame.physicsBody = SKPhysicsBody(
            circleOfRadius: ((photoFrame.size.width * 0.975) / 2.0))
        photoFrame.physicsBody!.categoryBitMask =
            PhysicsCategory.Block
        photoFrame.physicsBody!.collisionBitMask =
            PhysicsCategory.Block | PhysicsCategory.Cat |
            PhysicsCategory.Edge
    }
    
    
    func createPhotoFrameAtPosition(position: CGPoint) {
        // 1
        let photoFrame = SKSpriteNode(imageNamed: "picture-frame")
        photoFrame.name = "PhotoFrameNode"
        photoFrame.position = position
        let pictureNode = SKSpriteNode(imageNamed: "picture")
        pictureNode.name = "PictureNode"
        // 2
        let maskNode = SKSpriteNode(imageNamed: "picture-frame-mask")
        maskNode.name = "Mask"
        // 3
        let cropNode = SKCropNode()
        
        cropNode.addChild(pictureNode)
        cropNode.maskNode = maskNode
        photoFrame.addChild(cropNode)
        addChild(photoFrame)
        
        photoFrame.physicsBody = SKPhysicsBody(
            circleOfRadius: ((photoFrame.size.width * 0.975) / 2.0))
        photoFrame.physicsBody!.categoryBitMask = PhysicsCategory.Block
        photoFrame.physicsBody!.collisionBitMask =
            PhysicsCategory.Block | PhysicsCategory.Cat |
            PhysicsCategory.Edge
    }
    
    func changePhotoTexture(texture: SKTexture) {
            let photoNode =
            childNodeWithName("//PictureNode") as! SKSpriteNode
            photoNode.texture = texture
            photoChanged = true
    }

    
    
    func adjustedPoint(inputPoint: CGPoint, inputSize: CGSize)
            -> CGPoint {
            //1
            let width = inputSize.width * 0.15
            let height = inputSize.height * 0.15
            //2
            let xMove = width * CGFloat.random() - width / 2.0
            let yMove = height * CGFloat.random() - height / 2.0
            //3
            let move = CGPoint(x: xMove, y: yMove)
            //4
            return inputPoint + move
    }
    
    
    func makeWonkyBlockFromShapeNode(shapeNode: SKShapeNode) -> SKShapeNode {
        //1
        let newShapeNode = SKShapeNode()
        //2
        let originalRect = shapeNode.frame
        //3
        var leftTop = CGPoint(x: CGRectGetMinX(originalRect),
                y: CGRectGetMaxY(originalRect))
        var leftBottom = originalRect.origin
        var rightBottom = CGPoint(x: CGRectGetMaxX(originalRect),
                y: CGRectGetMinY(originalRect))
        var rightTop = CGPoint(x: CGRectGetMaxX(originalRect),
                y: CGRectGetMaxY(originalRect))
        //4
        let size = originalRect.size
        leftTop = adjustedPoint(leftTop, inputSize: size)
        leftBottom = adjustedPoint(leftBottom, inputSize: size)
        rightBottom = adjustedPoint(rightBottom, inputSize: size)
        rightTop = adjustedPoint(rightTop, inputSize: size)
        
        //5
        let bezierPath = CGPathCreateMutable()
        CGPathMoveToPoint(bezierPath, nil, leftTop.x, leftTop.y)
        CGPathAddLineToPoint(
            bezierPath, nil, leftBottom.x, leftBottom.y)
        CGPathAddLineToPoint(
            bezierPath, nil, rightBottom.x, rightBottom.y)
        CGPathAddLineToPoint(bezierPath, nil, rightTop.x, rightTop.y)
        //6
        CGPathCloseSubpath(bezierPath)
        //7
        newShapeNode.path = bezierPath
        //8
        leftTop -= CGPoint(x: -2, y: 2)
        leftBottom -= CGPoint(x: -2, y: -2)
        rightBottom -= CGPoint(x: 2, y: -2)
        rightTop -= CGPoint(x: 2, y: 2)
        //9
        let physicsBodyPath = CGPathCreateMutable()
        CGPathMoveToPoint(physicsBodyPath, nil, leftTop.x, leftTop.y)
        CGPathAddLineToPoint(
            physicsBodyPath, nil, leftBottom.x, leftBottom.y)
        CGPathAddLineToPoint(
            physicsBodyPath, nil, rightBottom.x, rightBottom.y)
        CGPathAddLineToPoint(
            physicsBodyPath, nil, rightTop.x, rightTop.y)
        //10
        CGPathCloseSubpath(physicsBodyPath)
        //11
        newShapeNode.physicsBody =
            SKPhysicsBody(polygonFromPath: physicsBodyPath)
        newShapeNode.physicsBody!.categoryBitMask =
            PhysicsCategory.Block
        newShapeNode.physicsBody!.collisionBitMask =
            PhysicsCategory.Block | PhysicsCategory.Cat |
            PhysicsCategory.Edge
        //12
        newShapeNode.lineWidth = 1.0
        newShapeNode.fillColor =
            SKColor(red: 0.73, green: 0.73, blue: 1.0, alpha: 1.0)
        newShapeNode.strokeColor =
                SKColor(red: 0.165, green: 0.165, blue: 0.0, alpha: 1.0)
        newShapeNode.glowWidth = 1.0
        //13
        newShapeNode.fillTexture = SKTexture(imageNamed: "wood_texture")
        return newShapeNode
    }

    
}
