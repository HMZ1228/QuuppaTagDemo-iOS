//
//  OnboardingOverlayView.h
//  QuuppaTagDemo  v3.0
//
//  A full-screen overlay UIView that presents a 3-step walkthrough
//  on the user's first launch.  Shown once per install; can be reset
//  for debug/testing via +resetOnboarding.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Called when the user completes or skips onboarding.
typedef void (^OnboardingCompletionBlock)(void);

@interface OnboardingOverlayView : UIView

/// Present the onboarding overlay in @p parentView if the user has not
/// seen it before.  The overlay fills the parent view.  @p completion
/// is invoked on the main queue when the user taps "Get Started" or "Skip".
///
/// If the user has already completed onboarding, @p completion is called
/// immediately with no overlay presented.
///
/// @param parentView  The view to add the overlay to (typically the root view).
/// @param chinese     YES to display Simplified Chinese text.
/// @param completion  Called when onboarding is finished or skipped.
+ (void)presentIfNeededInView:(UIView *)parentView
                      chinese:(BOOL)chinese
                   completion:(OnboardingCompletionBlock)completion;

/// Force the onboarding to be shown again on next call to
/// +presentIfNeededInView:chinese:completion: (for debug / QA testing).
+ (void)resetOnboarding;

@end

NS_ASSUME_NONNULL_END
