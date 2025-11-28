//
//

#import "CommonAICuidUtils.h"
#import <sys/utsname.h>

@implementation CommonAICuidUtils


+ (NSString *)getDeviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

// 获取总内存大小
+ (long long)getTotalMemorySize {
    return [NSProcessInfo processInfo].physicalMemory;
}

// 获取磁盘总空间
+ (int64_t)getTotalDiskSpace {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) return -1;
    int64_t space =  [[attrs objectForKey:NSFileSystemSize] longLongValue];
    if (space < 0) space = -1;
    return space;
}

+ (NSString *)deviceHash {
    NSString *dModel = [CommonAICuidUtils getDeviceModel];
    NSUInteger memorySize = roundf([CommonAICuidUtils getTotalMemorySize]/1000./1000./1000.);
    NSUInteger totalDiskSpace = roundf([CommonAICuidUtils getTotalDiskSpace]/1000./1000./1000.);
    
    NSString *deviceInfo = [NSString stringWithFormat:@"%@%lu%lu", dModel, (unsigned long)memorySize, (unsigned long)totalDiskSpace];
    NSString *deviceHash = [NSString stringWithFormat:@"%lud", (unsigned long)[deviceInfo hash]];
    
    return deviceHash;
}

@end
