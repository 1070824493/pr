

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonAICuid : NSObject

+ (instancetype)sharedInstance;


/// Application Device Identifier, 设备唯一标识符
- (NSString *)getDeviceADID;



@end

NS_ASSUME_NONNULL_END
