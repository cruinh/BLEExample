//
//  TabBarController.m
//  BLEExample
//
//  Created by cruinh on 2/6/14.
//  Copyright (c) 2014 Matthew Hayes. All rights reserved.
//

#import "TabBarController.h"

@interface TabBarController ()

@end

@implementation TabBarController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad)
    {
        self.tabBar.itemSpacing = 50;
    }
}

@end
