#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <Cocoa/Cocoa.h>

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);
CGSize CGSizeAspectFit(CGSize aspectRatio, CGSize boundingSize);
CGSize CGSizeAspectFit(CGSize aspectRatio, CGSize boundingSize)
{
    float mW = boundingSize.width / aspectRatio.width;
    float mH = boundingSize.height / aspectRatio.height;
    if( mH < mW )
        boundingSize.width = boundingSize.height / aspectRatio.height * aspectRatio.width;
    else if( mW < mH )
        boundingSize.height = boundingSize.width / aspectRatio.width * aspectRatio.height;
    return boundingSize;
}

//-------------------------------------------------------------------
//      patternMake2
//-------------------------------------------------------------------
void pattern2Callback (void *info, CGContextRef context) {
    CGImageRef imageRef = (CGImageRef)info;
    CGContextDrawImage(context, CGRectMake(0, 0, 8, 8), imageRef);
}

void patternReleaseCallback (void *info) {
    CGImageRef imageRef = (CGImageRef)info;
    CGImageRelease(imageRef);
}

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    CGDataProviderRef dataProvieder = CGDataProviderCreateWithURL(url);
    if (dataProvieder == NULL) {
        return noErr;
    }
    
    NSDictionary *thumbnailProperties = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent : @YES,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(MAX(maxSize.width, maxSize.height)),
        (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
        (NSString *)kCGImageSourceShouldCache : @YES
    };
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(url, (__bridge CFDictionaryRef)thumbnailProperties);
    if (imageSource == NULL) {
        return noErr;
    }
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)thumbnailProperties);
    CFRelease(imageSource);
    
    if (!imageRef) {
        return noErr;
    }
    CFURLRef bundleURL = CFBundleCopyBundleURL(QLThumbnailRequestGetGeneratorBundle(thumbnail));
    
    NSURL *pathToImage = [[NSBundle bundleWithURL:(__bridge NSURL *)bundleURL] URLForImageResource:@"transparency-bg.png"];
    CFRelease(bundleURL);
    CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)(pathToImage));
    CGImageRef transImage = CGImageCreateWithPNGDataProvider(provider, NULL, NO, kCGRenderingIntentDefault);
    
    static const CGPatternCallbacks callbacks = { 0, &pattern2Callback, &patternReleaseCallback };
    
    CGSize imageSize = (CGSize){CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)};
    imageSize = CGSizeAspectFit(imageSize, maxSize);
    CGContextRef _context = QLThumbnailRequestCreateContext(thumbnail, imageSize, false, NULL);
    if (_context) {
        CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
        CGContextSetFillColorSpace(_context, patternSpace);
        CGColorSpaceRelease(patternSpace);
        CGSize patternSize = CGSizeMake(8, 8);
        CGPatternRef pattern = CGPatternCreate(transImage, (CGRect){CGPointZero, imageSize}, CGAffineTransformIdentity, patternSize.width, patternSize.height, kCGPatternTilingConstantSpacing, true, &callbacks);
        CGFloat alpha = 1;
        CGContextSetFillPattern(_context, pattern, &alpha);
        CGPatternRelease(pattern);
        CGContextFillRect(_context, (CGRect){CGPointZero, imageSize});
        CGContextSetBlendMode(_context, kCGBlendModeNormal);
        CGContextDrawImage(_context, (CGRect){CGPointZero, imageSize}, imageRef);
        QLThumbnailRequestFlushContext(thumbnail, _context);
        CFRelease(_context);
    }
    CGDataProviderRelease(provider);

    
    CGImageRelease(imageRef);
    
    return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
