//
//  CBPeripheralViewController.h
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "CBPeripheralViewModel.h"

@interface CBPeripheralViewController : UIViewController<CBPeripheralViewModelDelegate,UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UITextView *communicationTextView;
@property (strong, nonatomic) IBOutlet UITextView *logTextView;
@property (strong, nonatomic) IBOutlet UIButton *backgroundButton;

@end
