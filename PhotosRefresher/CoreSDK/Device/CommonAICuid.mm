//
//

#import "CommonAICuid.h"
#import <CommonCrypto/CommonDigest.h> // Need to import for CC_MD5 access
#import "SSKeychain.h"
#import "CommonAICuidUtils.h"
#import <pthread.h>
#import <Foundation/Foundation.h>


static NSString * const kCommonAICuid = @"CommonAI_Cuid";
static NSString * const kCommonAICuidKeychain = @"CommonAI_Cuid_KEYCHAIN";
static NSString * const kCommonAICuid_KEYCHAIN_SERVICE = @"CommonAI_Cuid_KEYCHAIN_SERVICE";
static NSString * const kCommonAICuid_DEVICE = @"CommonAI_Cuid_DEVICE";
static NSString * const kCommonAICuidAccount = @"CommonAI_Cuid_ADID";
static NSString * const kADID_SAVE_SERIAL = @"ADID_SAVE_SERIAL";

static NSString * const CommonAICuid_CLOUD = @"CommonAI_Cuid_CLOUD";


@interface CommonAICuid()

@property (nonatomic, strong) NSString *ADID;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSMetadataQuery *metaQuery;
@property (nonatomic, strong) NSString *currentDeviceKey;


@end

@implementation CommonAICuid

+ (instancetype)sharedInstance {
    static CommonAICuid *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CommonAICuid alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // 初始化锁
        _lock = [NSLock new];
        _metaQuery = [[NSMetadataQuery alloc] init];
        
        NSDate *startDate = [NSDate date]; // 当前时间
        if ([self isICloudEnabled]) {
            [self sycCloud];
        }
        [self timeIntervalInMillisecondsStarDate:startDate uploggerString:@"sycCloudTime"];
        _currentDeviceKey = [self getCloudCuidKey];
    }
    
    return self;
}


-(void)timeIntervalInMillisecondsStarDate:(NSDate *)startDate uploggerString:(NSString *)logName{
    NSDate *endDate = [NSDate date]; // 当前时间，假设是结束时间
    NSTimeInterval timeInterval = [endDate timeIntervalSinceDate:startDate];
    double timeIntervalInMilliseconds = timeInterval * 1000.0;
}


-(void)sycCloud{
    BOOL  isSynchronize = [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    if (isSynchronize) {
        NSLog(@"同步成功");
//        [self printAlliCloudKeyValueStoreContents];
    }
    else{
        NSLog(@"同步失败");
    }
}


- (void)printAlliCloudKeyValueStoreContents {
    NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
    NSDictionary *storeDictionary = [iCloudStore dictionaryRepresentation];
    for (NSString *key in storeDictionary) {
        id value = storeDictionary[key];
        NSLog(@"key = %@ - value= %@",key,value);
    }
}


- (BOOL)isICloudEnabled {
    // 检查用户是否登录 iCloud
    if (![self isICloudLoggedIn]) {
        return NO;
    }
    
    // 检查 iCloud Key-Value 存储是否可用
    if (![self isICloudAvailable]) {
        return NO;
    }
    

    return YES;
}

// 检查 iCloud 账号是否登录
- (BOOL)isICloudLoggedIn {
    id token = [[NSFileManager defaultManager] ubiquityIdentityToken];
    return token != nil;
}

// 检查 iCloud Key-Value 存储是否可用
- (BOOL)isICloudAvailable {
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        return YES;
    } else {
        return NO;
    }
}

-(NSString *)getCloudCuidKey{
    NSString *device =   [CommonAICuidUtils deviceHash];
    NSString * keyCuid = [NSString stringWithFormat:@"%@%@",@"CUID",device];
    return keyCuid;
}

- (NSString *)getDeviceADID {
    NSString *tempADID;
    if (self.ADID.length == 0) {
        [_lock lock];
        
        tempADID = [self getValidateADIDInUserDefault];
        if (tempADID.length == 0) {
            
            tempADID = [self getValidateADIDInKeychain];
            
            if (tempADID.length == 0) {
                
                NSDate *startDate = [NSDate date]; // 当前时间
                if ([self isICloudEnabled]) {
                    tempADID = [self getValidateADIDiCloud];
                }
                [self timeIntervalInMillisecondsStarDate:startDate uploggerString:@"GetCuidCloudTime"];
                if (tempADID.length == 0) {
                    tempADID = [self _generateFreshADID];
                }
            }
        }
        [self syncADID:tempADID];
        [_lock unlock];
    }
    return self.ADID;
}


