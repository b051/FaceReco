//
//  FRAssetsViewController.m
//  FaceReco
//
//  Created by Rex Sheng on 2/18/13.
//  Copyright (c) 2013 lognllc.com. All rights reserved.
//

#import "FRAssetsViewController.h"
#import "iCarousel.h"
#import "FXImageView.h"

@interface FRAssetsViewController () <iCarouselDataSource, iCarouselDelegate>

@property (nonatomic, weak) iCarousel *carousel;
@end

@implementation FRAssetsViewController
{
	NSMutableArray *assets;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	iCarousel *carousel = [[iCarousel alloc] initWithFrame:self.view.bounds];
	_carousel = carousel;
	_carousel.delegate = self;
	_carousel.dataSource = self;
	_carousel.type = iCarouselTypeCoverFlow2;
	[self.view addSubview:_carousel];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    if (!assets) {
        assets = [[NSMutableArray alloc] init];
    } else {
        [assets removeAllObjects];
    }
    
	[_assetsGroup setAssetsFilter:[ALAssetsFilter allPhotos]];
	[_assetsGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
        if (result) {
            [assets addObject:result];
        }
    }];
	[_carousel reloadData];
	[_carousel scrollToOffset:1 duration:0.5];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
	return NO;
}

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    return assets.count;
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView *)view
{
    //create new view if no view is available for recycling
    if (view == nil) {
        FXImageView *imageView = [[FXImageView alloc] initWithFrame:CGRectMake(0, 0, 200.0f, 400.0f)];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.asynchronous = YES;
        imageView.reflectionScale = 0.5f;
        imageView.reflectionAlpha = 0.25f;
        imageView.reflectionGap = 10.0f;
        imageView.shadowOffset = CGSizeMake(0.0f, 2.0f);
        imageView.shadowBlur = 5.0f;
        imageView.cornerRadius = 10.0f;
        view = imageView;
    }
	
	ALAsset *asset = assets[index];
	ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
    
    UIImage *fullScreenImage = [UIImage imageWithCGImage:[assetRepresentation fullScreenImage] scale:[assetRepresentation scale] orientation:UIImageOrientationUp];
//	CGImageRef thumbnailImageRef = [asset thumbnail];
//	UIImage *thumbnail = [UIImage imageWithCGImage:thumbnailImageRef];
	
    //set image
    ((FXImageView *)view).image = fullScreenImage;
    
    return view;
}

@end
