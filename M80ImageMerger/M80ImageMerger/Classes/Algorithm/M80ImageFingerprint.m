//
//  M80ImageFingerprint.m
//  M80Image
//
//  Created by amao on 11/18/15.
//  Copyright © 2015 Netease. All rights reserved.
//

#import "M80ImageFingerprint.h"
#import <zlib.h>
#import "UIImage+M80.h"
#import "M80Constraint.h"
#import <CommonCrypto/CommonDigest.h>


@interface M80ImageFingerprint ()
@property (nonatomic,assign)    M80FingerprintType  type;
@end



@implementation M80ImageFingerprint
+ (instancetype)fingerprint:(UIImage *)image
                       type:(M80FingerprintType)type;
{
    M80ImageFingerprint *instance = [[M80ImageFingerprint alloc] init];
    instance.type = type;
    [instance calc:image];
    return instance;
}

- (void)calc:(UIImage *)image
{
    UIImage *source = [M80Constraint shouldUseGradientImage:_type] ? [image m80_gradientImage] : image;
//    UIImage *source = image;
    if (_type == M80FingerprintTypeCRC)
    {
        [self calcCRCImage:source];
    }
//    else if(_type == M80FingerprintTypeHistogram)
//    {
//        [self calcHistImage:source];
//    }
}

- (void)calcCRCImage:(UIImage *)image
{
    NSMutableArray *array = [NSMutableArray array];
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    const UInt8* data = CFDataGetBytePtr(pixelData);
    NSInteger height = image.size.height;
    NSInteger width = image.size.width;
    
    for (NSInteger y = 0; y < height; y++)
    {
        NSData *cacheData = [NSData dataWithBytes:data + y * width * 4
                                           length:width * 4];
        unsigned char result[CC_MD5_DIGEST_LENGTH];
        CC_MD5([cacheData bytes], (uInt)[cacheData length], result);
        NSString *imageHash = [NSString stringWithFormat:
                               @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                               result[0], result[1], result[2], result[3],
                               result[4], result[5], result[6], result[7],
                               result[8], result[9], result[10], result[11],
                               result[12], result[13], result[14], result[15]];
        [array addObject:imageHash];
//        if (@available(iOS 11.0, *)) {
//            uLong print = crc32_z(0, [cacheData bytes], (uInt)[cacheData length]);
//            [array addObject:@(print)];
//        } else {
//            // Fallback on earlier versions
//            uLong print = crc32(0, [cacheData bytes], (uInt)[cacheData length]);
//            [array addObject:@(print)];
//        }
    }
    _lines = array;
    CFRelease(pixelData);
}

- (void)calcHistImage:(UIImage *)image
{
    NSMutableArray *array = [NSMutableArray array];
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    const UInt8* data = CFDataGetBytePtr(pixelData);
    NSInteger height = image.size.height;
    NSInteger width = image.size.width;
    
    for (NSInteger y = 0; y < height; y++)
    {
        NSMutableDictionary *map = [[NSMutableDictionary alloc] init];
        for (NSInteger x = 0; x < width; x++)
        {
            const UInt8 *pixel = &(data[y * width * 4 + x * 4]);
            int32_t gray = 0.3 * pixel[3] + 0.59 * pixel[2] + 0.11 * pixel[1];
            
            if (map[@(gray)] == nil)
            {
                map[@(gray)] = @(1);
            }
            else
            {
                map[@(gray)] = @([map[@(gray)] integerValue] + 1);
            }
        }
        NSMutableArray *numbers = [NSMutableArray array];
        for (NSNumber *key in map.allKeys)
        {
            NSValue *value = [NSValue valueWithRange:NSMakeRange([key integerValue], [map[key] integerValue])];
            [numbers addObject:value];
        }
        
        [numbers sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger first = [obj1 rangeValue].length;
            NSInteger second = [obj2 rangeValue].length;
            return  first < second ? NSOrderedAscending : NSOrderedDescending;
        }];
        
        //取得特殊的点作为当前行的特征值
        NSInteger print = 255;
        NSInteger count = [numbers count] * 0.5;
        
        for (NSInteger i = 0; i < count; i++)
        {
            NSInteger value = [numbers[i] rangeValue].location;
            if (print > value)
            {
                print = value;
            }
        }
        [array addObject:@(print)];
    }
    _lines = array;
    CFRelease(pixelData);
}
@end
