//
//  CBCentralViewController.h
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBCentralViewModel.h"

@interface CBCentralViewController : UIViewController <CBManagerViewModelDelegate>

@property (strong, nonatomic) IBOutlet UITextView *communicationTextView;
@property (strong, nonatomic) IBOutlet UITextView *logTextView;

@end
