//
//  CBPeripheralManagerViewController.h
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBPeripheralManagerViewController : UIViewController<CBPeripheralManagerDelegate, UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UITextView *communicationTextView;
@property (strong, nonatomic) IBOutlet UITextView *logTextView;
@property (strong, nonatomic) IBOutlet UIButton *backgroundButton;

@end
