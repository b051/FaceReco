//
//  FRAssetsGroupViewController.m
//  FaceReco
//
//  Created by Rex Sheng on 2/18/13.
//  Copyright (c) 2013 lognllc.com. All rights reserved.
//

#import "FRAssetsGroupViewController.h"
#import "FRAssetsGroupCell.h"
#import "FRAssetsViewController.h"

@interface FRAssetsGroupViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) UICollectionView *gridView;

@end

@implementation FRAssetsGroupViewController
{
	NSMutableArray *groups;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	_assetsLibrary = [[ALAssetsLibrary alloc] init];
	UICollectionViewFlowLayout *gridViewLayout = [[UICollectionViewFlowLayout alloc] init];
    [gridViewLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [gridViewLayout setItemSize:CGSizeMake(112.f, 98.f)];
    [gridViewLayout setMinimumInteritemSpacing:10.f];
    [gridViewLayout setMinimumLineSpacing:10.f];
    [gridViewLayout setSectionInset:UIEdgeInsetsMake(0.0f, 20.0f, 0.0f, 20.0f)];
    
	_gridView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:gridViewLayout];
    _gridView.backgroundColor = [UIColor clearColor];
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _gridView.dataSource = self;
    _gridView.delegate = self;
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_gridView registerClass:[FRAssetsGroupCell class] forCellWithReuseIdentifier:@"group"];
    [self.view addSubview:_gridView];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.navigationController setNavigationBarHidden:YES animated:animated];
	if (!groups) {
        groups = [[NSMutableArray alloc] init];
    } else {
        [groups removeAllObjects];
    }
	[_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
		if (group) {
            [groups addObject:group];
        } else {
            [_gridView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
        }
	} failureBlock:nil];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
	return YES;
}

#pragma mark - UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return groups.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	FRAssetsGroupCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"group" forIndexPath:indexPath];
	ALAssetsGroup *groupForCell = groups[indexPath.row];
	CGImageRef posterImageRef = [groupForCell posterImage];
    UIImage *posterImage = [UIImage imageWithCGImage:posterImageRef];
    cell.imageView.image = posterImage;
    cell.textLabel.text = [groupForCell valueForProperty:ALAssetsGroupPropertyName];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	FRAssetsViewController *assetsViewController = [[FRAssetsViewController alloc] init];
	assetsViewController.assetsGroup = groups[indexPath.row];
	[self.navigationController pushViewController:assetsViewController animated:YES];
}

@end
