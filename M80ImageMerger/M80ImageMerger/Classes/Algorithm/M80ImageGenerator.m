//
//  M80ImageGenerator.m
//  M80Image
//
//  Created by amao on 11/18/15.
//  Copyright © 2015 Netease. All rights reserved.
//

#import "M80ImageGenerator.h"
#import "M80ImageMergeInfo.h"
#import "UIImage+M80.h"
#import "M80Constraint.h"

@interface M80ImageGenerator ()
@property (nonatomic,strong)    UIImage *firstImage;
@end

@implementation M80ImageGenerator
- (instancetype)init
{
    if (self = [super init])
    {
        _infos = @[].mutableCopy;
    }
    return self;
}

- (BOOL)feedImages:(NSArray *)images
{
    for (UIImage *image in images)
    {
        @autoreleasepool
        {
            if (![self feedImage:image])
            {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)feedImage:(UIImage *)image
{
    if (_error)
    {
        return NO;
    }
    
    BOOL success = NO;
    if (image)
    {
        if (_firstImage == nil)
        {
            _firstImage = image;
            success = YES;
        }
        else
        {
            success = [self doFeedImage:image];
        }
    }
    return success;
}


- (BOOL)doFeedImage:(UIImage *)image
{
    UIImage *baseImage = [self baseImage];
    BOOL doFeed = image.size.width == baseImage.size.width &&
                  image.scale == baseImage.scale;
    if (doFeed)
    {
        M80ImageMergeInfo *info = [M80ImageMergeInfo new];
        info.firstImage         = baseImage;
        info.secondImage        = image;
        info.type               = M80FingerprintTypeCRC;
        [info calc];
        
        BOOL success =[M80Constraint isInfoValid:info];
        
//        if (!success)
//        {
//            //CRC 这种较严格匹配失败的话，尝试下比较宽松的匹配 （容易出现误匹配
//            info.type = M80FingerprintTypeHistogram;
//            [info calc];
//
//            success = [M80Constraint isInfoValid:info];
//        }
        
        if (!success)
        {
            _error = [NSError errorWithDomain:M80ERRORDOMAIN
                                         code:M80MergeErrorNotEnoughOverlap
                                     userInfo:nil];
            doFeed = NO;
        }
        else
        {
            [_infos addObject:info];
        }
    }
    return doFeed;
}


- (UIImage *)generate
{
    if (_error || [_infos count] == 0)
    {
        return nil;
    }
    
#if DEBUG
    
    {
        NSString *path = NSTemporaryDirectory();
        NSString *prefix = [NSString stringWithFormat:@"%@",[NSDate date]];
        NSLog(@"view images at %@ with prefix %@",path,prefix);
        for (NSInteger i = 0; i < [_infos count]; i++)
        {
            M80ImageMergeInfo *info = [_infos objectAtIndex:i];
            UIImage *firstImage = [info.firstImage m80_rangedImage:NSMakeRange(info.firstOffset, info.length)];
            NSString *firstImagePath = [NSString stringWithFormat:@"%@/%@_%zd_first.png",path,prefix,i];
            [firstImage m80_saveAsPngFile:firstImagePath];
            
            
            UIImage *secondImage = [info.secondImage m80_rangedImage:NSMakeRange(info.secondOffset, info.length)];
            NSString *secondImagePath = [NSString stringWithFormat:@"%@/%@_%zd_second.png",path,prefix,i];
            [secondImage m80_saveAsPngFile:secondImagePath];
        }
    }

    
    
#endif
    
    M80ImageMergeInfo *drawInfo = [_infos firstObject];
    [_infos removeObjectAtIndex:0];
    
    UIImage *result = nil;
    while (drawInfo)
    {
        @autoreleasepool
        {
            UIImage *firstImage = drawInfo.firstImage;
            UIImage *secondImage= drawInfo.secondImage;
            NSRange firstRange = NSMakeRange(firstImage.size.height - drawInfo.firstOffset, drawInfo.length);
            NSRange secondRange= NSMakeRange(secondImage.size.height - drawInfo.secondOffset, drawInfo.length);
            
            CGSize size = CGSizeMake(drawInfo.firstImage.size.width, firstRange.location + secondImage.size.height - secondRange.location);
            CGFloat scale = drawInfo.firstImage.scale;
            
            UIGraphicsBeginImageContextWithOptions(size, NO, scale);
            [firstImage drawInRect:CGRectMake(0, 0, firstImage.size.width, firstImage.size.height)];
            UIImage *subSecondImage = [secondImage m80_subImage:CGRectMake(0, secondRange.location+drawInfo.length/2.0, secondImage.size.width, secondImage.size.height - secondRange.location-drawInfo.length/2.0)];
            [subSecondImage drawInRect:CGRectMake(0, firstRange.location+drawInfo.length/2.0, size.width, subSecondImage.size.height)];
            result = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            drawInfo = nil;
            
            if ([_infos count])
            {
                M80ImageMergeInfo *info = [_infos firstObject];
                [_infos removeObjectAtIndex:0];
                info.firstImage = result;
                drawInfo = info;
            }

        }
    }
    return result;
}




- (UIImage *)baseImage
{
    UIImage *image  = nil;
    M80ImageMergeInfo *info = [_infos lastObject];
    if (info)
    {
        image = info.secondImage;
    }
    else
    {
        image = _firstImage;
    }
    return image;
}
@end