- (void)syncADID:(NSString *)adid {
    if (adid.length == 0) {
        return;
    }
    BOOL needSaveADID = NO;
    _ADID = adid;
    NSDictionary *ADIDFromKeychainDic = [self ADIDDicFromKeychain];
    if (ADIDFromKeychainDic) {
        NSString *adidKeychain = [ADIDFromKeychainDic valueForKey:kCommonAICuidKeychain];
        NSString *device = [ADIDFromKeychainDic valueForKey:kCommonAICuid_DEVICE];
        if (![device isEqualToString:[CommonAICuidUtils deviceHash]] || ![adidKeychain isEqualToString:adid]) {
            needSaveADID = YES;
        }
    } else {
        needSaveADID = YES;
    }
    
    if ([self isICloudEnabled]) {
        NSUbiquitousKeyValueStore *kvStore = [NSUbiquitousKeyValueStore defaultStore];
       if (kvStore) {
            NSString *adidCloud = [kvStore objectForKey:self.currentDeviceKey];
           if (![kvStore.dictionaryRepresentation.allKeys containsObject:self.currentDeviceKey] || ![adidCloud isEqualToString:adid]) {
               needSaveADID = YES;
           }
       } else {
           needSaveADID = YES;
       }
    }

        
    NSString *ADIDFromUserDefault = [self ADIDFromUserDefault];
    if (!ADIDFromUserDefault || ![adid isEqualToString:ADIDFromUserDefault]) {
        needSaveADID = YES;
    }
        
    if (needSaveADID) {
        [self saveADID];
    }
}






- (NSString *)ADIDFromUserDefault {
    return [[NSUserDefaults standardUserDefaults] valueForKey:kCommonAICuid];
}

- (NSString *)ADIDDeviceFromUserDefault {
    return [[NSUserDefaults standardUserDefaults] valueForKey:kCommonAICuid_DEVICE];
}

- (void)saveADIDToUserDefault:(NSString *)ADID {
    if (ADID.length == 0) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setValue:[CommonAICuidUtils deviceHash] forKey:kCommonAICuid_DEVICE];
    [[NSUserDefaults standardUserDefaults] setValue:ADID forKey:kCommonAICuid];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (NSString *)getValidateADIDInUserDefault {
    NSString *ADIDFromUserDefault = [self ADIDFromUserDefault];
    BOOL deviceValidate = [[CommonAICuidUtils deviceHash] isEqualToString:[self ADIDDeviceFromUserDefault]]; ///
    BOOL adidValidate = [self isValidateADID:ADIDFromUserDefault]; ///
    if (ADIDFromUserDefault.length && deviceValidate && adidValidate) {
        return ADIDFromUserDefault;
    } else {
        self.ADID = nil;
        return nil;
    }
}




- (void)saveADIDiCloud:(NSString *)ADID {
    if (ADID.length == 0) {
        return;
    }
    NSUbiquitousKeyValueStore *kvStore = [NSUbiquitousKeyValueStore defaultStore];
    [kvStore setObject:ADID forKey:self.currentDeviceKey];
    [kvStore synchronize];
}


- (NSString *)getValidateADIDiCloud {
    NSUbiquitousKeyValueStore *kvStore = [NSUbiquitousKeyValueStore defaultStore];
    [kvStore synchronize];
    NSString * currentDevice = self.currentDeviceKey;
    if (kvStore) {
        BOOL deviceValidate =  [kvStore.dictionaryRepresentation.allKeys containsObject:currentDevice]; ///判断icloud是否有当前设备信息
        if (deviceValidate) {
            NSString *cuid = [kvStore objectForKey:currentDevice];///根据设备信息获取cuid
            BOOL cuidValidate = [self isValidateADID:cuid];///校验cuid
            if (cuidValidate) {
                return cuid;
            }
            else {
                self.ADID = nil;
                return nil;
            }
        }
        else{
            self.ADID = nil;
            return nil;
        }
        
    } else {
        self.ADID = nil;
        return nil;
    }
}

