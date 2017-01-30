//
//  ServerSelectionViewController.m
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

@interface ServerSelectionViewController ()

@end

@implementation ServerSelectionViewController {
    NSDictionary *servers;
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
    NSDictionary *server = [self serverAtIndexPath:indexPath];
    
    if ([server[@"available"] boolValue]) {
        [ServerConfig sharedConfig].selected = server;
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
    if (!servers[@"servers"]) {
        return 0;
    }
    if (![servers[@"servers"] isKindOfClass:NSArray.class]) {
        return 0;
    }
    return [servers[@"servers"] count];
}

- (NSDictionary*) serverAtIndexPath:(NSIndexPath*)indexPath
{
    if (!servers) {
        return nil;
    }
    if (!servers[@"servers"]) {
        return nil;
    }
    if (![servers[@"servers"] isKindOfClass:NSArray.class]) {
        return nil;
    }
    NSArray *array = servers[@"servers"];
    if (0 <= indexPath.row && indexPath.row < [array count]) {
        return array[indexPath.row];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server_candidate_cell" forIndexPath:indexPath];
    
    NSDictionary *server = [self serverAtIndexPath:indexPath];
    
    if (server) {
        NSString *userLanguage = [[[NSLocale preferredLanguages] objectAtIndex:0] substringToIndex:2];

        BOOL available = [server[@"available"] boolValue];
        
        if (available) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.textLabel.textColor = [UIColor blackColor];
            cell.detailTextLabel.textColor = [UIColor blackColor];
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor grayColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
        }
        
        cell.textLabel.text = server[@"name"][userLanguage];
        cell.detailTextLabel.text = server[@"description"][userLanguage];
    }
    
    return cell;
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
