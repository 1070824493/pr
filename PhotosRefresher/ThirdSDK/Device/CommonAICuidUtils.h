//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonAICuidUtils : NSObject

+ (NSString *)getDeviceModel;

+ (long long)getTotalMemorySize;

+ (int64_t)getTotalDiskSpace;

+ (NSString *)deviceHash;

@end

NS_ASSUME_NONNULL_END
