//
// Created by cruinh on 5/14/14.
// Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "CBCentralViewModel.h"

@interface CBCentralViewModel ()

@property(strong, nonatomic) CBCentralManager *centralManager;
@property(strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property(strong, nonatomic) NSMutableData *data;
@property(assign, nonatomic) BOOL isCentralManagerScanning;

@property(strong, nonatomic) dispatch_queue_t managerQueue;

@end

@implementation CBCentralViewModel

- (id)initWithDelegate:(id<CBManagerViewModelDelegate>)delegate
{
    self = [super init];
    if (self)
    {
        self.delegate = delegate;

        self.managerQueue = dispatch_queue_create("CBCentralManagerViewModelQueue",DISPATCH_QUEUE_CONCURRENT);
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.managerQueue];
        self.discoveredPeripherals = [NSMutableArray new];
        self.data = [NSMutableData new];
    }
    return self;
}

- (void)startScanning
{
    dispatch_async(self.managerQueue,^{
        if (self.centralManager.state == CBCentralManagerStatePoweredOn)
        {
            [self.centralManager scanForPeripheralsWithServices:@[[self _serviceUUID]]
                                                        options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
            self.isCentralManagerScanning = YES;

            [self _addToDisplayLog:@"Scanning started"];
        }
    });
}

- (void)stopScanning
{
    dispatch_async(self.managerQueue,^{
        if (self.isCentralManagerScanning)
        {
            [self.centralManager stopScan];
            self.isCentralManagerScanning = NO;

            [self _addToDisplayLog:@"Scanning stopped"];
        }
    });
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
            [self startScanning];

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
    if (![self.discoveredPeripherals containsObject:peripheral])
    {
        [self _addToDisplayLog:[NSString stringWithFormat:@"Discovered New Peripheral : %@ (RSSI: %@)", peripheral, RSSI]];

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

    [self stopScanning];

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
            [self.delegate viewModelReceivedData:self.data];
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

- (void)_addToDisplayLog:(NSString *)string
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotification_CBManagerViewModelDelegate_LogOutput
                                                        object:self
                                                      userInfo:@{@"logText":string}];
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