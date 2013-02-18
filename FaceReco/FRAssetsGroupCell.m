//
//  FRAssetsGroupCell.m
//  FaceReco
//
//  Created by Rex Sheng on 2/18/13.
//  Copyright (c) 2013 lognllc.com. All rights reserved.
//

#import "FRAssetsGroupCell.h"

@implementation FRAssetsGroupCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(25, 15, 65, 65)];
		_imageView = imageView;
		[self addSubview:_imageView];
		[self addSubview:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"album_black-iphone"]]];
		UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 72, 88, 30)];
		_textLabel = textLabel;
		_textLabel.font = [UIFont fontWithName:@"AvenirNext-Italic" size:10];
		_textLabel.backgroundColor = [UIColor clearColor];
		_textLabel.textColor = [UIColor whiteColor];
		_textLabel.shadowColor = [UIColor grayColor];
		textLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_textLabel];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
