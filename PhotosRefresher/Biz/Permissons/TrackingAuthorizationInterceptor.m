//
//  TrackingAuthorizationInterceptor.m
//

#import "TrackingAuthorizationInterceptor.h"
#import <objc/runtime.h>
#import "PhotosRefresher-Swift.h"

@implementation ATTrackingManager (Interceptor)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL originalSelector = @selector(requestTrackingAuthorizationWithCompletionHandler:);
        SEL swizzledSelector = @selector(intercept_requestTrackingAuthorizationWithCompletionHandler:);

        Method originalMethod = class_getClassMethod(self, originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);

        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

+ (void)intercept_requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus))completion {
    if (![PRPermissionManager canShowIDFA]) {
        if (completion) {
            completion(ATTrackingManagerAuthorizationStatusDenied);
        }
        return;
    }
    [self intercept_requestTrackingAuthorizationWithCompletionHandler:completion];
}

@end