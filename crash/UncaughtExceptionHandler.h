//
//  UncaughtExceptionHandler.h
//  crash
//
//  Created by 陈伟欣 on 2018/2/5.
//  Copyright © 2018年 CWX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UncaughtExceptionHandler : NSObject
{
    BOOL dismissed;
}

void HandleException(NSException *exception);
void SignalHandler(int signal);


void InstallUncaughtExceptionHandler(void);

@end
