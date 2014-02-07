//
//  CBPeripheralManagerViewController.m
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBPeripheralManagerViewController.h"

#define MAX_MESSAGE_CHUNK_LENGTH 20

#define BOM [@"BOM" dataUsingEncoding:NSUTF8StringEncoding]
#define EOM [@"EOM" dataUsingEncoding:NSUTF8StringEncoding]

@interface CBPeripheralManagerViewController ()

@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *transferCharacteristic;
@property (strong, nonatomic) NSData *dataToSend;
@property (strong, nonatomic) CBCentral *subscribedCentral;

@property (nonatomic, readwrite) NSInteger sendDataIndex;
@property (nonatomic, readwrite) BOOL sendingEOM;
@property (nonatomic, readwrite) BOOL isPeripheralManagerAdvertising;

@end

@implementation CBPeripheralManagerViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];

    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self _stopAdvertising];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn)
        [self _startAdvertising];
}

#pragma mark - Control actions

- (IBAction)backgroundButtonPressed:(id)sender
{
    [self.communicationTextView resignFirstResponder];
}

#pragma mark - CBPeripheralManagerDelegate methods

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch(peripheral.state)
    {
        case CBPeripheralManagerStatePoweredOff:
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStatePoweredOff"];
            self.isPeripheralManagerAdvertising = YES;
            break;
        case CBPeripheralManagerStatePoweredOn:
        {
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStatePoweredOn"];

            CBUUID *serviceUUID = [CBUUID UUIDWithString:TEXT_SERVICE_UUID];
            CBUUID *characteristicUUID = [CBUUID UUIDWithString:TEXT_SERVICE_CHARACTERISTIC_UUID];

            [self _startAdvertising];

            self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID
                                                                             properties:CBCharacteristicPropertyNotify
                                                                                  value:nil
                                                                            permissions:CBAttributePermissionsReadable];
            CBMutableService *transferService = [[CBMutableService alloc] initWithType:serviceUUID
                                                                               primary:YES];
            transferService.characteristics = @[self.transferCharacteristic];
            [self.peripheralManager addService:transferService];
        }
            break;
        case CBPeripheralManagerStateResetting:
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStateResetting"];
            break;
        case CBPeripheralManagerStateUnauthorized:
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStateUnauthorized"];
            break;
        case CBPeripheralManagerStateUnsupported:
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStateUnsupported"];
            break;
        default:
        case CBPeripheralManagerStateUnknown:
            [self _addToDisplayLog:@"new Peripheral Manager State: CBPeripheralManagerStateUnknown"];
            break;
    }
}

- (void)    peripheralManager:(CBPeripheralManager *)peripheral
                     central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    if (central != self.subscribedCentral)
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"Substribed to characteristic \"%@\" on central \"%@\"",
                                                          characteristic,
                                                          central]];

        self.subscribedCentral = central;
        [self _updateDataToSend];
        self.sendDataIndex = 0;
        [self _sendData];
    }
}

- (void)        peripheralManager:(CBPeripheralManager *)peripheral
                          central:(CBCentral *)central
 didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    if (central != self.subscribedCentral)
    {
        self.subscribedCentral = nil;
        [self _addToDisplayLog:[NSString stringWithFormat:@"Unsubstribed from characteristic \"%@\" on central \"%@\"",
                                                          characteristic,
                                                          central]];
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self _sendData];
}

#pragma mark - UITextViewDelegate methods

- (void)textViewDidChange:(UITextView *)textView
{
    [self _updateDataToSend];
}

#pragma mark - Other Methods

- (void)_startAdvertising
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:TEXT_SERVICE_UUID];
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey : @[serviceUUID]}];
    self.isPeripheralManagerAdvertising = YES;
    [self _addToDisplayLog:@"Peripheral Manager started advertising"];
}

- (void)_stopAdvertising
{
    [self.peripheralManager stopAdvertising];
    self.isPeripheralManagerAdvertising = NO;
    [self _addToDisplayLog:@"Peripheral Manager stopped advertising"];
}

- (void)_addToDisplayLog:(NSString*)string
{
    self.logTextView.text = [self.logTextView.text stringByAppendingString:string];
    self.logTextView.text = [self.logTextView.text stringByAppendingString:@"\n"];
}

- (BOOL)_sendEOM
{
    // end of message?
    if (self.sendingEOM)
    {
        BOOL EOMSent = [self.peripheralManager updateValue:EOM
                                         forCharacteristic:self.transferCharacteristic
                                      onSubscribedCentrals:nil];
        if (EOMSent)
        {
            [self _addToDisplayLog:@"Sent EOM"];
            // It did, so mark it as sent
            self.sendingEOM = NO;
        }
        else
        {
            [self _addToDisplayLog:@"Failed to send EOM"];
        }
        // didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call _sendData again
    }
    return self.sendingEOM;
}

- (void)_sendData
{
    if ([self _sendEOM])
    {
        return;
    }

    // We're sending data
    // Is there any left to send?
    if (!self.dataToSend ||
        self.sendDataIndex >= [self.dataToSend length])
    {
        // No data left.  Do nothing
        [self _addToDisplayLog:@"No data left to send"];
        return;
    }

    // There's data left, so send until the callback fails, or we're done.
    BOOL didSend = YES;
    while (didSend)
    {
        // Work out how big it should be
        NSUInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > MAX_MESSAGE_CHUNK_LENGTH)
        {
            amountToSend = MAX_MESSAGE_CHUNK_LENGTH;
        }
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes + self.sendDataIndex length:amountToSend];
        didSend = [self.peripheralManager updateValue:chunk
                                    forCharacteristic:self.transferCharacteristic
                                 onSubscribedCentrals:nil];

        NSString *chunkString = [[NSString alloc] initWithData:chunk
                                                      encoding:NSUTF8StringEncoding];
        [self _addToDisplayLog:[NSString stringWithFormat:@"Sending chunk \"%@\"", chunkString]];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend)
        {
            [self _addToDisplayLog:@"Chunk failed to send"];
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];

        [self _addToDisplayLog:[NSString stringWithFormat:@"Sent: %@", stringFromData]];
        
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length)
        {
            // Set this so if the send fails, we'll send it next time
            self.sendingEOM = YES;
            self.dataToSend = nil;

            BOOL eomSent = [self.peripheralManager updateValue:EOM
                                             forCharacteristic:self.transferCharacteristic
                                          onSubscribedCentrals:nil];
            if (eomSent)
            {
                // It sent, we're all done
                self.sendingEOM = NO;
                [self _addToDisplayLog:@"Sent: EOM"];
            }
            return;
        }
    }
}

- (void)_updateDataToSend
{
    self.dataToSend = [self.communicationTextView.text dataUsingEncoding:NSUTF8StringEncoding];
    self.sendDataIndex = 0;
    [self _sendData];
}

@end
