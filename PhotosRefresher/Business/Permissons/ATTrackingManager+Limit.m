//
//  ATTrackingManager+Limit.m
//  PlantAI
//
//  Created by zhaoliang09 on 2024/11/26.
//

#import "ATTrackingManager+Limit.h"
#import <objc/runtime.h>
#import "PhotosRefresher-Swift.h"

@implementation ATTrackingManager (Limit)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        SEL originalSelector = @selector(requestTrackingAuthorizationWithCompletionHandler:);
        SEL swizzledSelector = @selector(x_limit_requestTrackingAuthorizationWithCompletionHandler:);

        Method originalMethod = class_getClassMethod(self, originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

+ (void)x_limit_requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus))completion {
    
    if (!PermissionManager.canShowIDFA) {
        return;
    }
    [self x_limit_requestTrackingAuthorizationWithCompletionHandler:completion];
}


@end
