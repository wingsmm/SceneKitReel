//
//  AAPLSpriteKitOverlayScene.h
//  SceneKitReel
//
//  Created by ZhangBo on 15/6/21.
//  Copyright (c) 2015年 ZhangBo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <SpriteKit/SpriteKit.h>

@interface AAPLSpriteKitOverlayScene : SKScene

@property (readonly) SKNode *nextButton;
@property (readonly) SKNode *previousButton;
@property (readonly) SKNode *buttonGroup;

- (void)showLabel:(NSString *)label;

@end
