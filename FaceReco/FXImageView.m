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
@property (nonatomic, strong) UIView *facesView;
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
	_facesView = [[UIView alloc] initWithFrame:self.bounds];
	[self addSubview:_facesView];
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
		[self markFaces];
        [self didChangeValueForKey:@"processedImage"];
    }
}

- (void)markFaces
{
	for (UIView *view in _facesView.subviews) {
		[view removeFromSuperview];
	}
	CGImageRef CGImage = _imageView.image.CGImage;
    // draw a CI image with the previously loaded face detection picture
    CIImage* image = [CIImage imageWithCGImage:CGImage];
    
	NSLog(@"frame:%@ image:@%@", NSStringFromCGRect(_imageView.frame), NSStringFromCGSize(_imageView.image.size));
    // create a face detector - since speed is not an issue we'll use a high accuracy
    // detector
	CGFloat dh = _imageView.bounds.size.height - _imageView.image.size.height;
	CGFloat dw = _imageView.bounds.size.width - _imageView.image.size.width;
	
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
    
    // create an array containing all the detected faces from the detector
    NSArray* features = [detector featuresInImage:image];
    
    // we'll iterate through every detected face.  CIFaceFeature provides us
    // with the width for the entire face, and the coordinates of each eye
    // and the mouth if detected.  Also provided are BOOL's for the eye's and
    // mouth so we can check if they already exist.
	
	CGPoint(^fpoint)(CGPoint) = ^(CGPoint p) {
		return CGPointMake((p.x + dw) / 2, (p.y + dh) / 2);
	};
	
	CGSize(^fsize)(CGSize) = ^(CGSize s) {
		return CGSizeMake(s.width / 2, s.height / 2);
	};
	CGRect(^frect)(CGRect) = ^(CGRect r) {
		r.origin = fpoint(r.origin);
		r.size = fsize(r.size);
		return r;
	};
	
    for(CIFaceFeature *faceFeature in features)
    {
        // get the width of the face
        
        // create a UIView using the bounds of the face
		CGRect faceBounds = frect(faceFeature.bounds);
		CGFloat faceWidth = faceBounds.size.width;
        UIView *faceView = [[UIView alloc] initWithFrame:faceBounds];
        // add a border around the newly created UIView
        faceView.layer.borderWidth = 1;
        faceView.layer.borderColor = [[UIColor redColor] CGColor];
        
        // add the new view to create a box around the face
        [_facesView addSubview:faceView];
        
        if(faceFeature.hasLeftEyePosition)
        {
            // create a UIView with a size based on the width of the face
			//			CGRect bounds = CGRectMake(faceFeature.leftEyePosition.x/2 -faceWidth*0.15, faceFeature.leftEyePosition.y/2-faceWidth*.15, faceWidth*.3, faceWidth*0.3);
			CGRect bounds = (CGRect) {.origin=fpoint(faceFeature.leftEyePosition), .size=CGSizeZero};
			CGFloat radius = faceWidth * .15;
			bounds = CGRectInset(bounds, -radius, -radius);
            UIView *leftEyeView = [[UIView alloc] initWithFrame:bounds];
            // change the background color of the eye view
            [leftEyeView setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            // round the corners
            leftEyeView.layer.cornerRadius = radius;
            // add the view to the window
            [_facesView addSubview:leftEyeView];
        }
        
        if(faceFeature.hasRightEyePosition)
        {
            // create a UIView with a size based on the width of the face
			//			CGRect bounds = CGRectMake(faceFeature.rightEyePosition.x/2 -faceWidth*.15, faceFeature.rightEyePosition.y/2-faceWidth*.15, faceWidth*.3, faceWidth*.3);
			CGRect bounds = (CGRect) {.origin=fpoint(faceFeature.rightEyePosition), .size=CGSizeZero};
			CGFloat radius = faceWidth * .15;
			bounds = CGRectInset(bounds, -radius, -radius);
			
            UIView* leftEye = [[UIView alloc] initWithFrame:bounds];
            // change the background color of the eye view
            [leftEye setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            // round the corners
            leftEye.layer.cornerRadius = radius;
            // add the new view to the window
            [_facesView addSubview:leftEye];
        }
        
        if(faceFeature.hasMouthPosition)
        {
            // create a UIView with a size based on the width of the face
			//			CGRect bounds = CGRectMake(faceFeature.mouthPosition.x/2 -faceWidth*.2, faceFeature.mouthPosition.y/2-faceWidth*.2, faceWidth*.4, faceWidth*.4);
			
			CGRect bounds = (CGRect) {.origin=fpoint(faceFeature.mouthPosition), .size=CGSizeZero};
			CGFloat radius = faceWidth * .2;
			bounds = CGRectInset(bounds, -radius, -radius);
			
            UIView* mouth = [[UIView alloc] initWithFrame:bounds];
            // change the background color for the mouth to green
            [mouth setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.3]];
            // round the corners
            mouth.layer.cornerRadius = radius;
            // add the new view to the window
            [_facesView addSubview:mouth];
        }
		if (faceFeature.hasMouthPosition && faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition) {
			CGPoint a = faceFeature.leftEyePosition;
			CGPoint b = faceFeature.rightEyePosition;
			CGPoint c = faceFeature.mouthPosition;
			CGFloat ab = pow(b.x - a.x, 2) + pow(b.y - a.y, 2);
			CGFloat ac = pow(c.x - a.x, 2) + pow(c.y - a.y, 2);
			CGFloat bc = pow(c.x - b.x, 2) + pow(c.y - b.y, 2);
			CGFloat angleC = acos((ac + bc - ab)/(2 * sqrt(ac * bc))) / M_PI * 180;
			CGFloat angleB = acos((ab + bc - ac)/(2 * sqrt(ab * bc))) / M_PI * 180;
			CGRect frame = faceView.frame;
			frame.size.width = 200;
			frame.size.height = 50;
			UILabel *label = [[UILabel alloc] initWithFrame:frame];
			[_facesView addSubview:label];

			label.backgroundColor = [UIColor clearColor];
			label.text = [NSString stringWithFormat:@"mouth:%.2f\neye(r):%.2f", angleC, angleB];
			label.numberOfLines = 2;
			label.font = [UIFont fontWithName:@"Futura-CondensedMedium" size:11];
			label.shadowColor = [UIColor darkGrayColor];
			label.textColor = [UIColor whiteColor];
			label.transform = CGAffineTransformMakeScale(1, -1);
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
		[self markFaces];
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