- (NSString *)getValidateADIDInKeychain {
    NSDictionary *ADIDFromKeychainDic = [self ADIDDicFromKeychain];
    if (ADIDFromKeychainDic) {
        NSString *adidKeychain = [ADIDFromKeychainDic valueForKey:kCommonAICuidKeychain];
        NSString *device = [ADIDFromKeychainDic valueForKey:kCommonAICuid_DEVICE];
        BOOL deviceValidate = [[CommonAICuidUtils deviceHash] isEqualToString:device];
        BOOL adidValidate = [self isValidateADID:adidKeychain];
        if (adidKeychain.length && deviceValidate && adidValidate) {
            return adidKeychain;
        } else {
            self.ADID = nil;
            return nil;
        }
    } else {
        self.ADID = nil;
        return nil;
    }
}


- (BOOL)isValidateADID:(NSString *)ADID {
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",@"[a-f0-9]{40}"];
    BOOL ADIDValidate = [pre evaluateWithObject:ADID];
    
    return ADIDValidate;
}


- (NSDictionary *)ADIDDicFromKeychain {
    NSData *ADIDData = [SSKeychain passwordDataForService:kCommonAICuid_KEYCHAIN_SERVICE account:kCommonAICuidAccount];
    NSDictionary *ADIDDic;
    if (ADIDData) {
        //此处返回的一定是NSDictionary，所以强转安全
        ADIDDic = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:ADIDData];
    }
    
    return ADIDDic;
}

- (void)saveADIDToKeychain:(NSString *)ADID {
    if (ADID.length == 0) {
        return;
    }
    NSDictionary *ADIDDic = @{kCommonAICuidKeychain: ADID, kCommonAICuid_DEVICE: [CommonAICuidUtils deviceHash]};
    [SSKeychain setPasswordData:[NSKeyedArchiver archivedDataWithRootObject:ADIDDic] forService:kCommonAICuid_KEYCHAIN_SERVICE account:kCommonAICuidAccount];
}


- (void)saveADID {
    if (self.ADID.length) {
        if ([self isICloudEnabled]) {
            [self saveADIDiCloud:self.ADID];
        }
        [self saveADIDToUserDefault:self.ADID];
        [self saveADIDToKeychain:self.ADID];
    }
}


- (NSString*) _generateFreshADID {
    
    NSString* ADID = nil;
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef cfstring = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    const char *cStr = CFStringGetCStringPtr(cfstring,CFStringGetFastestEncoding(cfstring));
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
    CFRelease(uuid);
    CFRelease(cfstring);
    
    ADID = [NSString stringWithFormat:
             @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
             result[0], result[1], result[2], result[3],
             result[4], result[5], result[6], result[7],
             result[8], result[9], result[10], result[11],
             result[12], result[13], result[14], result[15]];
    
    ADID = [ADID stringByAppendingString:[self hash:ADID]];

    return ADID;
}


- (NSString *)hash:(NSString *)str {
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",@"[a-f0-9]{32}"];
    BOOL result = [pre evaluateWithObject:str];
    if (result) {
        NSString *key1 = [str substringToIndex:str.length/2];
        NSString *key2 = [str substringFromIndex:str.length/2];
        
        const char *key1Array = [key1 UTF8String];
        const char *key2Array = [key2 UTF8String];
        NSMutableString *hash = [NSMutableString string];
        
        while (*key1Array && *key2Array) {
            char c1[2] = {0, '\0'};
            char c2[2] = {0, '\0'};
            
            c1[0] = *key1Array++;
            c2[0] = *key2Array++;
            
            unsigned long hex1 = strtoul(c1,0,16);
            unsigned long hex2 = strtoul(c2,0,16);
            
            NSUInteger ret = hex1^hex2;
            [hash appendFormat:@"%lx", (unsigned long)ret];
        }
        
        
        key1 = [hash substringToIndex:hash.length/2];
        key2 = [hash substringFromIndex:hash.length/2];
        
        hash = [@"" mutableCopy];
        
        key1Array = [key1 UTF8String];
        key2Array = [key2 UTF8String];
        
        while (*key1Array && *key2Array) {
            char c1[2] = {0, '\0'};
            char c2[2] = {0, '\0'};
            
            c1[0] = *key1Array++;
            c2[0] = *key2Array++;
            
            unsigned long hex1 = strtoul(c1,0,16);
            unsigned long hex2 = strtoul(c2,0,16);
            
            NSUInteger ret = hex1^hex2;
            [hash appendFormat:@"%lx", (unsigned long)ret];
        }
        
        return hash;
    } else {
        return [NSString stringWithFormat:@"%08x", 0];
    }
}

@end
