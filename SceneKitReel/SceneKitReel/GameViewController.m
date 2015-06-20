//
//  GameViewController.m
//  SceneKitReel
//
//  Created by ZhangBo on 15/6/21.
//  Copyright (c) 2015年 ZhangBo. All rights reserved.
//

#import "GameViewController.h"

#import <SceneKit/SceneKit.h>
#import <SpriteKit/SpriteKit.h>
#import "AAPLSpriteKitOverlayScene.h"


#define SLIDE_COUNT 10

#define TEXT_SCALE 0.75
#define TEXT_Z_SPACING 200

#define MAX_FIRE 25.0
#define MAX_SMOKE 20.0


// utility function
static CGFloat randFloat(CGFloat min, CGFloat max)
{
    return min + (max - min) * (CGFloat)rand() / RAND_MAX;
}



@interface GameViewController ()
{
@private
    //steps of the demo
    NSUInteger _introductionStep;
    NSUInteger _step;
    
    //scene
    SCNScene *_scene;
    
    // save spot light transform
    SCNMatrix4 _originalSpotTransform;
    
    //references to nodes for manipulation
    SCNNode *_cameraHandle;
    SCNNode *_cameraOrientation;
    SCNNode *_cameraNode;
    SCNNode *_spotLightParentNode;
    SCNNode *_spotLightNode;
    SCNNode *_ambientLightNode;
    SCNNode *_floorNode;
    SCNNode *_sceneKitLogo;
    SCNNode *_mainWall;
    SCNNode *_invisibleWallForPhysicsSlide;
    
    //ship
    SCNNode *_shipNode;
    SCNNode *_shipPivot;
    SCNNode *_shipHandle;
    SCNNode *_introNodeGroup;
    
    //physics slide
    NSMutableArray *_boxes;
    
    //particles slide
    SCNNode *_fireTruck;
    SCNNode *_collider;
    SCNNode *_emitter;
    SCNNode *_fireContainer;
    SCNNode *_handle;
    SCNParticleSystem *_fire;
    SCNParticleSystem *_smoke;
    SCNParticleSystem *_plok;
    BOOL _hitFire;
    
    //physics fields slide
    SCNNode *_fieldEmitter;
    SCNNode *_fieldOwner;
    SCNNode *_interactiveField;
    
    //SpriteKit integration slide
    SCNNode *_torus;
    SCNNode *_splashNode;
    
    //shaders slide
    SCNNode *_shaderGroupNode;
    SCNNode *_shadedNode;
    int      _shaderStage;
    
    // shader modifiers
    NSString *_geomModifier;
    NSString *_surfModifier;
    NSString *_fragModifier;
    NSString *_lightModifier;
    
    //camera manipulation
    SCNVector3 _cameraBaseOrientation;
    CGPoint    _initialOffset, _lastOffset;
    SCNMatrix4 _cameraHandleTransforms[SLIDE_COUNT];
    SCNMatrix4 _cameraOrientationTransforms[SLIDE_COUNT];
    dispatch_source_t _timer;
    
    
    BOOL _preventNext;

}
@end

@implementation GameViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setup];
}

#pragma mark - Setup

- (void)setup
{
    SCNView *sceneView = (SCNView *)self.view;
    
    //redraw forever
    sceneView.playing = YES;
    sceneView.loops = YES;
    sceneView.showsStatistics = YES;
    
    sceneView.backgroundColor = [SKColor blackColor];
    
    //setup ivars
    _boxes = [NSMutableArray array];
    
    //setup the scene
    [self setupScene];
    
    //present it
    sceneView.scene = _scene;
    
    //tweak physics
    sceneView.scene.physicsWorld.speed = 2.0;
    
    //let's be the delegate of the SCNView
    sceneView.delegate = self;
    
    //initial point of view
    sceneView.pointOfView = _cameraNode;
    
    //setup overlays
    AAPLSpriteKitOverlayScene *overlay = [[AAPLSpriteKitOverlayScene alloc] initWithSize:sceneView.bounds.size];
    sceneView.overlaySKScene = overlay;
    
#if TARGET_OS_IPHONE
    NSMutableArray *gestureRecognizers = [NSMutableArray array];
    [gestureRecognizers addObjectsFromArray:sceneView.gestureRecognizers];
    
    // add a tap gesture recognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    
    // add a pan gesture recognizer
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    
    // add a double tap gesture recognizer
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    
    [tapGesture requireGestureRecognizerToFail:panGesture];
    
    [gestureRecognizers addObject:doubleTapGesture];
    [gestureRecognizers addObject:tapGesture];
    [gestureRecognizers addObject:panGesture];
    
    //register gesture recognizers
    sceneView.gestureRecognizers = gestureRecognizers;
#endif
    
    if (!_introductionStep)
        [overlay showLabel:@"Go!"];
}

