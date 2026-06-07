//
//  QuuppaLogoUiView.m
//  QuuppaTagDemo
//
//  Updated for modern iOS (iOS 13+)
//  Original created by Quuppa on 07/02/15.
//  Copyright (c) 2015 Quuppa. All rights reserved.
//
//  Changes from original:
//  - stopAnim now uses UIViewPropertyAnimator to cleanly cancel in-flight animation
//  - startAnim guards against double-starting
//

#import "QuuppaLogoUiView.h"

@implementation QuuppaLogoUiView

- (void)initialize {
    _logoColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    _animating = NO;
    [self setContentMode:UIViewContentModeRedraw];
}

- (id)initWithCoder:(NSCoder *)aCoder {
    if (self = [super initWithCoder:aCoder]) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)rect {
    if (self = [super initWithFrame:rect]) {
        [self initialize];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    float sw = self.frame.size.width;
    float sh = self.frame.size.height;
    float cx = sw / 2.0f;
    float cy = sh / 2.0f;
    float logoDim = MIN(sw, sh) * 0.5f / 2.0f;
    float logoThickness = logoDim * 0.2f;

    CGContextSetStrokeColorWithColor(context, _logoColor.CGColor);
    CGContextSetLineWidth(context, logoThickness);
    CGContextAddArc(context, cx, cy, logoDim, 0.5f * M_PI, 0.6f * M_PI, 1);
    CGContextMoveToPoint(context, cx, cy + logoDim / 2.0f);
    CGContextAddLineToPoint(context, cx, cy + logoDim * 1.5f);
    CGContextStrokePath(context);
}

- (void)setLogoColor:(UIColor *)logoColor {
    _logoColor = logoColor;
    [self setNeedsDisplay];
}

- (void)startAnim {
    if (_animating) return;

    // Reset alpha before starting so the animation always starts clean
    self.alpha = 1.0f;
    self.animating = YES;

    [UIView animateWithDuration:1.0f
                          delay:0.0f
                        options:(UIViewAnimationOptionAutoreverse |
                                 UIViewAnimationOptionRepeat |
                                 UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
        self.alpha = 0.3f;
    }
                     completion:nil];
}

- (void)stopAnim {
    // Cancel all animations on this view's layer, then restore full opacity
    [self.layer removeAllAnimations];
    self.alpha = 1.0f;
    self.animating = NO;
}

@end
