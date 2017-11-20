//
//  ZIKServiceRouter.m
//  ZIKRouter
//
//  Created by zuik on 2017/8/9.
//  Copyright © 2017 zuik. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "ZIKServiceRouter.h"
#import "ZIKRouterInternal.h"
#import "ZIKServiceRouterPrivate.h"
#import "ZIKServiceRouteRegistry.h"
#import "ZIKRouteRegistryInternal.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "ZIKRouterRuntime.h"

NSString *const kZIKServiceRouterErrorDomain = @"ZIKServiceRouterErrorDomain";

static ZIKServiceRouteGlobalErrorHandler g_globalErrorHandler;
static dispatch_semaphore_t g_globalErrorSema;

@interface ZIKServiceRouter ()

@end

@implementation ZIKServiceRouter

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [ZIKRouteRegistry addRegistry:[ZIKServiceRouteRegistry class]];
        g_globalErrorSema = dispatch_semaphore_create(1);
    });
}

+ (void)_autoRegistrationDidFinished {
    
}

_Nullable Class _ZIKServiceRouterToService(Protocol *serviceProtocol) {
    NSCParameterAssert(serviceProtocol);
    NSCAssert(ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only get router after app did finish launch.");
    if (!serviceProtocol) {
        [ZIKServiceRouter _callbackError_invalidProtocolWithAction:@selector(toService) errorDescription:@"ZIKServiceRouter.toService() serviceProtocol is nil"];
        NSCAssert1(NO, @"ZIKServiceRouter.toService() serviceProtocol is nil. callStackSymbols: %@",[NSThread callStackSymbols]);
        return nil;
    }
    Class routerClass = [ZIKServiceRouteRegistry routerToDestination:serviceProtocol];
    if (routerClass) {
        return routerClass;
    }
    [ZIKServiceRouter _callbackError_invalidProtocolWithAction:@selector(toService)
                                             errorDescription:@"Didn't find service router for service protocol: %@, this protocol was not registered.",serviceProtocol];
    NSCAssert1(NO, @"Didn't find service router for service protocol: %@, this protocol was not registered.",serviceProtocol);
    return nil;
}

_Nullable Class _ZIKServiceRouterToModule(Protocol *configProtocol) {
    NSCParameterAssert(configProtocol);
    NSCAssert(ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only get router after app did finish launch.");
    if (!configProtocol) {
        [ZIKServiceRouter _callbackError_invalidProtocolWithAction:@selector(toModule) errorDescription:@"ZIKServiceRouter.toModule() configProtocol is nil"];
        NSCAssert1(NO, @"ZIKServiceRouter.toModule() configProtocol is nil. callStackSymbols: %@",[NSThread callStackSymbols]);
        return nil;
    }
    Class routerClass = [ZIKServiceRouteRegistry routerToModule:configProtocol];
    if (routerClass) {
        return routerClass;
    }
    [ZIKServiceRouter _callbackError_invalidProtocolWithAction:@selector(toModule)
                                             errorDescription:@"Didn't find service router for config protocol: %@, this protocol was not registered.",configProtocol];
    NSCAssert1(NO, @"Didn't find service router for config protocol: %@, this protocol was not registered.",configProtocol);
    return nil;
}

- (void)performWithConfiguration:(__kindof ZIKPerformRouteConfiguration *)configuration {
    [[self class] increaseRecursiveDepth];
    if ([[self class] _validateInfiniteRecursion] == NO) {
        [self _callbackError_infiniteRecursionWithAction:@selector(performRoute) errorDescription:@"Infinite recursion for performing route detected. Recursive call stack:\n%@",[NSThread callStackSymbols]];
        [[self class] decreaseRecursiveDepth];
        return;
    }
    [super performWithConfiguration:configuration];
    [[self class] decreaseRecursiveDepth];
}

#pragma mark ZIKRouterProtocol

+ (void)registerRoutableDestination {
    NSAssert1(NO, @"subclass(%@) must override +registerRoutableDestination to register destination.",self);
}

- (void)performRouteOnDestination:(id)destination configuration:(__kindof ZIKPerformRouteConfiguration *)configuration {
    [self beginPerformRoute];
    
    if (!destination) {
        [self endPerformRouteWithError:[[self class] errorWithCode:ZIKServiceRouteErrorServiceUnavailable localizedDescriptionFormat:@"Router(%@) returns nil for destination, you can't use this service now. Maybe your configuration is invalid (%@), or there is a bug in the router.",self,configuration]];
        return;
    }
#if ZIKROUTER_CHECK
    [self _validateDestinationConformance:destination];
#endif
    if (configuration.prepareDestination) {
        configuration.prepareDestination(destination);
    }
    if (configuration.routeCompletion) {
        configuration.routeCompletion(destination);
    }
    [self endPerformRouteWithSuccess];
}

#pragma mark State

- (void)beginPerformRoute {
    NSAssert(self.state != ZIKRouterStateRouting, @"state should not be routing when begin to route.");
    [self notifyRouteState:ZIKRouterStateRouting];
}

- (void)endPerformRouteWithSuccess {
    NSAssert(self.state == ZIKRouterStateRouting, @"state should be routing when end to route.");
    [self notifyRouteState:ZIKRouterStateRouted];
    [self notifySuccessWithAction:@selector(performRoute)];
}

- (void)endPerformRouteWithError:(NSError *)error {
    NSAssert(self.state == ZIKRouterStateRouting, @"state should be routing when end to route.");
    [self notifyRouteState:ZIKRouterStateRouteFailed];
    [self notifyError:error routeAction:@selector(performRoute)];
}

- (void)beginRemoveRoute {
    NSAssert(self.state != ZIKRouterStateRemoving, @"state should not be removing when begin remove route.");
    [self notifyRouteState:ZIKRouterStateRemoving];
}

- (void)endRemoveRouteWithSuccessOnDestination:(id)destination {
    NSAssert(self.state == ZIKRouterStateRemoving, @"state should be removing when end remove route.");
    [self notifyRouteState:ZIKRouterStateRemoved];
}

- (void)endRemoveRouteWithError:(NSError *)error {
    NSAssert(self.state == ZIKRouterStateRemoving, @"state should be removing when end remove route.");
    [self notifyRouteState:ZIKRouterStateRemoveFailed];
    [self notifyError:error routeAction:@selector(removeRoute)];
}

+ (__kindof ZIKPerformRouteConfiguration *)defaultRouteConfiguration {
    return [ZIKPerformRouteConfiguration new];
}

+ (__kindof ZIKRouteConfiguration *)defaultRemoveConfiguration {
    return [ZIKRouteConfiguration new];
}

- (NSString *)errorDomain {
    return kZIKServiceRouterErrorDomain;
}

+ (BOOL)completeSynchronously {
    return YES;
}

#pragma mark Validate

- (BOOL)_validateDestinationConformance:(id)destination {
#if ZIKROUTER_CHECK
    Class routerClass = [self class];
    CFMutableSetRef serviceProtocols = (CFMutableSetRef)CFDictionaryGetValue(ZIKServiceRouteRegistry._check_routerToDestinationProtocolsMap, (__bridge const void *)(routerClass));
    if (serviceProtocols != NULL) {
        for (Protocol *serviceProtocol in (__bridge NSSet*)serviceProtocols) {
            if (!class_conformsToProtocol([destination class], serviceProtocol)) {
                NSAssert(NO, @"Bad implementation in router (%@)'s -destinationWithConfiguration:. The destiantion (%@) doesn't conforms to registered service protocol (%@).",routerClass, destination, NSStringFromProtocol(serviceProtocol));
                return NO;
            }
        }
    }
#endif
    return YES;
}

+ (BOOL)_validateInfiniteRecursion {
    NSUInteger maxRecursiveDepth = 200;
    if ([self recursiveDepth] > maxRecursiveDepth) {
        return NO;
    }
    return YES;
}

#pragma mark Error Handle

+ (void)setGlobalErrorHandler:(ZIKServiceRouteGlobalErrorHandler)globalErrorHandler {
    dispatch_semaphore_wait(g_globalErrorSema, DISPATCH_TIME_FOREVER);
    
    g_globalErrorHandler = globalErrorHandler;
    
    dispatch_semaphore_signal(g_globalErrorSema);
}

- (void)_callbackErrorWithAction:(SEL)routeAction error:(NSError *)error {
    [[self class] _callbackGlobalErrorHandlerWithRouter:self action:routeAction error:error];
    [super notifyError:error routeAction:routeAction];
}

+ (void)_callbackError_invalidProtocolWithAction:(SEL)action errorDescription:(NSString *)format ,... {
    va_list argList;
    va_start(argList, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end(argList);
    [self _callbackGlobalErrorHandlerWithRouter:nil action:action error:[[self class] errorWithCode:ZIKServiceRouteErrorInvalidProtocol localizedDescription:description]];
    NSAssert(NO, @"Error when get router for serviceProtocol: %@",description);
}

- (void)_callbackError_infiniteRecursionWithAction:(SEL)action errorDescription:(NSString *)format ,... {
    va_list argList;
    va_start(argList, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end(argList);
    [self _callbackErrorWithAction:action error:[[self class] errorWithCode:ZIKServiceRouteErrorInfiniteRecursion localizedDescription:description]];
}

#pragma mark Getter/Setter

+ (NSUInteger)recursiveDepth {
    NSNumber *depth = objc_getAssociatedObject(self, @"ZIKServiceRouter_recursiveDepth");
    if ([depth isKindOfClass:[NSNumber class]]) {
        return [depth unsignedIntegerValue];
    }
    return 0;
}

+ (void)setRecursiveDepth:(NSUInteger)depth {
    objc_setAssociatedObject(self, @"ZIKServiceRouter_recursiveDepth", @(depth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)increaseRecursiveDepth {
    NSUInteger depth = [self recursiveDepth];
    [self setRecursiveDepth:++depth];
}

+ (void)decreaseRecursiveDepth {
    NSUInteger depth = [self recursiveDepth];
    [self setRecursiveDepth:--depth];
}

@end

@implementation ZIKServiceRouter (Register)

+ (void)registerService:(Class)serviceClass {
    NSParameterAssert(serviceClass);
    NSParameterAssert([serviceClass conformsToProtocol:@protocol(ZIKRoutableService)]);
    NSAssert(!ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only register in +registerRoutableDestination.");
    NSAssert([NSThread isMainThread], @"Call in main thread for thread safety.");
    [ZIKServiceRouteRegistry registerDestination:serviceClass router:self];
}

+ (void)registerExclusiveService:(Class)serviceClass {
    NSParameterAssert([serviceClass conformsToProtocol:@protocol(ZIKRoutableService)]);
    NSAssert(!ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only register in +registerRoutableDestination.");
    NSAssert([NSThread isMainThread], @"Call in main thread for thread safety.");
    [ZIKServiceRouteRegistry registerExclusiveDestination:serviceClass router:self];
}

+ (void)registerServiceProtocol:(Protocol *)serviceProtocol {
    NSAssert(!ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only register in +registerRoutableDestination.");
    NSAssert([NSThread isMainThread], @"Call in main thread for thread safety.");
    [ZIKServiceRouteRegistry registerDestinationProtocol:serviceProtocol router:self];
}

+ (void)registerModuleProtocol:(Protocol *)configProtocol {
    NSAssert([[self defaultRouteConfiguration] conformsToProtocol:configProtocol], @"configProtocol should be conformed by this router's defaultRouteConfiguration.");
    NSAssert(!ZIKServiceRouteRegistry.autoRegistrationFinished, @"Only register in +registerRoutableDestination.");
    NSAssert([NSThread isMainThread], @"Call in main thread for thread safety.");
    [ZIKServiceRouteRegistry registerModuleProtocol:configProtocol router:self];
}

_Nullable Class _swift_ZIKServiceRouterToService(id serviceProtocol) {
    return _ZIKServiceRouterToService(serviceProtocol);
}

extern _Nullable Class _swift_ZIKServiceRouterToModule(id configProtocol) {
    return _ZIKServiceRouterToModule(configProtocol);
}

@end

@implementation ZIKServiceRouter (Discover)

+ (Class(^)(Protocol *))toService {
    return ^(Protocol *serviceProtocol) {
        return _ZIKServiceRouterToService(serviceProtocol);
    };
}

+ (Class(^)(Protocol *))toModule {
    return ^(Protocol *configProtocol) {
        return _ZIKServiceRouterToModule(configProtocol);
    };
}

@end

@implementation ZIKServiceRouter (Private)

+ (BOOL)shouldCheckImplementation {
#if ZIKROUTER_CHECK
    return YES;
#else
    return NO;
#endif
}

+ (BOOL)_isAutoRegistrationFinished {
    return ZIKServiceRouteRegistry.autoRegistrationFinished;
}

+ (void)_swift_registerServiceProtocol:(id)serviceProtocol {
    NSCParameterAssert(ZIKRouter_isObjcProtocol(serviceProtocol));
    [self registerServiceProtocol:serviceProtocol];
}

+ (void)_swift_registerConfigProtocol:(id)configProtocol {
    NSCParameterAssert(ZIKRouter_isObjcProtocol(configProtocol));
    [self registerModuleProtocol:configProtocol];
}

+ (_Nullable Class)validateRegisteredServiceClasses:(ZIKServiceClassValidater)handler {
#if ZIKROUTER_CHECK
    Class routerClass = self;
    CFMutableSetRef services = (CFMutableSetRef)CFDictionaryGetValue(ZIKServiceRouteRegistry._check_routerToDestinationsMap, (__bridge const void *)(routerClass));
    __block Class badClass = nil;
    [(__bridge NSSet *)(services) enumerateObjectsUsingBlock:^(Class  _Nonnull serviceClass, BOOL * _Nonnull stop) {
        if (handler) {
            if (!handler(serviceClass)) {
                badClass = serviceClass;
                *stop = YES;
            }
        }
    }];
    return badClass;
#else
    return nil;
#endif
}

+ (void)_callbackGlobalErrorHandlerWithRouter:(nullable __kindof ZIKServiceRouter *)router action:(SEL)action error:(NSError *)error {
    dispatch_semaphore_wait(g_globalErrorSema, DISPATCH_TIME_FOREVER);
    
    ZIKServiceRouteGlobalErrorHandler errorHandler = g_globalErrorHandler;
    if (errorHandler) {
        errorHandler(router, action, error);
    } else {
#ifdef DEBUG
        NSLog(@"❌ZIKServiceRouter Error: router's action (%@) catch error: (%@),\nrouter:(%@)", NSStringFromSelector(action), error,router);
#endif
    }
    
    dispatch_semaphore_signal(g_globalErrorSema);
}

@end