- (void)setupScene
{
    _scene = [SCNScene scene];
    
    [self setupEnvironment];
    [self setupSceneElements];
    [self setupIntroEnvironment];
}

- (void) setupEnvironment
{
    // |_   cameraHandle
    //   |_   cameraOrientation
    //     |_   cameraNode
    
    //create a main camera
    _cameraNode = [SCNNode node];
    _cameraNode.position = SCNVector3Make(0, 0, 120);
    
    //create a node to manipulate the camera orientation
    _cameraHandle = [SCNNode node];
    _cameraHandle.position = SCNVector3Make(0, 60, 0);
    
    _cameraOrientation = [SCNNode node];
    
    [_scene.rootNode addChildNode:_cameraHandle];
    [_cameraHandle addChildNode:_cameraOrientation];
    [_cameraOrientation addChildNode:_cameraNode];
    
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.zFar = 800;
#if TARGET_OS_IPHONE
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        _cameraNode.camera.yFov = 55;
    }
    else
#endif
    {
        _cameraNode.camera.xFov = 75;
    }
    
    _cameraHandleTransforms[0] = _cameraNode.transform;
    
    // add an ambient light
    _ambientLightNode = [SCNNode node];
    _ambientLightNode.light = [SCNLight light];
    
    _ambientLightNode.light.type = SCNLightTypeAmbient;
    _ambientLightNode.light.color = [SKColor colorWithWhite:0.3 alpha:1.0];
    
    [_scene.rootNode addChildNode:_ambientLightNode];
    
    
    //add a key light to the scene
    _spotLightParentNode = [SCNNode node];
    _spotLightParentNode.position = SCNVector3Make(0, 90, 20);
    
    _spotLightNode = [SCNNode node];
    _spotLightNode.rotation = SCNVector4Make(1,0,0,-M_PI_4);
    
    _spotLightNode.light = [SCNLight light];
    _spotLightNode.light.type = SCNLightTypeSpot;
    _spotLightNode.light.color = [SKColor colorWithWhite:1.0 alpha:1.0];
    _spotLightNode.light.castsShadow = YES;
    _spotLightNode.light.shadowColor = [SKColor colorWithWhite:0 alpha:0.5];
    _spotLightNode.light.zNear = 30;
    _spotLightNode.light.zFar = 800;
    _spotLightNode.light.shadowRadius = 1.0;
    _spotLightNode.light.spotInnerAngle = 15;
    _spotLightNode.light.spotOuterAngle = 70;
    
    [_cameraNode addChildNode:_spotLightParentNode];
    [_spotLightParentNode addChildNode:_spotLightNode];
    
    //save spotlight transform
    _originalSpotTransform = _spotLightNode.transform;
    
    //floor
    SCNFloor *floor = [SCNFloor floor];
    floor.reflectionFalloffEnd = 0;
    floor.reflectivity = 0;
    
    _floorNode = [SCNNode node];
    _floorNode.geometry = floor;
    _floorNode.geometry.firstMaterial.diffuse.contents = @"wood.png";
    _floorNode.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    _floorNode.geometry.firstMaterial.diffuse.wrapS = SCNWrapModeRepeat;
    _floorNode.geometry.firstMaterial.diffuse.wrapT = SCNWrapModeRepeat;
    _floorNode.geometry.firstMaterial.diffuse.mipFilter = SCNFilterModeNearest;
    _floorNode.geometry.firstMaterial.doubleSided = NO;
    
    _floorNode.physicsBody = [SCNPhysicsBody staticBody];
    _floorNode.physicsBody.restitution = 1.0;
    
    [_scene.rootNode addChildNode:_floorNode];
}

