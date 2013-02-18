//
//  FXImageView.m
//
//  Version 1.2.3
//
//  Created by Nick Lockwood on 31/10/2011.
//  Copyright (c) 2011 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXImageView
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "FXImageView.h"
#import "UIImage+FX.h"
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>


@interface FXImageOperation : NSOperation

@property (nonatomic, strong) FXImageView *target;

@end


@interface FXImageView ()

@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSURL *imageContentURL;

- (void)processImage;

@end


@implementation FXImageOperation

@synthesize target = _target;

- (void)main
{
    @autoreleasepool
    {
        [_target processImage];
    }
}

#if !__has_feature(objc_arc)

- (void)dealloc
{
    [_target release];
    [super dealloc];
}

#endif

@end


@implementation FXImageView

@synthesize asynchronous = _asynchronous;
@synthesize reflectionGap = _reflectionGap;
@synthesize reflectionScale = _reflectionScale;
@synthesize reflectionAlpha = _reflectionAlpha;
@synthesize shadowColor = _shadowColor;
@synthesize shadowOffset = _shadowOffset;
@synthesize shadowBlur = _shadowBlur;
@synthesize cornerRadius = _cornerRadius;
@synthesize customEffectsBlock = _customEffectsBlock;
@synthesize cacheKey = _cacheKey;

@synthesize originalImage = _originalImage;
@synthesize imageView = _imageView;
@synthesize imageContentURL = _imageContentURL;


#pragma mark -
#pragma mark Shared storage

+ (NSOperationQueue *)processingQueue
{
    static NSOperationQueue *sharedQueue = nil;
    if (sharedQueue == nil)
    {
        sharedQueue = [[NSOperationQueue alloc] init];
        [sharedQueue setMaxConcurrentOperationCount:4];
    }
    return sharedQueue;
}

+ (NSCache *)processedImageCache
{
    static NSCache *sharedCache = nil;
    if (sharedCache == nil)
    {
        sharedCache = [[NSCache alloc] init];
    }
    return sharedCache;
}


#pragma mark -
#pragma mark Setup

