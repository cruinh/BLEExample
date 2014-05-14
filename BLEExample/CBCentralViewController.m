//
//  CBCentralViewController.m
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBCentralViewController.h"
#import "CBCentralViewModel.h"

@interface CBCentralViewController ()

@property(strong, nonatomic) CBCentralViewModel *viewModel;

@end

@implementation CBCentralViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];

    self.viewModel = [[CBCentralViewModel alloc] initWithDelegate:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self _startListeningForNotifications];

    [self.viewModel startScanning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self _stopListeningForNotifications];

    [self.viewModel stopScanning];
}

#pragma mark - CBCentralViewModelDelegateMethods

- (void)viewModelReceivedData:(NSData*)data
{
    [self.communicationTextView setText:[[NSString alloc] initWithData:data
                                                              encoding:NSUTF8StringEncoding]];
}

#pragma mark - Notifications

- (void)_startListeningForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_onViewModelLogOutput:)
                                                 name:kNotification_CBManagerViewModelDelegate_LogOutput
                                               object:self.viewModel];
}

- (void)_stopListeningForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNotification_CBManagerViewModelDelegate_LogOutput
                                                  object:self.viewModel];
}

- (void)_onViewModelLogOutput:(NSString*)text
{
    NSLog(@"%@",text);
    self.logTextView.text = [self.logTextView.text stringByAppendingString:[NSString stringWithFormat:@"%@\n",text]];
}
@end
