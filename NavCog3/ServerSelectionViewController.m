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

#import "ServerSelectionViewController.h"
#import "ServerConfig.h"
#import "AuthManager.h"
#import "NavDataStore.h"

@interface ServerSelectionViewController ()

@end

@implementation ServerSelectionViewController {
    ServerList *servers;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    self.navigationItem.leftBarButtonItem = nil;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    servers = [ServerConfig sharedConfig].serverList;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    //self.navigationItem.leftBarButtonItem = nil;
    //[self.navigationItem setHidesBackButton:YES animated:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ServerEntry *server = [self serverAtIndexPath:indexPath];
    
    if (server.available ||
        [[AuthManager sharedManager] isDeveloperAuthorized]) {
        
        if (server.minimumAppVersion) {
            NSString *versionNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            
            if ([server.minimumAppVersion compare:versionNo options:NSNumericSearch] == NSOrderedDescending) {
                NSString *title = NSLocalizedString(@"NeedToUpdateAppTitle", @"");
                NSString *message = NSLocalizedString(@"NeedToUpdateAppMessage", @"");
                NSString *ok = NSLocalizedString(@"OpenAppStore", @"");
                NSString *cancel = NSLocalizedString(@"CANCEL", @"");
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:ok
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                              NSURL *appURL = [NSURL URLWithString:@"https://itunes.apple.com/jp/app/navcog/id1042163426?mt=8"];
                                                              [[UIApplication sharedApplication] openURL:appURL options:@{} completionHandler:^(BOOL success) {
                                                              }];
                                                          }]];
                [alert addAction:[UIAlertAction actionWithTitle:cancel
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                          }]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:alert animated:YES completion:nil];
                });
                return;
            }
        }
        [ServerConfig sharedConfig].selected = server;
        [[NavDataStore sharedDataStore] selectUserLanguage:server.userLanguage];

        [self performSegueWithIdentifier:@"unwind_server_selection" sender:self];
    }
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    
    if (!servers) {
        return 0;
    }
    return [servers count];
}

- (ServerEntry*) serverAtIndexPath:(NSIndexPath*)indexPath
{
    if (!servers) {
        return nil;
    }

    if (0 <= indexPath.row && indexPath.row < [servers count]) {
        return servers[indexPath.row];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server_candidate_cell" forIndexPath:indexPath];
    
    ServerEntry *server = [self serverAtIndexPath:indexPath];
    
    if (server) {
        //NSString *userLanguage = [[[NSLocale preferredLanguages] objectAtIndex:0] substringToIndex:2]; // use first two characters.
        
        // Enumerate user language candidates by using first preferred language
        NSArray* userLanguageCandidates = [[NavDataStore sharedDataStore] userLanguageCandidates];
        
        for(NSString *userLanguage in userLanguageCandidates) {
            
            if (server.available ||
                [[AuthManager sharedManager] isDeveloperAuthorized]) {
                //cell.accessoryType = UITableViewCellAccessoryCheckmark;
                cell.textLabel.textColor = nil;
                cell.detailTextLabel.textColor = nil;
            } else {
                //cell.accessoryType = UITableViewCellAccessoryNone;
                cell.textLabel.textColor = [UIColor grayColor];
                cell.detailTextLabel.textColor = [UIColor grayColor];
            }
            NSString *name = [server.name stringByLanguage:userLanguage];
            NSString *description = [server.serverDescription stringByLanguage:userLanguage];
            
            if(name){
                cell.textLabel.text = name;
                cell.detailTextLabel.text = description;
                server.userLanguage = userLanguage;
                break;
            }
        }
    }
    
    return cell;
}

- (IBAction)refreshServerlist:(id)sender {
    [ServerConfig sharedConfig].serverList = nil;
    [ServerConfig sharedConfig].selected = nil;
    [self performSegueWithIdentifier:@"unwind_server_selection" sender:self];
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