- (void)setUp
{
    self.shadowColor = [UIColor blackColor];
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
	[_imageView setTransform:CGAffineTransformMakeScale(1, -1)];
    _imageView.contentMode = UIViewContentModeCenter;
    [self addSubview:_imageView];
    [self setImage:super.image];
	[self setTransform:CGAffineTransformMakeScale(1, -1)];
    super.image = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    if ((self = [super initWithImage:image]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
    if ((self = [super initWithImage:image highlightedImage:highlightedImage]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

#if !__has_feature(objc_arc)

- (void)dealloc
{
    [_customEffectsBlock release];
    [_cacheKey release];
    [_originalImage release];
    [_shadowColor release];
    [_imageView release];
    [_imageContentURL release];
    [super dealloc];
}

#endif


#pragma mark -
#pragma mark Caching

- (NSString *)colorHash:(UIColor *)color
{
    NSString *colorString = @"{0.00,0.00}";
    if (color && ![color isEqual:[UIColor clearColor]])
    {
        NSInteger componentCount = CGColorGetNumberOfComponents(color.CGColor);
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        NSMutableArray *parts = [NSMutableArray arrayWithCapacity:componentCount];
        for (int i = 0; i < componentCount; i++)
        {
            [parts addObject:[NSString stringWithFormat:@"%.2f", components[i]]];
        }
        colorString = [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }
    return colorString;
}

- (NSString *)imageHash:(UIImage *)image
{
    static NSInteger hashKey = 1;
    NSString *number = objc_getAssociatedObject(image, @"FXImageHash");
    if (!number && image)
    {
        number = [NSString stringWithFormat:@"%i", hashKey++];
        objc_setAssociatedObject(image, @"FXImageHash", number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return number;
}

- (NSString *)cacheKey
{
    if (_cacheKey) return _cacheKey;
    
    return [NSString stringWithFormat:@"%@_%@_%.2f_%.2f_%.2f_%@_%@_%.2f_%.2f_%i",
            _imageContentURL ?: [self imageHash:_originalImage],
            NSStringFromCGSize(self.bounds.size),
            _reflectionGap,
            _reflectionScale,
            _reflectionAlpha,
            [self colorHash:_shadowColor],
            NSStringFromCGSize(_shadowOffset),
            _shadowBlur,
            _cornerRadius,
            self.contentMode];
}

- (void)cacheProcessedImage:(UIImage *)processedImage forKey:(NSString *)cacheKey
{
    [[[self class] processedImageCache] setObject:processedImage forKey:cacheKey];
}

- (UIImage *)cachedProcessedImage
{
    return [[[self class] processedImageCache] objectForKey:[self cacheKey]];
}

#pragma mark -
#pragma mark Processing

- (void)setProcessedImageOnMainThread:(NSArray *)array
{
    //get images
    NSString *cacheKey = [array objectAtIndex:1];
    UIImage *processedImage = [array objectAtIndex:0];
    processedImage = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
    
    if (processedImage)
    {
        //cache image
        [self cacheProcessedImage:processedImage forKey:cacheKey];
    }
    
    //set image
    if ([[self cacheKey] isEqualToString:cacheKey])
    {
        //implement crossfade transition without needing to import QuartzCore
        id animation = objc_msgSend(NSClassFromString(@"CATransition"), @selector(animation));
        objc_msgSend(animation, @selector(setType:), @"kCATransitionFade");
        objc_msgSend(self.layer, @selector(addAnimation:forKey:), animation, nil);
        
        //set processed image
        [self willChangeValueForKey:@"processedImage"];
        _imageView.image = processedImage;
		[self markFaces:processedImage.CGImage];
        [self didChangeValueForKey:@"processedImage"];
    }
}

- (void)markFaces:(CGImageRef)CGImage
{
    // draw a CI image with the previously loaded face detection picture
    CIImage* image = [CIImage imageWithCGImage:CGImage];
    
    // create a face detector - since speed is not an issue we'll use a high accuracy
    // detector
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:[NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy]];
    
    // create an array containing all the detected faces from the detector
    NSArray* features = [detector featuresInImage:image];
    
    // we'll iterate through every detected face.  CIFaceFeature provides us
    // with the width for the entire face, and the coordinates of each eye
    // and the mouth if detected.  Also provided are BOOL's for the eye's and
    // mouth so we can check if they already exist.
    for(CIFaceFeature *faceFeature in features)
    {
        // get the width of the face
        CGFloat faceWidth = faceFeature.bounds.size.width;
        
        // create a UIView using the bounds of the face
        UIView *faceView = [[UIView alloc] initWithFrame:faceFeature.bounds];
        // add a border around the newly created UIView
        faceView.layer.borderWidth = 1;
        faceView.layer.borderColor = [[UIColor redColor] CGColor];
        
        // add the new view to create a box around the face
        [self addSubview:faceView];
        
        if(faceFeature.hasLeftEyePosition)
        {
            // create a UIView with a size based on the width of the face
            UIView *leftEyeView = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.leftEyePosition.x-faceWidth*0.15, faceFeature.leftEyePosition.y-faceWidth*0.15, faceWidth*0.3, faceWidth*0.3)];
            // change the background color of the eye view
            [leftEyeView setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            // set the position of the leftEyeView based on the face
            [leftEyeView setCenter:faceFeature.leftEyePosition];
            // round the corners
            leftEyeView.layer.cornerRadius = faceWidth*0.15;
            // add the view to the window
            [self addSubview:leftEyeView];
        }
        
        if(faceFeature.hasRightEyePosition)
        {
            // create a UIView with a size based on the width of the face
            UIView* leftEye = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.rightEyePosition.x-faceWidth*0.15, faceFeature.rightEyePosition.y-faceWidth*0.15, faceWidth*0.3, faceWidth*0.3)];
            // change the background color of the eye view
            [leftEye setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            // set the position of the rightEyeView based on the face
            [leftEye setCenter:faceFeature.rightEyePosition];
            // round the corners
            leftEye.layer.cornerRadius = faceWidth*0.15;
            // add the new view to the window
            [self addSubview:leftEye];
        }
        
        if(faceFeature.hasMouthPosition)
        {
            // create a UIView with a size based on the width of the face
            UIView* mouth = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.mouthPosition.x-faceWidth*0.2, faceFeature.mouthPosition.y-faceWidth*0.2, faceWidth*0.4, faceWidth*0.4)];
            // change the background color for the mouth to green
            [mouth setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.3]];
            // set the position of the mouthView based on the face
            [mouth setCenter:faceFeature.mouthPosition];
            // round the corners
            mouth.layer.cornerRadius = faceWidth*0.2;
            // add the new view to the window
            [self addSubview:mouth];
        }
    }
}

- (void)processImage
{
    //get properties
    NSString *cacheKey = [self cacheKey];
    UIImage *image = _originalImage;
    NSURL *imageURL = _imageContentURL;
    CGSize size = self.bounds.size;
    CGFloat reflectionGap = _reflectionGap;
    CGFloat reflectionScale = _reflectionScale;
    CGFloat reflectionAlpha = _reflectionAlpha;
    UIColor *shadowColor = _shadowColor;
    CGSize shadowOffset = _shadowOffset;
    CGFloat shadowBlur = _shadowBlur;
    CGFloat cornerRadius = _cornerRadius;
    UIImage *(^customEffectsBlock)(UIImage *image) = [_customEffectsBlock copy];
    UIViewContentMode contentMode = self.contentMode;
    
#if !__has_feature(objc_arc)
	
    [[image retain] autorelease];
    [[imageURL retain] autorelease];
    [[shadowColor retain] autorelease];
    [customEffectsBlock autorelease];
    
#endif
    
    //check cache
    UIImage *processedImage = [self cachedProcessedImage];
    if (!processedImage)
    {
        //load image
        if (imageURL)
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:imageURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:30.0];
            NSError *error = nil;
            NSURLResponse *response = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            if (error)
            {
                NSLog(@"Error loading image for URL: %@, %@", imageURL, error);
                return;
            }
            else
            {
                image = [UIImage imageWithData:data];
                if ([[[imageURL path] stringByDeletingPathExtension] hasSuffix:@"@2x"])
                {
                    image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:image.imageOrientation];
                }
            }
        }
        
        if (image)
        {
            //crop and scale image
            processedImage = [image imageCroppedAndScaledToSize:size
                                                    contentMode:contentMode
                                                       padToFit:NO];
            
            //apply custom processing
            if (customEffectsBlock)
            {
                processedImage = customEffectsBlock(processedImage);
            }
            
            //clip corners
            if (cornerRadius)
            {
                processedImage = [processedImage imageWithCornerRadius:cornerRadius];
            }
            
            //apply shadow
            if (shadowColor && ![shadowColor isEqual:[UIColor clearColor]] &&
                (shadowBlur || !CGSizeEqualToSize(shadowOffset, CGSizeZero)))
            {
                reflectionGap -= 2.0f * (fabsf(shadowOffset.height) + shadowBlur);
                processedImage = [processedImage imageWithShadowColor:shadowColor
                                                               offset:shadowOffset
                                                                 blur:shadowBlur];
            }
            
            //apply reflection
            if (reflectionScale && reflectionAlpha)
            {
                processedImage = [processedImage imageWithReflectionWithScale:reflectionScale
                                                                          gap:reflectionGap
                                                                        alpha:reflectionAlpha];
            }
        }
    }
    
    //cache and set image
    if ([[NSThread currentThread] isMainThread])
    {
        if (processedImage)
        {
            [self cacheProcessedImage:processedImage forKey:cacheKey];
        }
        [self willChangeValueForKey:@"processedImage"];
        _imageView.image = processedImage;
		[self markFaces:processedImage.CGImage];
        [self didChangeValueForKey:@"processedImage"];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(setProcessedImageOnMainThread:)
                               withObject:[NSArray arrayWithObjects:
                                           processedImage ?: [NSNull null],
                                           cacheKey,
                                           nil]
                            waitUntilDone:YES];
    }
}

