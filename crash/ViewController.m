//
//  ViewController.m
//  crash
//
//  Created by 陈伟欣 on 2018/2/5.
//  Copyright © 2018年 CWX. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor greenColor];
    
    NSArray *a = @[@"11"];
    NSLog(@"%@",a[2]);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
