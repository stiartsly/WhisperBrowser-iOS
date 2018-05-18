#ifndef PrefixHeader_h
#define PrefixHeader_h

#if USE_VANILLA
#import <WhisperVanilla/WhisperVanilla.h>
#endif

#import <Bugly/Bugly.h>
#import "DeviceManager.h"
#import "MBProgressHUD.h"

#define weakSelf(self)  __weak __typeof(self)weakSelf = self
#define strongSelf(weakSelf)    __strong __typeof(weakSelf)strongSelf = weakSelf

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

static NSString * const defaultService = @"web";
static NSString * const Bugly_APP_ID = @"9dc9b11a50";

#endif /* PrefixHeader_h */