- (void)setupSceneElements
{
    // create the wall geometry
    SCNPlane *wallGeometry = [SCNPlane planeWithWidth:800 height:200];
    wallGeometry.firstMaterial.diffuse.contents = @"wallPaper.png";
    wallGeometry.firstMaterial.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(8, 2, 1), SCNMatrix4MakeRotation(M_PI_4, 0, 0, 1));
    wallGeometry.firstMaterial.diffuse.wrapS = SCNWrapModeRepeat;
    wallGeometry.firstMaterial.diffuse.wrapT = SCNWrapModeRepeat;
    wallGeometry.firstMaterial.doubleSided = NO;
    wallGeometry.firstMaterial.locksAmbientWithDiffuse = YES;
    
    SCNNode *wallWithBaseboardNode = [SCNNode nodeWithGeometry:wallGeometry];
    wallWithBaseboardNode.position = SCNVector3Make(200, 100, -20);
    wallWithBaseboardNode.physicsBody = [SCNPhysicsBody staticBody];
    wallWithBaseboardNode.physicsBody.restitution = 1.0;
    wallWithBaseboardNode.castsShadow = NO;
    
    SCNNode *baseboardNode = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:800 height:8 length:0.5 chamferRadius:0]];
    baseboardNode.geometry.firstMaterial.diffuse.contents = @"baseboard.jpg";
    baseboardNode.geometry.firstMaterial.diffuse.wrapS = SCNWrapModeRepeat;
    baseboardNode.geometry.firstMaterial.doubleSided = NO;
    baseboardNode.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    baseboardNode.position = SCNVector3Make(0, -wallWithBaseboardNode.position.y + 4, 0.5);
    baseboardNode.castsShadow = NO;
    baseboardNode.renderingOrder = -3; //render before others
    
    [wallWithBaseboardNode addChildNode:baseboardNode];
    
    //front walls
    _mainWall = wallWithBaseboardNode;
    [_scene.rootNode addChildNode:wallWithBaseboardNode];
    _mainWall.renderingOrder = -3; //render before others
    
    //back
    SCNNode *wallNode = [wallWithBaseboardNode clone];
    wallNode.opacity = 0;
    wallNode.physicsBody = [SCNPhysicsBody staticBody];
    wallNode.physicsBody.restitution = 1.0;
    wallNode.physicsBody.categoryBitMask = 1 << 2;
    wallNode.castsShadow = NO;
    
    wallNode.position = SCNVector3Make(0, 100, 40);
    wallNode.rotation = SCNVector4Make(0, 1, 0, M_PI);
    [_scene.rootNode addChildNode:wallNode];
    
    //left
    wallNode = [wallWithBaseboardNode clone];
    wallNode.position = SCNVector3Make(-120, 100, 40);
    wallNode.rotation = SCNVector4Make(0, 1, 0, M_PI_2);
    [_scene.rootNode addChildNode:wallNode];
    
    
    //right (an invisible wall to keep the bodies in the visible area when zooming in the Physics slide)
    wallNode = [wallNode clone];
    wallNode.opacity = 0;
    wallNode.position = SCNVector3Make(120, 100, 40);
    wallNode.rotation = SCNVector4Make(0, 1, 0, -M_PI_2);
    _invisibleWallForPhysicsSlide = wallNode;
    
    //right (the actual wall on the right)
    wallNode = [wallWithBaseboardNode clone];
    wallNode.physicsBody = nil;
    wallNode.position = SCNVector3Make(600, 100, 40);
    wallNode.rotation = SCNVector4Make(0, 1, 0, -M_PI_2);
    [_scene.rootNode addChildNode:wallNode];
    
    //top
    wallNode = [wallWithBaseboardNode copy];
    wallNode.geometry = [wallNode.geometry copy];
    wallNode.geometry.firstMaterial = [SCNMaterial material];
    wallNode.opacity = 1;
    wallNode.position = SCNVector3Make(200, 200, 0);
    wallNode.scale = SCNVector3Make(1, 10, 1);
    wallNode.rotation = SCNVector4Make(1, 0, 0, M_PI_2);
    [_scene.rootNode addChildNode:wallNode];
    
    _mainWall.hidden = YES; //hide at first (save some milliseconds)
}

