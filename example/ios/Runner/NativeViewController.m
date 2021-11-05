//
//  NativeViewController.m
//  Runner
//
//  Created by sheng on 2021/9/23.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

#import "NativeViewController.h"

@interface NativeViewController ()

@end

@implementation NativeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)backFlutter:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

@end
