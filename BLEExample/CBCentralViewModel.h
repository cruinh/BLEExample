//
// Created by cruinh on 5/14/14.
// Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#define kNotification_CBManagerViewModelDelegate_LogOutput @"kNotification_CBManagerViewModelDelegate_LogOutput"

@protocol CBManagerViewModelDelegate
- (void)viewModelReceivedData:(NSData*)data;
@end

@interface CBCentralViewModel : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, weak) id<CBManagerViewModelDelegate> delegate;

- (id)initWithDelegate:(id<CBManagerViewModelDelegate>)delegate;

- (void)startScanning;
- (void)stopScanning;

@end