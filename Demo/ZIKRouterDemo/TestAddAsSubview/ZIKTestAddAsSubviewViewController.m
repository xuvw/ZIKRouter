//
//  ZIKTestAddAsSubviewViewController.m
//  ZIKRouterDemo
//
//  Created by zuik on 2017/7/5.
//  Copyright © 2017 zuik. All rights reserved.
//

#import "ZIKTestAddAsSubviewViewController.h"
@import ZIKRouter;
#import "ZIKSimpleLabelProtocol.h"

@interface ZIKTestAddAsSubviewViewController ()
@property (nonatomic, strong) ZIKViewRouter *labelRouter;
@end

@implementation ZIKTestAddAsSubviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)addAsSubview:(id)sender {
    self.labelRouter = [ZIKViewRouter.toView(ZIKSimpleLabelProtocol_routable)
                        performFromSource:self.view
                        configuring:^(ZIKViewRouteConfiguration * _Nonnull config) {
                            config.routeType = ZIKViewRouteTypeAddAsSubview;
                            config.prepareDestination = ^(id<ZIKSimpleLabelProtocol>  _Nonnull destination) {
                                destination.text = @"this is a label from router";
                                destination.frame = CGRectMake(50, 50, 200, 50);
                            };
                            config.routeCompletion = ^(UIView * _Nonnull destination) {
                                NSLog(@"add as subview complete");
                            };
                            config.errorHandler = ^(ZIKRouteAction routeAction, NSError * _Nonnull error) {
                                NSLog(@"add as subview failed: %@",error);
                            };
                        }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
