//
//  QRCodeGenerator.m
//  QuuppaTagDemo  v3.0
//

#import "QRCodeGenerator.h"
@import CoreImage;

@implementation QRCodeGenerator

+ (nullable UIImage *)imageForString:(NSString *)string
                            pointSize:(CGFloat)pointSize
                     foregroundColor:(nullable UIColor *)fgColor
                     backgroundColor:(nullable UIColor *)bgColor {
    if (!string.length || pointSize <= 0) return nil;

    // 1. Encode string to UTF-8 data
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;

    // 2. Generate raw QR CIImage via CIQRCodeGenerator
    //    Correction level M (≈15 % recovery capacity)
    CIFilter *generator = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [generator setValue:data forKey:@"inputMessage"];
    [generator setValue:@"M" forKey:@"inputCorrectionLevel"];

    CIImage *rawQR = generator.outputImage;
    if (!rawQR) return nil;

    // 3. Scale to requested point size (multiply by screen scale for crisp pixels)
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat pixelSize   = pointSize * screenScale;
    CGFloat scaleFactor = pixelSize / rawQR.extent.size.width;
    CIImage *scaledQR   = [rawQR imageByApplyingTransform:
                           CGAffineTransformMakeScale(scaleFactor, scaleFactor)];

    // 4. Apply foreground / background colours using CIFalseColor
    UIColor *fg = fgColor ?: [UIColor blackColor];
    UIColor *bg = bgColor ?: [UIColor whiteColor];

    CIFilter *colorFilter = [CIFilter filterWithName:@"CIFalseColor"];
    [colorFilter setValue:scaledQR forKey:kCIInputImageKey];
    [colorFilter setValue:[CIColor colorWithCGColor:fg.CGColor] forKey:@"inputColor0"];
    [colorFilter setValue:[CIColor colorWithCGColor:bg.CGColor] forKey:@"inputColor1"];

    CIImage *coloredQR = colorFilter.outputImage ?: scaledQR;

    // 5. Render to UIImage via CGImage (sharper than imageWithCIImage: on device)
    CIContext *ctx = [CIContext context];
    CGImageRef cgImage = [ctx createCGImage:coloredQR fromRect:coloredQR.extent];
    if (!cgImage) return nil;

    UIImage *result = [UIImage imageWithCGImage:cgImage
                                          scale:screenScale
                                    orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return result;
}

@end
