//
//  CBPeripheralViewController.m
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBPeripheralViewController.h"

@interface CBPeripheralViewController ()

@property(nonatomic, strong) CBPeripheralViewModel *viewModel;
@end

@implementation CBPeripheralViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];

    self.viewModel = [[CBPeripheralViewModel alloc] initWithDelegate:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self _startListeningForNotifications];

    [self.viewModel stopAdvertising];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self _stopListeningForNotifications];

    [self.viewModel stopAdvertising];
}

#pragma mark - Notifications

- (void)_startListeningForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_onViewModelLogOutput:)
                                                 name:kNotification_CBPeripheralViewModelDelegate_LogOutput
                                               object:self.viewModel];
}

- (void)_stopListeningForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNotification_CBPeripheralViewModelDelegate_LogOutput
                                                  object:self.viewModel];
}

- (void)_onViewModelLogOutput:(NSNotification*)notification
{
    NSString *text = [notification.userInfo objectForKey:@"logOutput"];
    if (text)
    {
        NSString *newText = [NSString stringWithFormat:@"%@\n",text];
        self.logTextView.text = [self.logTextView.text stringByAppendingString:newText];
    }
}

#pragma mark - Control actions

- (IBAction)backgroundButtonPressed:(id)sender
{
    [self.communicationTextView resignFirstResponder];
}

#pragma mark - CBPeripheralViewModelDelegate methods

- (NSData*)viewModelWantsCurrentDataToSend
{
    return [self.logTextView.text dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - UITextViewDelegate methods

- (void)textViewDidChange:(UITextView *)textView
{
    [self.viewModel updateDataToSend:[self.logTextView.text dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
