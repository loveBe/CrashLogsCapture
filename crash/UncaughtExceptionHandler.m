//
//  UncaughtExceptionHandler.m
//  crash
//
//  Created by 陈伟欣 on 2018/2/5.
//  Copyright © 2018年 CWX. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>

NSString *const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString *const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString *const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;


@implementation UncaughtExceptionHandler

+ (NSArray *)backtrace {
    void* callstack[128];
    int frames =backtrace(callstack, 128);
    char **strs =backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount ; i <UncaughtExceptionHandlerSkipAddressCount +UncaughtExceptionHandlerReportAddressCount; i++){
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

- (void)handleException:(NSException *)exception {
    // 写入文件
    writeFileExceptionHandler(exception);
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    while (!dismissed) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode,0.001, false);
        }
    }
    
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey]intValue]);
    }else{
        [exception raise];
    }
}

// 写入文件
void writeFileExceptionHandler(NSException * exception) {
    // 崩溃的原因  可以有崩溃的原因(数组越界,字典nil,调用未知方法...) 崩溃的控制器以及方法
    NSString *reason = [exception reason];
    // 崩溃时获取到的当前页面
    NSString *className = NSStringFromClass([[Utils getCurrentVC] class]);
    // 系统版本号
    NSString *sysVersion = [[UIDevice currentDevice] systemVersion];
    // 应用版本号
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    // callStackSymbols
    NSArray *arr = [exception callStackSymbols];
    
    NSString *url = [NSString stringWithFormat:@"\n\n========异常错误报告========\n\n崩溃时间：%@\n\n系统版本：%@\n\n应用版本：%@\n\n崩溃原因:\n%@\n\ncallStackSymbols:\n%@\n\n",
                     [Utils getCurrentTime],
                     sysVersion,
                     appVersion,
                     reason,
                     [arr componentsJoinedByString:@"\n"]
                     ];
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Exception.txt"];
    
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"NSString类方法读取的内容是：\n%@\n\n新内容：\n%@",content,url);
    
    if (content.length != 0 && [content rangeOfString:reason].location != NSNotFound) {// 相同
        [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:@"isCrash"];
        return;
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"isCrash"];
    }
    
    // 将一个txt文件写入沙盒
    [url writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void HandleException(NSException *exception) {
    int32_t exceptionCount =OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount >UncaughtExceptionMaximum) {
        return;
    }
    
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];[userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    [[[UncaughtExceptionHandler alloc] init]performSelectorOnMainThread:@selector(handleException:)withObject:
     [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo]waitUntilDone:YES];
}

void SignalHandler(int signal) {
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount >UncaughtExceptionMaximum) {
        return;
    }
    
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    [[[UncaughtExceptionHandler alloc] init]performSelectorOnMainThread:@selector(handleException:)withObject:[NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason:[NSString stringWithFormat:NSLocalizedString(@"Signal %d was raised.",nil),signal]userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:signal]forKey:UncaughtExceptionHandlerSignalKey]]waitUntilDone:YES];
}

void InstallUncaughtExceptionHandler(void) {
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT,SignalHandler);
    signal(SIGILL,SignalHandler);
    signal(SIGSEGV,SignalHandler);
    signal(SIGFPE,SignalHandler);
    signal(SIGBUS,SignalHandler);
    signal(SIGPIPE,SignalHandler);
}

@end
