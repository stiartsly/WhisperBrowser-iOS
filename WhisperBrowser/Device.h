//
//  Device.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kNotificationDeviceConnected        @"kNotificationDeviceConnected"
#define kNotificationDeviceConnectFailed    @"kNotificationDeviceConnectFailed"

@interface Device : NSObject

@property (nonatomic, strong, readonly) WMWhisperFriendInfo *deviceInfo;
@property (nonatomic, strong, readonly) NSString *deviceId;
@property (nonatomic, strong, readonly) NSString *deviceName;
@property (nonatomic, assign, readonly) BOOL isOnline;

@property (nonatomic, assign) WMWhisperTransportType protocol;
@property (nonatomic, strong) NSString *service;
@property (nonatomic, assign, readonly) int localPort;

- (instancetype)initWithDeviceInfo:(WMWhisperFriendInfo *)deviceInfo;

- (BOOL)connect;
- (void)disconnect;

@end
