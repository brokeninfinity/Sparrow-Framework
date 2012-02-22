//
// SHClippedSprite.m
// Sparrow
//
// Created by Shilo White on 5/30/11.
// Copyright 2011 Shilocity Productions. All rights reserved.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the Simplified BSD License.
//
// Modified by Kile Schwaneke on 9/19/2011
// Copyright 2011 BodSix, Inc. All rights reserved.
//

#import "SHClippedSprite.h"

#import "SPDisplayObject.h"
#import "SPEvent.h"
#import "SPQuad.h"
#import "SPStage.h"
#import "SPTouchEvent.h"
#import "SPTween.h"
#import <OpenGLES/ES1/gl.h>

static const float BOUNCE_DURATION   = 0.5f;

@interface SHClippedSprite ()

- (void)onAddedToStage:(SPEvent *)event;
- (void)onClippedSpriteTouch:(SPTouchEvent*)touchEvent;
- (void)bounceMenuItems;

@end

@implementation SHClippedSprite

+ (SHClippedSprite *)clippedSprite {
  return [[[SHClippedSprite alloc] init] autorelease];
}

- (SHClippedSprite *)init {
  if ((self = [super init])) {
    mClip = [[SPQuad alloc] init];
    mClip.visible = NO;
    mClip.width = 0;
    mClip.height = 0;
    [super addChild:mClip]; // Avoid our own addChild as it increments by 1 to avoid the mClip
    mClipping = NO;
    mIsScrolling = NO;
    [self addEventListener:@selector(onAddedToStage:) atObject:self forType:SP_EVENT_TYPE_ADDED_TO_STAGE];
    [self addEventListener:@selector(onClippedSpriteTouch:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
  }
  return self;
}

- (void)dealloc {
  [self removeEventListener:@selector(onAddedToStage:) atObject:self forType:SP_EVENT_TYPE_ADDED_TO_STAGE];
  [self removeEventListener:@selector(onClippedSpriteTouch:) atObject:self forType:SP_EVENT_TYPE_TOUCH];

  [mClip release];
  [super dealloc];
}

@synthesize clip = mClip;
@synthesize clipping = mClipping;

#pragma mark - overridding base class methods so that callers don't need to care
- (void)setWidth:(float)width {
  mClip.width = width;
  [super setWidth:width];
}

- (void)setHeight:(float)height {
  mClip.height = height;
  [super setHeight:height];
}

- (void)removeAllChildren
{
  [mClip retain];
  [super removeAllChildren];
  [self addChild:mClip];
  [mClip release];
}

#pragma mark -
- (void)onAddedToStage:(SPEvent *)event {
  [self removeEventListener:@selector(onAddedToStage:) atObject:self forType:SP_EVENT_TYPE_ADDED_TO_STAGE];
  mStage = (SPStage *)self.stage;
}

- (void)render:(SPRenderSupport *)support {
  if (mClipping) {
    glEnable(GL_SCISSOR_TEST);
    SPRectangle *clip = [mClip boundsInSpace:mStage];
    glScissor((clip.x*[SPStage contentScaleFactor]), (mStage.height*[SPStage contentScaleFactor])-(clip.y*[SPStage contentScaleFactor])-(clip.height*[SPStage contentScaleFactor]), (clip.width*[SPStage contentScaleFactor]), (clip.height*[SPStage contentScaleFactor]));
    [super render:support];
    glDisable(GL_SCISSOR_TEST);
  } else {
    [super render:support];
  }
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetCoordinateSpace {
  if (mClipping) {
    return [mClip boundsInSpace:targetCoordinateSpace];
  } else {
    return [super boundsInSpace:targetCoordinateSpace];
  }
}

#pragma mark - NSFastEnumeration
-(NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
  [mClip retain];
  [mClip removeFromParent];

  NSUInteger retVal = [super countByEnumeratingWithState:state objects:stackbuf count:len];

  [self addChild:mClip atIndex:0];
  [mClip release];

  return retVal;
}

#pragma mark - scrolling
- (void)onClippedSpriteTouch:(SPTouchEvent*)touchEvent {
  SPTouch *touch = [[[touchEvent touchesWithTarget:self] allObjects] objectAtIndex:0];
  SPPoint *touchPos = [touch locationInSpace:self];

  if (touch.phase == SPTouchPhaseMoved) {
    mIsScrolling = YES;

    for (SPDisplayObject *spdo in self) {
      spdo.x += touchPos.x - lastTouchX;
    }
  } else if (touch.phase == SPTouchPhaseEnded) {
    mIsScrolling = NO;
    [self bounceMenuItems];
  }

  lastTouchX = touchPos.x;
}

- (void)bounceMenuItems {
  if (1 == self.numChildren)
    return;

  // min could be negative and max could be out of view.  This is a feature.
  SPDisplayObject *lastchild = [self childAtIndex:self.numChildren - 1];
  float max = lastchild.x + lastchild.width;
  float min = [self childAtIndex:1].x; // Skip the mClip - I wish I didn't have to know about this, but I can't see a way to make SHClippedSprite hide it

  float bounceDistance;
    for (SPDisplayObject *spdo in self) {
    if (min > 0.0f || (max - min) < self.width)
      bounceDistance = 0.0f - min;
    else if (max < self.width)
      bounceDistance = self.width - max;
    else
      continue;

    SPTween *bounceMenuItems = [SPTween tweenWithTarget:spdo time:BOUNCE_DURATION transition:SP_TRANSITION_EASE_OUT];
    [bounceMenuItems animateProperty:@"x" targetValue:spdo.x + bounceDistance];
    [self.stage.juggler addObject:bounceMenuItems];
  }
}

@end

#pragma mark - SPDisplayObject (ClippedHitTest)
@implementation SPDisplayObject (ClippedHitTest)
- (SPDisplayObject*)hitTestPoint:(SPPoint*)localPoint forTouch:(BOOL)isTouch
{
  if (isTouch && (!mVisible || !mTouchable)) return nil;
  
  SPDisplayObject *parent = self.parent;
  while (parent) {
    if ([parent isKindOfClass:[SHClippedSprite class]]) {
      SPMatrix *transformationMatrix = [self transformationMatrixToSpace:parent];
      SPPoint *transformedPoint = [transformationMatrix transformPoint:localPoint];
      if (![[parent boundsInSpace:parent] containsPoint:transformedPoint])
        return nil;
    }
    
    parent = parent.parent;
  }
  
  if ([[self boundsInSpace:self] containsPoint:localPoint]) return self;
  else return nil;
}

@end