- (void)setupIntroEnvironment
{
    _introductionStep = 1;
    
    // configure the lighting for the introduction (dark lighting)
    _ambientLightNode.light.color = [SKColor blackColor];
    _spotLightNode.light.color = [SKColor blackColor];
    _spotLightNode.position = SCNVector3Make(50, 90, -50);
    _spotLightNode.eulerAngles = SCNVector3Make(-M_PI_2*0.75, M_PI_4*0.5, 0);
    
    //put all texts under this node to remove all at once later
    _introNodeGroup = [SCNNode node];
    
    //Slide 1
#define LOGO_SIZE 70
#define TITLE_SIZE (TEXT_SCALE*0.45)
    SCNNode *sceneKitLogo = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:LOGO_SIZE height:LOGO_SIZE]];
    sceneKitLogo.geometry.firstMaterial.doubleSided = YES;
    sceneKitLogo.geometry.firstMaterial.diffuse.contents = @"SceneKit.png";
    sceneKitLogo.geometry.firstMaterial.emission.contents = @"SceneKit.png";
    _sceneKitLogo = sceneKitLogo;
    
    _sceneKitLogo.renderingOrder = -1;
    _floorNode.renderingOrder = -2;
    
    [_introNodeGroup addChildNode:sceneKitLogo];
    sceneKitLogo.position = SCNVector3Make(200, LOGO_SIZE/2, 200);
    
    SCNVector3 position = SCNVector3Make(200, 0, 200);
    
    _cameraNode.position = SCNVector3Make(200, -20, position.z+150);
    _cameraNode.eulerAngles = SCNVector3Make(-M_PI_2*0.06, 0, 0);
    
    /* hierarchy
     shipHandle
     |_ shipXTranslate
     |_ shipPivot
     |_ ship */
    SCNScene *modelScene = [SCNScene sceneNamed:@"ship.dae" inDirectory:@"art.scnassets/models" options:nil];
    _shipNode = [modelScene.rootNode childNodeWithName:@"Aircraft" recursively:YES];
    
    SCNNode*shipMesh = _shipNode.childNodes[0];
    // shipMesh.geometry.firstMaterial.fresnelExponent = 1.0;
    shipMesh.geometry.firstMaterial.emission.intensity = 0.5;
    shipMesh.renderingOrder = -3;
    
    _shipPivot = [SCNNode node];
    SCNNode *shipXTranslate = [SCNNode node];
    _shipHandle = [SCNNode node];
    
    _shipHandle.position =  SCNVector3Make(200 - 500, 0, position.z + 30);
    _shipNode.position = SCNVector3Make(50, 30, 0);
    
    [_shipPivot addChildNode:_shipNode];
    [shipXTranslate addChildNode:_shipPivot];
    [_shipHandle addChildNode:shipXTranslate];
    [_introNodeGroup addChildNode:_shipHandle];
    
    //animate ship
    [_shipNode removeAllActions];
    _shipNode.rotation = SCNVector4Make(0, 0, 1, M_PI_4*0.5);
    
    //make spotlight relative to the ship
    SCNVector3 newPosition = SCNVector3Make(50, 100, 0);
    SCNMatrix4 oldTransform = [_shipPivot convertTransform:SCNMatrix4Identity fromNode:_spotLightNode];
    
    [_spotLightNode removeFromParentNode];
    _spotLightNode.transform = oldTransform;
    [_shipPivot addChildNode:_spotLightNode];
    
    _spotLightNode.position = newPosition; // will animate implicitly
    _spotLightNode.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
    _spotLightNode.light.spotOuterAngle = 120;
    
    _shipPivot.eulerAngles = SCNVector3Make(0, M_PI_2, 0);
    SCNAction *action = [SCNAction sequence:@[[SCNAction repeatActionForever:[SCNAction rotateByX:0 y:M_PI z:0 duration:2]]]];
    [_shipPivot runAction:action];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position.x"];
    animation.fromValue = @(-50);
    animation.toValue =  @(+50);
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.autoreverses = YES;
    animation.duration = 2;
    animation.repeatCount = MAXFLOAT;
    animation.timeOffset = -animation.duration*0.5;
    [shipXTranslate addAnimation:animation forKey:nil];
    
    SCNNode *emitter = [_shipNode childNodeWithName:@"emitter" recursively:YES];
    SCNParticleSystem *ps = [SCNParticleSystem particleSystemNamed:@"reactor.scnp" inDirectory:@"art.scnassets/particles"];
    [emitter addParticleSystem:ps];
    _shipHandle.position = SCNVector3Make(_shipHandle.position.x, _shipHandle.position.y, _shipHandle.position.z-50);
    
    [_scene.rootNode addChildNode:_introNodeGroup];
    
    //wait, then fade in light
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:1.0];
    [SCNTransaction setCompletionBlock:^{
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:2.5];
        
        _shipHandle.position = SCNVector3Make(_shipHandle.position.x+500, _shipHandle.position.y, _shipHandle.position.z);
        
        _spotLightNode.light.color = [SKColor colorWithWhite:1 alpha:1];
        sceneKitLogo.geometry.firstMaterial.emission.intensity = 0.80;
        
        [SCNTransaction commit];
    }];
    
    _spotLightNode.light.color = [SKColor colorWithWhite:0.001 alpha:1];
    
    [SCNTransaction commit];
}




