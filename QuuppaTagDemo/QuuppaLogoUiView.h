//
//  QuuppaLogoUiView.h
//  QuuppaTagDemo
//
//  Created by Quuppa on 07/02/15.
//  Copyright (c) 2015 Quuppa. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QuuppaLogoUiView : UIView

@property (strong, nonatomic) UIColor *logoColor;

@property BOOL animating;

-(void) startAnim;
-(void) stopAnim;

@end
