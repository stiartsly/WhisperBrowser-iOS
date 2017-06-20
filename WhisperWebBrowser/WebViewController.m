//
//  WebViewController.m
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import "WebViewController.h"
#import "SelfInfoViewController.h"
#import "DeviceChooseViewController.h"
#import "DeviceManager.h"
#import <WebKit/WebKit.h>

@interface WebViewController () <WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate>
{
    WKWebView *_webView;
    UIProgressView *_progressView;
    UIBarButtonItem *backButtonItem;
    UIBarButtonItem *forwardButtonItem;
}
@end

@implementation WebViewController

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[DeviceManager sharedManager] removeObserver:self forKeyPath:@"currentDevice"];
    [_webView removeObserver:self forKeyPath:@"title"];
    [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [_webView removeObserver:self forKeyPath:@"canGoBack"];
    [_webView removeObserver:self forKeyPath:@"canGoForward"];
    _webView.scrollView.delegate = nil;
    _webView.navigationDelegate = nil;
    _webView.UIDelegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"user"] style:UIBarButtonItemStylePlain target:self action:@selector(selfInfo)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"setting"] style:UIBarButtonItemStylePlain target:self action:@selector(setting)];
    
    backButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    forwardButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forward"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    UIBarButtonItem *homeButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"home"] style:UIBarButtonItemStylePlain target:self action:@selector(goHome)];
    UIBarButtonItem *reloadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.toolbarItems = @[backButtonItem, flexibleSpaceButtonItem, forwardButtonItem, flexibleSpaceButtonItem, homeButtonItem, flexibleSpaceButtonItem, reloadButtonItem];
    
    if (_webView == nil) {
        WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
        configuration.preferences = [[WKPreferences alloc] init];
        configuration.userContentController = [[WKUserContentController alloc] init];
        
        _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
        _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _webView.backgroundColor = [UIColor whiteColor];
        _webView.navigationDelegate = self;
        _webView.UIDelegate = self;
        _webView.scrollView.delegate = self;
        [self.view addSubview:_webView];
        
        [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
        [_webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
        [_webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:nil];
    }
    
    if (_progressView == nil) {
        CGFloat progressBarHeight = 2.f;
        CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
        CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight, navigationBarBounds.size.width, progressBarHeight);
        _progressView = [[UIProgressView alloc] initWithFrame:barFrame];
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _progressView.backgroundColor = [UIColor clearColor];
        _progressView.trackTintColor = [UIColor clearColor];
        _progressView.progressTintColor = [UIColor blueColor];
    }
    
    backButtonItem.enabled = NO;
    forwardButtonItem.enabled = NO;
    [self goHome];
    
    [[DeviceManager sharedManager] addObserver:self forKeyPath:@"currentDevice" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:kNotificationDeviceConnected object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnectFailed:) name:kNotificationDeviceConnectFailed object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (_progressView) {
        [self.navigationController.navigationBar addSubview:_progressView];
    }
    [self.navigationController setToolbarHidden:NO animated:YES];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (_progressView) {
        // Remove progress view because UINavigationBar is shared with other ViewControllers
        [_progressView removeFromSuperview];
    }
    [self.navigationController setToolbarHidden:YES animated:YES];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)goBack
{
    if ([_webView canGoBack]) {
        [_webView goBack];
    }
}

- (void)goForward
{
    if ([_webView canGoForward]) {
        [_webView goForward];
    }
}

- (void)reload
{
    if ([DeviceManager sharedManager].currentDevice) {
        if ([DeviceManager sharedManager].currentDevice.isOnline) {
            if ([[DeviceManager sharedManager].currentDevice connect]) {
                if (_webView.URL && ![_webView.URL.absoluteString isEqualToString:@"about:blank"])
                {
                    [_webView reload];
                }
                else {
                    NSString *urlString = [NSString stringWithFormat:@"http://localhost:%d", [DeviceManager sharedManager].currentDevice.localPort];
                    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
                }
            }
        }
        else {
            [MBProgressHUD showToast:NSLocalizedString(@"设备不在线", nil) inView:self.view duration:3 animated:YES];
        }
    }
}

- (void)goHome
{
    NSString *urlString = nil;
    int port = [DeviceManager sharedManager].currentDevice.localPort;
    if (port > 0)
    {
        urlString = [NSString stringWithFormat:@"http://localhost:%d", port];
    }
    else if (_webView.URL != nil)
    {
        urlString = @"about:blank";
    }
    
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
}

- (void)selfInfo
{
    SelfInfoViewController *vc = [[SelfInfoViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)setting
{
    DeviceChooseViewController *vc = [[DeviceChooseViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)deviceConnected:(NSNotification *)noti
{
    Device *device = noti.object;
    if (device == [DeviceManager sharedManager].currentDevice) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self goHome];
        });
    }
}

- (void)deviceConnectFailed:(NSNotification *)noti
{
    Device *device = noti.object;
    if (device == [DeviceManager sharedManager].currentDevice) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD showToast:NSLocalizedString(@"连接设备失败", nil) inView:[UIApplication sharedApplication].delegate.window duration:3 animated:YES];
        });
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [DeviceManager sharedManager]) {
        if ([keyPath isEqualToString:@"currentDevice"]) {
            [self goHome];
        }
    }
    else if (object == _webView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([keyPath isEqualToString:@"title"]) {
                self.title = change[NSKeyValueChangeNewKey];
            }
            else if ([keyPath isEqualToString:@"estimatedProgress"]) {
                float progress = [change[NSKeyValueChangeNewKey] floatValue];
                NSLog(@"progress: %f", progress);
                [_progressView setProgress:progress animated:YES];
                if (progress >= 1.0) {
                    [UIView animateWithDuration:0.0 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                        _progressView.alpha = 0.0;
                    } completion:^(BOOL completed) {
                        _progressView.hidden = YES;
                        _progressView.progress = 0;
                    }];
                }
                else if (_progressView.hidden) {
                    _progressView.alpha = 1.0;
                    _progressView.hidden = NO;
                }
            }
            else if ([keyPath isEqualToString:@"canGoBack"]) {
                backButtonItem.enabled = [change[NSKeyValueChangeNewKey] boolValue];
            }
            else if ([keyPath isEqualToString:@"canGoForward"]) {
                forwardButtonItem.enabled = [change[NSKeyValueChangeNewKey] boolValue];
            }
        });
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark- WKNavigationDelegate
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (navigationAction.targetFrame == nil) {
        [webView loadRequest:navigationAction.request];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    if (self.navigationController.visibleViewController == self) {
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"webView:didFailProvisionalNavigation:withError: %@", error);
    [MBProgressHUD showToast:NSLocalizedString(@"页面加载失败", nil) inView:[UIApplication sharedApplication].delegate.window duration:3 animated:YES];
}

- (void)webView: (WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"webView:didFailNavigation:withError: %@", error);
}

#pragma mark- WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"取消", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark- UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (targetContentOffset->y > scrollView.contentOffset.y) {
        [self.navigationController setToolbarHidden:YES animated:YES];
    }
    else if (targetContentOffset->y < scrollView.contentOffset.y) {
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y == 0) {
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

@end