#pragma mark -
#pragma mark UIKit configuration



- (BOOL)shouldAutorotate
{
    return YES;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}



#pragma mark - Gestures

- (void)gestureDidEnd
{
    if (_step == 3) {
        //bubbles
        _fieldOwner.physicsField.strength = 0.0;
    }
}

- (void)gestureDidBegin
{
    _initialOffset = _lastOffset;
}

#if TARGET_OS_IPHONE
- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer
{
//    [self restoreCameraAngle];
}

- (void)handlePan:(UITapGestureRecognizer *)gestureRecognizer
{
//    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
//        [self gestureDidEnd];
//        return;
//    }
//    
//    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
//        [self gestureDidBegin];
//        return;
//    }
//    
//    if (gestureRecognizer.numberOfTouches == 2) {
//        [self tiltCameraWithOffset:[(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.view]];
//    }
//    else {
//        CGPoint p = [gestureRecognizer locationInView:self.view];
//        [self handlePanAtPoint:p];
//    }
}

- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer
{
//    CGPoint p = [gestureRecognizer locationInView:self.view];
//    [self handleTapAtPoint:p];
}
#endif


- (void)handlePanAtPoint:(CGPoint) p
{
//    SCNView *scnView = (SCNView *) self.view;
//    
//    if (_step == 2) {
//        //particles
//        SCNVector3 pTmp = [scnView projectPoint:SCNVector3Make(0, 0, 0)];
//        SCNVector3 p3d = [scnView unprojectPoint:SCNVector3Make(p.x, p.y, pTmp.z)];
//        SCNMatrix4 handlePos = _handle.worldTransform;
//        
//        
//        float dy = MAX(0, p3d.y - handlePos.m42);
//        float dx = handlePos.m41 - p3d.x;
//        float angle = atan2f(dy, dx);
//        
//        
//        angle -= 35.*M_PI/180.0; //handle is 35 degree by default
//        
//        //clamp
//#define MIN_ANGLE -M_PI_2*0.1
//#define MAX_ANGLE M_PI*0.8
//        if (angle < MIN_ANGLE) angle = MIN_ANGLE;
//        if (angle > MAX_ANGLE) angle = MAX_ANGLE;
//        
//        
//#define HIT_DELAY 3.0
//        
//        if (angle <= 0.66 && angle >= 0.48) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HIT_DELAY * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                //hit the fire!
//                _hitFire = YES;
//            });
//        }
//        else {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HIT_DELAY * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                //hit the fire!
//                _hitFire = NO;
//            });
//        }
//        
//        _handle.rotation = SCNVector4Make(1, 0, 0, angle);
//    }
//    
//    if (_step == 3) {
//        //bubbles
//        [self moveEmitterTo:p];
//    }
}