- (void)queueProcessingOperation:(FXImageOperation *)operation
{
    //suspend operation queue
    NSOperationQueue *queue = [[self class] processingQueue];
    [queue setSuspended:YES];
    
    //check for existing operations
    for (FXImageOperation *op in queue.operations)
    {
        if ([op isKindOfClass:[FXImageOperation class]])
        {
            if (op.target == self && ![op isExecuting])
            {
                //already queued
                [queue setSuspended:NO];
                return;
            }
        }
    }
    
    //make op a dependency of all queued ops
    NSInteger maxOperations = ([queue maxConcurrentOperationCount] > 0) ? [queue maxConcurrentOperationCount]: INT_MAX;
    NSInteger index = [queue operationCount] - maxOperations;
    if (index >= 0)
    {
        NSOperation *op = [[queue operations] objectAtIndex:index];
        if (![op isExecuting])
        {
            [op addDependency:operation];
        }
    }
    
    //add operation to queue
    [queue addOperation:operation];
    
    //resume queue
    [queue setSuspended:NO];
}

- (void)queueImageForProcessing
{
    //create processing operation
    FXImageOperation *operation = [[FXImageOperation alloc] init];
    operation.target = self;
    
    //set operation thread priority
    [operation setThreadPriority:1.0];
    
    //queue operation
    [self queueProcessingOperation:operation];
    
#if !__has_feature(objc_arc)
    
    [operation release];
    
#endif
    
}

