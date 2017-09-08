/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import "ScreenshotHelper.h"

#define MAX_SCS 600

@implementation ScreenshotHelper {
    NSTimer *timer;
    NSOperationQueue *queue;
    NSMutableArray *images;
}

static ScreenshotHelper *instance;

+ (instancetype) sharedHelper
{
    if (!instance) {
        instance = [[ScreenshotHelper alloc] initPrivate];
    }
    return instance;
}

- (instancetype) initPrivate
{
    self = [super init];
    queue = [[NSOperationQueue alloc] init];
    return self;
}

- (NSArray *)screenshotsFromLog:(NSString *)logPath
{
    NSError *error;
    
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *scsPath = [docPath stringByAppendingPathComponent:@"screenshots"];
    NSArray *logs = [[NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:&error] componentsSeparatedByString:@"\n"];
    
    NSMutableArray *temp = [@[] mutableCopy];
    for(NSString *line in logs) {
        NSRange range = [line rangeOfString:@"screenshot,"];
        if (range.location != NSNotFound) {
            NSString *name = [line componentsSeparatedByString:@","][1];
            if ([images containsObject:name]) {
                [temp addObject:[scsPath stringByAppendingPathComponent:name]];
            }
        }
    }

    return temp;
}

- (void)startRecording
{
    if (!timer) {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *scsPath = [docPath stringByAppendingPathComponent:@"screenshots"];

        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:scsPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error])
        {
            NSLog(@"Create directory error: %@", error);
        }
        NSFileManager *fm = [NSFileManager defaultManager];
        images = [[fm contentsOfDirectoryAtPath:scsPath error:nil] mutableCopy];
        [images filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF like '*png'"]];
        [images sortUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2 options:0];
        }];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                UIImage *image = [self screenshotImage];
            
                [queue addOperationWithBlock:^{
                    
                    static NSDateFormatter *formatter;
                    if (!formatter) {
                        formatter = [[NSDateFormatter alloc] init];
                        [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss'.png'"];
                        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
                    }
                    NSString *fileName = [formatter stringFromDate:[NSDate date]];
                    NSString *filePath = [scsPath stringByAppendingPathComponent:fileName];
                    
                    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:NO];
                    NSLog(@"screenshot,%@,%ld",fileName,(long)([NSDate date].timeIntervalSince1970*1000));
                    NSLog(@"%@",filePath);
                    
                    @synchronized (images) {
                        [images addObject:fileName];
                    }
                    [self checkLimit];
                }];
            });
        }];
    }
}

- (void)checkLimit
{
    @synchronized (images) {
        while(images.count > MAX_SCS) {
            NSString *name = images.firstObject;
            NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
            NSString *scsPath = [docPath stringByAppendingPathComponent:@"screenshots"];
            
            NSString *path = [scsPath stringByAppendingPathComponent:name];
            NSFileManager *fm = [NSFileManager defaultManager];

            NSError *error;
            [fm removeItemAtPath:path error:&error];
            if (!error ) {
                [images removeObjectAtIndex:0];
            } else {
                NSLog(@"error removing file %@, (%@)", path, error);
            }
        }
    }
}

- (UIImage*)screenshotImage
{
    CGFloat scale = 1.0;
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    screenSize.width = screenSize.width * scale;
    screenSize.height = screenSize.height * scale;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(nil, screenSize.width, screenSize.height, 8, 4*(int)screenSize.width, colorSpaceRef, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0.0, screenSize.height);
    CGContextScaleCTM(ctx, scale, -scale);
    
    for (UIView *view in [UIApplication sharedApplication].keyWindow.subviews) {
        [(CALayer*)view.layer renderInContext:ctx];
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(ctx);
    return image;
}

- (void)stopRecording
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}
@end
