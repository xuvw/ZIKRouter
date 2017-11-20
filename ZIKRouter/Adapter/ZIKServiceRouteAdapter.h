//
//  ZIKServiceRouteAdapter.h
//  ZIKRouter
//
//  Created by zuik on 2017/8/21.
//  Copyright © 2017 zuik. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "ZIKServiceRouter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Subclass it and register protocols for other ZIKServiceRouter in the subclass's +registerRoutableDestination with +registerServiceProtocol: or +registerModuleProtocol:. It's only for register protocol for other ZIKServiceRouter, don't use it's instance.
 @discussion
 Why you need an adapter to decouple? There is a situation: module A need to use a file log module inside it, and A use the log module by a required interface (ModuleALogProtocol). The app context provides the log module with module B, and module B use a provided interface (ModuleBLogProtocol). So in the app context, you need to adapte required interface(ModuleALogProtocol) and provided interface(ModuleBLogProtocol). Use category, swift extension, NSProxy or custom mediator to forward ModuleALogProtocol to ModuleBLogProtocol. Then module A is totally decoupled with module B.
 */
@interface ZIKServiceRouteAdapter : ZIKServiceRouter
- (nullable instancetype)initWithConfiguration:(__kindof ZIKPerformRouteConfiguration *)configuration
                           removeConfiguration:(nullable __kindof ZIKRouteConfiguration *)removeConfiguration NS_UNAVAILABLE;
- (nullable instancetype)initWithConfiguring:(void(NS_NOESCAPE ^)(__kindof ZIKPerformRouteConfiguration *config))configBuilder
                           removing:(void(NS_NOESCAPE ^ _Nullable)( __kindof ZIKRouteConfiguration *config))removeConfigBuilder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)canPerform NS_UNAVAILABLE;
- (void)performRoute NS_UNAVAILABLE;
- (void)performRouteWithSuccessHandler:(void(^ __nullable)(void))performerSuccessHandler
                          errorHandler:(void(^ __nullable)(SEL routeAction, NSError *error))performerErrorHandler NS_UNAVAILABLE;
- (BOOL)canRemove NS_UNAVAILABLE;
- (void)removeRoute NS_UNAVAILABLE;
- (void)removeRouteWithSuccessHandler:(void(^ __nullable)(void))performerSuccessHandler
                         errorHandler:(void(^ __nullable)(SEL routeAction, NSError *error))performerErrorHandler NS_UNAVAILABLE;
+ (nullable __kindof ZIKServiceRouter *)performWithConfiguring:(void(NS_NOESCAPE ^)(__kindof ZIKPerformRouteConfiguration *config))configBuilder
                                             removing:(void(NS_NOESCAPE ^ _Nullable)( __kindof ZIKRouteConfiguration *config))removeConfigBuilder NS_UNAVAILABLE;
+ (nullable __kindof ZIKServiceRouter *)performWithConfiguring:(void(NS_NOESCAPE ^)(__kindof ZIKPerformRouteConfiguration *config))configBuilder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
