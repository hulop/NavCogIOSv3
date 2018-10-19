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

#import "DownloadViewController.h"
#import "ServerConfig.h"

@interface DownloadViewController ()

@end

@implementation DownloadViewController {
    double progress;
    
    NSArray *downloadingFiles;
    long totalLength;
    long downloadedLength;
    NSURLSession *session;
    NSOperationQueue *downloadQueue;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.statusLabel.text = NSLocalizedString(@"DOWNLOADING_DATA", @"");
    self.progressBar.progress = 0;
    self.progressLabel.text = @"0%";
    
    downloadingFiles = [[ServerConfig sharedConfig] checkDownloadFiles];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self downloadFiles:downloadingFiles];
}


- (void) downloadFiles:(NSArray*)files
{
    totalLength = 0;
    [files enumerateObjectsUsingBlock:^(NSDictionary*  obj, NSUInteger idx, BOOL * _Nonnull stop) {
        totalLength += [obj[@"length"] doubleValue];
    }];
    downloadingFiles = files;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];

    downloadQueue = [[NSOperationQueue alloc] init];
    
    downloadedLength = 0;
    session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:downloadQueue];
    [self downloadNext];
}


/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    NSError *error = nil;
    
    NSURL *destLocation = [[ServerConfig sharedConfig] getDestLocation:downloadTask.originalRequest.URL.path];
    [[NSFileManager defaultManager] removeItemAtURL:destLocation error:nil];
    NSLog(@"moving %@ to %@", location.path, destLocation.path);
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destLocation error:&error];
    if (error) {
        NSLog(@"error=%@", error);
    }
    
    downloadingFiles = [downloadingFiles subarrayWithRange:NSMakeRange(1, [downloadingFiles count]-1)];
    [self downloadNext];
}

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    downloadedLength += bytesWritten;
    [self updateProgress];
}

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    
}

- (void) downloadNext
{
    if ([downloadingFiles count] == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"unwind_download" sender:self];
        });
        return;
    }
    
    NSDictionary *file = [downloadingFiles firstObject];
    NSURL *url = [NSURL URLWithString:file[@"url"]];

    NSLog(@"start download %@", url);
    NSURLSessionDownloadTask * task = [session downloadTaskWithURL:url];
    [task resume];
}

- (void)updateProgress
{
    NSLog(@"downloadedLength=%ld", downloadedLength);
    progress = (double)downloadedLength / totalLength;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressBar.progress = progress;
        self.progressLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(progress*100)];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
