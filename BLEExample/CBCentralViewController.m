//
//  CBCentralViewController.m
//  BLEExample
//
//  Created by cruinh on 2/4/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBCentralViewController.h"

@interface CBCentralViewController ()

@property(strong, nonatomic) CBCentralManager *centralManager;
@property(strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property(strong, nonatomic) NSMutableData *data;
@property(assign, nonatomic) BOOL isCentralManagerScanning;

@end

@implementation CBCentralViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];

    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.discoveredPeripherals = [NSMutableArray new];
    self.data = [NSMutableData new];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.isCentralManagerScanning)
    {
        [self _stopScanning];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.centralManager.state == CBCentralManagerStatePoweredOn)
        [self _startScanning];
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBCentralManagerStatePoweredOff:
            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStatePoweredOff"];
            self.isCentralManagerScanning = NO;
            break;
        case CBCentralManagerStatePoweredOn:

            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStatePoweredOn"];
            [self _startScanning];

            break;
        case CBCentralManagerStateResetting:
            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStateResetting"];
            break;
        case CBCentralManagerStateUnauthorized:
            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStateUnauthorized"];
            break;
        case CBCentralManagerStateUnsupported:
            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStateUnsupported"];
            break;
        default:
        case CBCentralManagerStateUnknown:
            [self _addToDisplayLog:@"new Central Manager State: CBCentralManagerStateUnknown"];
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    [self _addToDisplayLog:[NSString stringWithFormat:@"Discovered Peripheral : %@ (RSSI: %@)", peripheral, RSSI]];

    if (![self.discoveredPeripherals containsObject:peripheral])
    {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        [self.discoveredPeripherals addObject:peripheral];

        [self _addToDisplayLog:[NSString stringWithFormat:@"Connecting to peripheral %@", peripheral]];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)    centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                     error:(NSError *)error
{
    [self _addToDisplayLog:[NSString stringWithFormat:@"Failed to connect to peripheral: %@\n%@", peripheral, error]];
    [self _cleanup];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [self _addToDisplayLog:[NSString stringWithFormat:@"Connected to peripheral: %@", peripheral]];

    [self _stopScanning];

    [self.data setLength:0];
    peripheral.delegate = self;

    [peripheral discoverServices:@[[CBUUID UUIDWithString:TEXT_SERVICE_UUID]]];
}

- (void) centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{
    if (error)
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"[--ERROR--]: %s\n%@", __PRETTY_FUNCTION__, error]];
    }

    [self _addToDisplayLog:[NSString stringWithFormat:@"Disconnected from Peripheral: %@", peripheral]];

    [self.discoveredPeripherals removeObject:peripheral];

    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TEXT_SERVICE_UUID]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
}

#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error)
    {
        for (CBService *service in peripheral.services)
        {
            [self _addToDisplayLog:[NSString stringWithFormat:@"Discovering characteristic on peripheral: %@",
                                                              peripheral]];

            [peripheral discoverCharacteristics:@[[self _characteristicUUID]]
                                     forService:service];
        }
    }
    else
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"[--ERROR--]: %s\n%@", __PRETTY_FUNCTION__, error]];
        [self _cleanup];
    }
}

- (void)                  peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
                               error:(NSError *)error
{
    [self _addToDisplayLog:[NSString stringWithFormat:@"Discovered characteristics for service \"%@\" from peripheral \"%@\"",
                                                      service,
                                                      peripheral]];
    if (!error)
    {
        for (CBCharacteristic *characteristic in service.characteristics)
        {
            if ([characteristic.UUID isEqual:[self _characteristicUUID]])
            {
                [self _addToDisplayLog:[NSString stringWithFormat:@"Requesting notifications from service \"%@\" from characteristic \"%@\" from peripheral \"%@\"",
                                                                  service,
                                                                  characteristic,
                                                                  peripheral]];
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
    else
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"[--ERROR--]: %s\n%@", __PRETTY_FUNCTION__, error]];
        [self _cleanup];
    }
}

- (void)             peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                          error:(NSError *)error
{
    if (!error)
    {
        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        [self _addToDisplayLog:[NSString stringWithFormat:@"Received: %@", stringFromData]];

        // Have we got everything we need?
        if ([stringFromData isEqualToString:@"EOM"])
        {
            [self _addToDisplayLog:@"Received EOM"];
            [self.communicationTextView setText:[[NSString alloc] initWithData:self.data
                                                                      encoding:NSUTF8StringEncoding]];
            self.data = [NSMutableData new];
        }
        else
        {
            [self.data appendData:characteristic.value];
        }
    }
    else
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"[--ERROR--]: %s\n%@", __PRETTY_FUNCTION__, error]];
    }

}

- (void)                         peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
                                      error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[self _characteristicUUID]])
    {
        if (characteristic.isNotifying)
        {
            [self _addToDisplayLog:[NSString stringWithFormat:@"Notification began on %@", characteristic]];
        }
        else
        {
            // Notification has stopped
            [self _addToDisplayLog:[NSString stringWithFormat:@"Notification has stopped from peripheral \"%@\" for characteristic \"%@\"",
                                                              peripheral,
                                                              characteristic]];
            [self.centralManager cancelPeripheralConnection:peripheral];
        }
    }
}

#pragma mark - Other Private Methods

- (void)_startScanning
{
    [self.centralManager scanForPeripheralsWithServices:@[[self _serviceUUID]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
    self.isCentralManagerScanning = YES;

    [self _addToDisplayLog:@"Scanning started"];
}

- (void)_stopScanning
{
    [self.centralManager stopScan];
    self.isCentralManagerScanning = NO;

    [self _addToDisplayLog:@"Scanning stopped"];
}

- (void)_addToDisplayLog:(NSString *)string
{
    NSLog(@"%@",string);
    self.logTextView.text = [self.logTextView.text stringByAppendingString:string];
    self.logTextView.text = [self.logTextView.text stringByAppendingString:@"\n"];
}

- (CBUUID *)_serviceUUID
{
    return [CBUUID UUIDWithString:TEXT_SERVICE_UUID];
}

- (CBUUID *)_characteristicUUID
{
    return [CBUUID UUIDWithString:TEXT_SERVICE_CHARACTERISTIC_UUID];
}

- (void)_cleanup
{
    [self _addToDisplayLog:@"Cleaning up connected peripherals..."];
    // See if we are subscribed to a characteristic on the peripheral
    for (CBPeripheral *cbPeripheral in self.discoveredPeripherals)
    {
        if (cbPeripheral.services != nil)
        {
            for (CBService *service in cbPeripheral.services)
            {
                if (service.characteristics != nil)
                {
                    for (CBCharacteristic *characteristic in service.characteristics)
                    {
                        if ([characteristic.UUID isEqual:[self _characteristicUUID]])
                        {
                            if (characteristic.isNotifying)
                            {
                                [cbPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            }
                        }
                    }
                }
            }
        }
        [self.centralManager cancelPeripheralConnection:cbPeripheral];
    }
    [self _addToDisplayLog:@"All peripherals disconnected."];
}

@end