- (void)handleDoubleTapAtPoint:(CGPoint)p
{
//    [self restoreCameraAngle];
}

- (void) preventAccidentalNext:(CGFloat) delay
{
//    _preventNext = YES;
//    
//    //disable the next button for "delay" seconds to prevent accidental tap
//    AAPLSpriteKitOverlayScene *overlay = (AAPLSpriteKitOverlayScene *)((SCNView*)self.view).overlaySKScene;
//    [overlay.nextButton runAction:[SKAction fadeAlphaBy:-0.5 duration:0.5]];
//    [overlay.previousButton runAction:[SKAction fadeAlphaBy:-0.5 duration:0.5]];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        _preventNext = NO;
//        [overlay.previousButton runAction:[SKAction fadeAlphaTo:_step > 1 ? 1 : 0 duration:0.75]];
//        [overlay.nextButton runAction:[SKAction fadeAlphaTo:_introductionStep == 0 && _step < 5 ? 1 : 0 duration:0.75]];
//    });
}

- (void)handleTapAtPoint:(CGPoint)p
{
//    //test buttons
//    SKScene *skScene = ((SCNView*)self.view).overlaySKScene;
//    CGPoint p2D = [skScene convertPointFromView:p];
//    SKNode *node = [skScene nodeAtPoint:p2D];
//    
//    // wait X seconds before enabling the next tap to avoid accidental tap
//    BOOL ignoreNext = _preventNext;
//    
//    if (_introductionStep) {
//        //next introduction step
//        if (!ignoreNext){
//            [self preventAccidentalNext:1];
//            [self nextIntroductionStep];
//        }
//        return;
//    }
//    
//    if (ignoreNext == NO) {
//        if (_step == 0 || [node.name isEqualToString:@"next"] || [node.name isEqualToString:@"back"]) {
//            BOOL shouldGoBack = [node.name isEqualToString:@"back"];
//            
//            if ([node.name isEqualToString:@"next"]) {
//                ((SKSpriteNode*)node).color = [SKColor colorWithRed:1 green:0 blue:0 alpha:1];
//                [node runAction:[SKAction customActionWithDuration:0.7 actionBlock:^(SKNode *node, CGFloat elapsedTime) {
//                    ((SKSpriteNode*)node).colorBlendFactor = 0.7 - elapsedTime;
//                }]];
//            }
//            
//            [self restoreCameraAngle];
//            
//            [self preventAccidentalNext:_step==1 ? 3 : 1];
//            
//            if (shouldGoBack)
//                [self previous];
//            else
//                [self next];
//            
//            return;
//        }
//    }
//    
//    if (_step == 1) {
//        //bounce physics!
//        SCNView *scnView = (SCNView *) self.view;
//        SCNVector3 pTmp = [scnView projectPoint:SCNVector3Make(0, 0, -60)];
//        SCNVector3 p3d = [scnView unprojectPoint:SCNVector3Make(p.x, p.y, pTmp.z)];
//        
//        p3d.y = 0;
//        p3d.z = 0;
//        
//        [self explosionAt:p3d receivers:_boxes removeOnCompletion:NO];
//    }
//    if (_step == 3) {
//        //bubbles
//        [self moveEmitterTo:p];
//    }
//    
//    if (_step == 5) {
//        //shader
//        [self showNextShaderStage];
//    }
}


@end
