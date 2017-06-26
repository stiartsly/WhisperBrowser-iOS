//
//  PrefixHeader.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#ifndef PrefixHeader_H
#define PrefixHeader_H

// Include any system framework and library headers here that should be included in all compilation units.
// You will also need to set the Prefix Header build setting of one or more of your targets to reference this file.

#import <ManagedWhisper/ManagedWhisper.h>
#import <Bugly/Bugly.h>
#import "DeviceManager.h"
#import "MBProgressHUD.h"

#define weakSelf(self)  __weak __typeof(self)weakSelf = self
#define strongSelf(weakSelf)    __strong __typeof(weakSelf)strongSelf = weakSelf

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#endif