- (void)updateProcessedImage
{
    id processedImage = [self cachedProcessedImage];
    if (!processedImage && !_originalImage && !_imageContentURL)
    {
        processedImage = [NSNull null];
    }
    if (processedImage)
    {
        //use cached version
        [self willChangeValueForKey:@"processedImage"];
        _imageView.image = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
        [self didChangeValueForKey:@"processedImage"];
    }
    else if (_asynchronous)
    {
        //process in background
        [self queueImageForProcessing];
    }
    else
    {
        //process on main thread
        [self processImage];
    }
}

- (void)layoutSubviews
{
    _imageView.frame = self.bounds;
    if (_imageContentURL || self.image)
    {
        [self updateProcessedImage];
    }
}


#pragma mark -
#pragma mark Setters and getters

- (UIImage *)processedImage
{
    return _imageView.image;
}

- (void)setProcessedImage:(UIImage *)image
{
    self.imageContentURL = nil;
    [self willChangeValueForKey:@"image"];
    self.originalImage = nil;
    [self didChangeValueForKey:@"image"];
    _imageView.image = image;
}

- (UIImage *)image
{
    return _originalImage;
}

- (void)setImage:(UIImage *)image
{
    if (_imageContentURL || ![image isEqual:_originalImage])
    {
        //update processed image
        self.imageContentURL = nil;
        self.originalImage = image;
        [self updateProcessedImage];
    }
}

- (void)setReflectionGap:(CGFloat)reflectionGap
{
    if (_reflectionGap != reflectionGap)
    {
        _reflectionGap = reflectionGap;
        [self setNeedsLayout];
    }
}

- (void)setReflectionScale:(CGFloat)reflectionScale
{
    if (_reflectionScale != reflectionScale)
    {
        _reflectionScale = reflectionScale;
        [self setNeedsLayout];
    }
}

- (void)setReflectionAlpha:(CGFloat)reflectionAlpha
{
    if (_reflectionAlpha != reflectionAlpha)
    {
        _reflectionAlpha = reflectionAlpha;
        [self setNeedsLayout];
    }
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    if (![_shadowColor isEqual:shadowColor])
    {
        
#if !__has_feature(objc_arc)
        
        [_shadowColor release];
        _shadowColor = [shadowColor retain];
        
#else
        
        _shadowColor = shadowColor;
        
#endif
        
        [self setNeedsLayout];
    }
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
    if (!CGSizeEqualToSize(_shadowOffset, shadowOffset))
    {
        _shadowOffset = shadowOffset;
        [self setNeedsLayout];
    }
}

- (void)setShadowBlur:(CGFloat)shadowBlur
{
    if (_shadowBlur != shadowBlur)
    {
        _shadowBlur = shadowBlur;
        [self setNeedsLayout];
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (self.contentMode != contentMode)
    {
        super.contentMode = contentMode;
        [self setNeedsLayout];
    }
}

- (void)setCustomEffectsBlock:(UIImage *(^)(UIImage *))customEffectsBlock
{
    if (![customEffectsBlock isEqual:_customEffectsBlock])
    {
        _customEffectsBlock = [customEffectsBlock copy];
        [self setNeedsLayout];
    }
}

- (void)setCacheKey:(NSString *)cacheKey
{
    if (![cacheKey isEqual:_cacheKey])
    {
        _cacheKey = [cacheKey copy];
        [self setNeedsLayout];
    }
}


#pragma mark -
#pragma mark loading

- (void)setImageWithContentsOfFile:(NSString *)file
{
    if ([[file pathExtension] length] == 0)
    {
        file = [file stringByAppendingPathExtension:@"png"];
    }
    if (![file isAbsolutePath])
    {
        file = [[NSBundle mainBundle] pathForResource:file ofType:nil];
    }
    if ([UIScreen mainScreen].scale == 2.0f)
    {
        NSString *temp = [[[file stringByDeletingPathExtension] stringByAppendingString:@"@2x"] stringByAppendingPathExtension:[file pathExtension]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:temp])
        {
            file = temp;
        }
    }
    [self setImageWithContentsOfURL:[NSURL fileURLWithPath:file]];
}

- (void)setImageWithContentsOfURL:(NSURL *)URL
{
    if (![URL isEqual:_imageContentURL])
    {
        //update processed image
        [self willChangeValueForKey:@"image"];
        self.originalImage = nil;
        [self didChangeValueForKey:@"image"];
        self.imageContentURL = URL;
        [self updateProcessedImage];
    }
}

@end
