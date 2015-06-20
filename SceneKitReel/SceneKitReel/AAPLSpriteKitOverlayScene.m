//
//  AAPLSpriteKitOverlayScene.m
//  SceneKitReel
//
//  Created by ZhangBo on 15/6/21.
//  Copyright (c) 2015年 ZhangBo. All rights reserved.
//

#import "AAPLSpriteKitOverlayScene.h"

@implementation AAPLSpriteKitOverlayScene
{
@private
    SKNode *_nextButton;
    SKNode *_previousButton;
    CGSize _size;
    SKLabelNode *_label;
}

- (instancetype)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        _size = size;
        
        /* Setup your scene here */
        self.anchorPoint = CGPointMake(0.5, 0.5);
        self.scaleMode = SKSceneScaleModeResizeFill;
        
        //buttons
        _nextButton = [SKSpriteNode spriteNodeWithImageNamed:@"next.png"];
        
        float marginY = 60;
        float maringX = -60;
#if TARGET_OS_IPHONE
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            marginY = 30;
            marginY = 30;
        }
#endif
        
        _nextButton.position = CGPointMake(size.width * 0.5 + maringX, -size.height * 0.5 + marginY);
        _nextButton.name = @"next";
        _nextButton.alpha = 0.01;
#if TARGET_OS_IPHONE
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            _nextButton.xScale = _nextButton.yScale = 0.5;
        }
#endif
        [self addChild:_nextButton];
        
        _previousButton = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:_nextButton.frame.size];
        _previousButton.position = CGPointMake(-(size.width * 0.5 + maringX), -size.height * 0.5 + marginY);
        _previousButton.name = @"back";
        _previousButton.alpha = 0.01;
        [self addChild:_previousButton];
    }
    return self;
}

- (void)showLabel:(NSString *)label
{
    if (!_label) {
        _label = [SKLabelNode labelNodeWithFontNamed:@"Myriad Set"];
        if(!_label)
            _label = [SKLabelNode labelNodeWithFontNamed:@"Avenir-Heavy"];
        _label.fontSize = 140;
        _label.position = CGPointMake(0,0);
        
        [self addChild:_label];
    }
    else {
        if (label)
            _label.position = CGPointMake(0, _size.height * 0.25);
    }
    
    if (!label) {
        [_label runAction:[SKAction fadeOutWithDuration:0.5]];
    }
    else {
#if TARGET_OS_IPHONE
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            _label.fontSize = [label length] > 10 ? 50 : 80;
        }
        else
#endif
        {
            _label.fontSize = [label length] > 10 ? 100 : 140;
        }
        
        _label.text = label;
        _label.alpha = 0.0;
        [_label runAction:[SKAction sequence:@[[SKAction waitForDuration:0.5], [SKAction fadeInWithDuration:0.5]]]];
    }
}

@end
