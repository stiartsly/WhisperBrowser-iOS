//
//  DeviceManager.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Device.h"

#define kNotificationDeviceListUpdated      @"kNotificationDeviceListUpdated"
#define kNotificationSelfInfoUpdated        @"kNotificationSelfInfoUpdated"

@interface DeviceManager : NSObject

@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) WMWhisperUserInfo *selfInfo;
@property (nonatomic, strong, readonly) NSArray *devices;
@property (nonatomic, strong) Device *currentDevice;

+ (DeviceManager *)sharedManager;

- (void)login:(NSString *)username
     password:(NSString *)password
   completion:(void (^)(NSError *error))completion;

- (void)logout;

- (BOOL)setDeviceLabel:(Device *)device
              newLabel:(NSString *)newLabel
                 error:(NSError **)error;

- (BOOL)pairWithDevice:(NSString *)deviceID
              passWord:(NSString *)password
                 error:(NSError **)error;

- (BOOL)unPairDevice:(Device *)device
               error:(NSError **)error;

@end
