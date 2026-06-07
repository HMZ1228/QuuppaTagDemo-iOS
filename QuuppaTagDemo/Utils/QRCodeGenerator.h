//
//  QRCodeGenerator.h
//  QuuppaTagDemo  v3.0
//
//  Generates QR code UIImages using the CoreImage CIQRCodeGenerator filter.
//  No third-party libraries required.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QRCodeGenerator : NSObject

/// Returns a high-resolution QR code image encoding the given string.
/// The image is rendered at @p pointSize × @p pointSize points, suitable
/// for display in a UIImageView with contentMode = UIViewContentModeScaleAspectFit.
///
/// @param string    The text to encode (e.g. a Quuppa Tag ID such as "112233445566").
/// @param pointSize The desired output square size in points (e.g. 200).
/// @param fgColor   Foreground (module) colour — pass nil for black.
/// @param bgColor   Background colour — pass nil for white.
/// @return A UIImage, or nil if encoding fails.
+ (nullable UIImage *)imageForString:(NSString *)string
                            pointSize:(CGFloat)pointSize
                     foregroundColor:(nullable UIColor *)fgColor
                     backgroundColor:(nullable UIColor *)bgColor;

@end

NS_ASSUME_NONNULL_END
