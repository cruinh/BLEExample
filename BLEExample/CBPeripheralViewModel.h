//
// Created by cruinh on 5/14/14.
// Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#define kNotification_CBPeripheralViewModelDelegate_LogOutput @"kNotification_CBPeripheralViewModelDelegate_LogOutput"

@protocol CBPeripheralViewModelDelegate
- (NSData*)viewModelWantsCurrentDataToSend;
@end

@interface CBPeripheralViewModel : NSObject<CBPeripheralManagerDelegate>

@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property(nonatomic, weak) NSObject<CBPeripheralViewModelDelegate> *delegate;

- (id)initWithDelegate:(NSObject<CBPeripheralViewModelDelegate>*)delegate;

- (void)startAdvertising;
- (void)stopAdvertising;

- (void)updateDataToSend:(NSData*)data;

@end