/*
* Copyright (c) 2013-2014 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
  
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
  
  var bedNode: SKSpriteNode!
  var catNode: SKSpriteNode!
  
  var currentLevel: Int = 0
  
  var hookBaseNode: SKSpriteNode!
  var hookNode: SKSpriteNode!
  var hookJoint: SKPhysicsJoint!
  var ropeNode: SKSpriteNode!
  
  override func didMoveToView(view: SKView) {
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
    
    
    bedNode = childNodeWithName("bed") as SKSpriteNode
    catNode = childNodeWithName("cat") as SKSpriteNode
    
    //        bedNode.setScale(1.5)
    //        catNode.setScale(1.5)
    
    let bedBodySize = CGSize(width: 40, height: 30)
    bedNode.physicsBody = SKPhysicsBody(
      rectangleOfSize: bedBodySize)
    bedNode.physicsBody!.dynamic = false
    
    let catBodyTexture = SKTexture(imageNamed: "cat_body")
    catNode.physicsBody =
      SKPhysicsBody(texture: catBodyTexture, size: catNode.size)
    
    SKTAudio.sharedInstance().playBackgroundMusic("backgroundMusic.mp3")
    
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
    
  }
  
  
  func sceneTouched(location: CGPoint) {
    //1
    let targetNode = self.nodeAtPoint(location)
//    println(targetNode)
    if targetNode.parent?.name == "compoundNode" {
      targetNode.parent!.removeFromParent()
    }

    //2
    if targetNode.physicsBody == nil {
      return
    }
    //3
    if targetNode.physicsBody!.categoryBitMask == PhysicsCategory.Block {
      
      targetNode.removeFromParent()
      //4
      runAction(SKAction.playSoundFileNamed("pop.mp3",
        waitForCompletion: false))
      
      return
      
    }
    
    if targetNode.physicsBody!.categoryBitMask ==
      PhysicsCategory.Spring {
        
        let spring = targetNode as SKSpriteNode
        spring.physicsBody!.applyImpulse(CGVector(dx: 0, dy: 160),
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
  
  override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
    
    let touch: UITouch = touches.anyObject() as UITouch
    sceneTouched(touch.locationInNode(self))
    
  }
  
  func didBeginContact(contact: SKPhysicsContact!) {
    let collision: UInt32 = contact.bodyA.categoryBitMask |
      contact.bodyB.categoryBitMask
    
    if collision == PhysicsCategory.Cat | PhysicsCategory.Bed {
      println("SUCCESS")
      win()
    } else if collision == PhysicsCategory.Cat | PhysicsCategory.Edge {
      println("FAIL")
      lose()
    }
    
    //
    // MARK: Challenge 1 code
    //
    if collision == PhysicsCategory.Label | PhysicsCategory.Edge {
      let labelNode = contact.bodyA.categoryBitMask == PhysicsCategory.Label ? contact.bodyA.node as SKLabelNode: contact.bodyB.node as SKLabelNode
      
      if var userData = labelNode.userData {
        //consequent bounce, keep counting
        userData["bounceCount"] = (userData["bounceCount"] as Int) + 1
        if userData["bounceCount"] as Int == 4 {
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
    label.position = CGPoint(x: frame.size.width/2, y: frame.size.height/2)
    
    label.physicsBody = SKPhysicsBody(circleOfRadius: 10)
    label.physicsBody!.collisionBitMask = PhysicsCategory.Edge
    label.physicsBody!.categoryBitMask = PhysicsCategory.Label
    label.physicsBody!.contactTestBitMask = PhysicsCategory.Edge
    label.physicsBody!.restitution = 0.7
    //3
    addChild(label)
    //4
//    runAction(SKAction.sequence([
//      SKAction.waitForDuration(3),
//      SKAction.removeFromParent()
//      ]))
  }
  
  func newGame() {
    view!.presentScene(GameScene.level(currentLevel))
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
    if (currentLevel < 3) {
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

  class func level(levelNum: Int) -> GameScene? {
    let scene = GameScene(fileNamed: "Level\(levelNum)")
    scene.currentLevel = levelNum
    scene.scaleMode = .AspectFill
    return scene
  }

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

  

}
