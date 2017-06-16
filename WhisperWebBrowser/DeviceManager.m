//
//  DeviceManager.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import "DeviceManager.h"

static NSString * const APP_ID = @"7sRQjDsniyuHdZ9zsQU9DZbMLtQGLBWZ78yHWgjPpTKm";
static NSString * const APP_KEY = @"6tzPPAgSACJdScX79wuzMNPQTWkRLZ4qEdhLcZU6q4B9";

static NSString * const API_SERVER = @"https://whisper.freeddns.org:8443/web/api";
static NSString * const MQTT_SERVER = @"ssl://whisper.freeddns.org:8883";
static NSString * const STUN_SERVER = @"whisper.freeddns.org";
static NSString * const TURN_SERVER = @"whisper.freeddns.org";
static NSString * const TURN_USERNAME = @"whisper";
static NSString * const TURN_PASSWORD = @"io2016whisper";

static NSString * const KEY_CurrentDeviceId = @"currentDeviceIdentifier";

@interface DeviceManager () <WMWhisperDelegate>
{
    BOOL initializerd;
    WMWhisper *whisperInstance;
    WMWhisperConnectionStatus connectStatus;
    NSMutableArray *devices;
    Device *currentDevice;
    dispatch_queue_t managerDeviceQueue;
}
@end

@implementation DeviceManager

+ (DeviceManager *)sharedManager
{
    static DeviceManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

-(instancetype)init {
    if (self = [super init]) {
        initializerd = NO;
        connectStatus = WMWhisperConnectionStatusDisconnected;
        managerDeviceQueue = dispatch_queue_create("managerDeviceQueue", NULL);
        [WMWhisper setLogLevel:WMWhisperLogLevelDebug];
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    if (initializerd || connectStatus == WMWhisperConnectionStatusConnecting) {
        return;
    }
    
    connectStatus = WMWhisperConnectionStatusConnecting;
    
    dispatch_async(managerDeviceQueue, ^{
        NSError *error = nil;
        if (whisperInstance == nil) {
            NSString *whisperDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"whisper"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:whisperDirectory]) {
                NSURL *url = [NSURL fileURLWithPath:whisperDirectory];
                if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error]) {
                    NSLog(@"Create whisper persistent directory failed: %@", error);
                    return;
                }

                [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
            }

            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSString *deviceId = [userDefaults stringForKey:@"selfIdentifier"];
            if (deviceId == nil) {
                deviceId = [[UIDevice currentDevice] identifierForVendor].UUIDString;
                [userDefaults setObject:deviceId forKey:@"selfIdentifier"];
                [userDefaults synchronize];
            }

            WMWhisperOptions *options = [[WMWhisperOptions alloc] init];
            [options setAppId:APP_ID andKey:APP_KEY];
            options.apiServerUrl = API_SERVER;
            options.mqttServerUri = MQTT_SERVER;
            options.trustStore = [[NSBundle mainBundle] pathForResource:@"whisper" ofType:@"pem"];
            options.persistentLocation = whisperDirectory;
            options.deviceId = deviceId;
            options.connectTimeout = 5;

            whisperInstance = [WMWhisper getInstanceWithOptions:options delegate:self error:&error];
            if (whisperInstance == nil) {
                NSLog(@"Create whisper instance failed: %@", error);
                return;
            }
        }

        initializerd = [whisperInstance startWithIterateInterval:1000 error:&error];
        if (initializerd) {
            devices = [[NSMutableArray alloc] init];
        }
        else {
            connectStatus = WMWhisperConnectionStatusDisconnected;
            NSLog(@"Start whisper instance failed: %@", error);
        }
    });
}

- (NSArray *)devices
{
    if (devices == nil) {
        [self initialize];
    }

    return devices;
}

- (Device *)currentDevice
{
    if (currentDevice == nil) {
        [self initialize];
    }

    return currentDevice;
}

- (void)setCurrentDevice:(Device *)device
{
    if (device == nil) {
        currentDevice = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:KEY_CurrentDeviceId];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else if (device != currentDevice && [devices containsObject:device]) {
        currentDevice = device;
        [[NSUserDefaults standardUserDefaults] setObject:device.deviceId forKey:KEY_CurrentDeviceId];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [currentDevice connect];
    }
}

- (BOOL)setDeviceLabel:(Device *)device
              newLabel:(NSString *)newLabel
                 error:(NSError *__autoreleasing *)error
{
    return [whisperInstance setLabelForFriend:device.deviceId withLabel:newLabel error:error];
}

- (BOOL)pairWithDevice:(NSString *)deviceID
              passWord:(NSString *)password
                 error:(NSError *__autoreleasing *)error
{
    NSError *err = nil;
    if ([whisperInstance sendFriendRequestTo:deviceID withGreeting:password error:&err]) {
        return NO;
    }

    if (err.code == 0x8100000C) {
        return YES;
    }

    *error = err;
    return NO;
}

- (BOOL)unPairDevice:(Device *)device
               error:(NSError *__autoreleasing *)error
{
    return [whisperInstance removeFriend:device.deviceId error:error];
}

#pragma mark - WMWhisperDelegate

- (void)whisper:(WMWhisper *)whisper connectionStatusDidChange:(enum WMWhisperConnectionStatus)newStatus
{
    NSLog(@"connectionStatusDidChange : %d", (int)newStatus);
    connectStatus = newStatus;

    if (connectStatus == WMWhisperConnectionStatusDisconnected) {
        for (Device *device in devices) {
            [device disconnect];
        }

        [devices removeAllObjects];
        currentDevice = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            [MBProgressHUD showToast:NSLocalizedString(@"连接服务器失败", nil) inView:[UIApplication sharedApplication].delegate.window duration:3 animated:YES];
        }
    }
}

- (void)whisperDidBecomeReady:(WMWhisper *)whisper
{
    NSLog(@"didBecomeReady");
    WMWhisperUserInfo *selfInfo = [whisper getSelfUserInfo:nil];
    if (selfInfo.name.length == 0) {
        selfInfo.name = [UIDevice currentDevice].name;
        [whisper setSelfUserInfo:selfInfo error:nil];
    }

    WMWhisperSessionManagerOptions *options = [[WMWhisperSessionManagerOptions alloc] initWithTransports:WMWhisperTransportOptionICE | WMWhisperTransportOptionTCP];
    options.stunServer = STUN_SERVER;
    options.turnServer = TURN_SERVER;
    options.turnUsername = TURN_USERNAME;
    options.turnPassword = TURN_PASSWORD;
    [WMWhisperSessionManager getInstance:whisper withOptions:options error:nil];

    [self.currentDevice connect];
}

- (void)whisper:(WMWhisper *)whisper selfUserInfoDidChange:(WMWhisperUserInfo *)newInfo
{
    NSLog(@"selfUserInfoDidChange : %@", newInfo);
}

- (void)whisper:(WMWhisper *)whisper didReceiveFriendsList:(NSArray<WMWhisperFriendInfo *> *)friends
{
    NSLog(@"didReceiveFriendsList : %@", friends);

    NSString *savedDeviceId = [[NSUserDefaults standardUserDefaults] objectForKey:KEY_CurrentDeviceId];

    for (WMWhisperFriendInfo *friend in friends) {
        Device *device = [[Device alloc] initWithDeviceInfo:friend];
        [devices addObject:device];

        if ([device.deviceId isEqualToString:savedDeviceId]) {
            self.currentDevice = device;
        }
    }

    if (self.currentDevice == nil) {
        for (Device *device in devices) {
            if (device.isOnline) {
                self.currentDevice = device;
                break;
            }
        }

        if (self.currentDevice == nil) {
            self.currentDevice = devices[0];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
}

- (void)whisper:(WMWhisper *)whisper friendInfoDidChange:(NSString *)friendId newInfo:(WMWhisperFriendInfo *)newInfo
{
    NSLog(@"friendInfoDidChange : %@", newInfo);
    for (Device *device in devices) {
        if ([device.deviceId isEqual:friendId]) {
            [device performSelector:@selector(setDeviceInfo:) withObject:newInfo];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
            break;
        }
    }
}

- (void)whisper:(WMWhisper *)whisper friendPresenceDidChange:(NSString *)friendId newPresence:(NSString *)newPresence
{
    NSLog(@"friendPresenceDidChange, userId : %@, newPresence : %@", friendId, newPresence);
    for (Device *device in devices) {
        if ([device.deviceId isEqual:friendId]) {
            device.deviceInfo.presence = newPresence;
            if (device.isOnline) {
                if (self.currentDevice == nil) {
                    self.currentDevice = device;
                }
                else if (self.currentDevice == device) {
                    [device connect];
                }
            }
            else {
                [device disconnect];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
            break;
        }
    }
}

- (void)whisper:(WMWhisper *)whisper didReceiveFriendRequestFromUser:(NSString *)userId withUserInfo:(WMWhisperUserInfo *)userInfo hello:(NSString *)hello
{
    NSLog(@"didReceiveFriendRequestFromUser, userId : %@", userId);
}

- (void)whisper:(WMWhisper *)whisper didReceiveFriendResponseFromUser:(NSString *)userId withStatus:(NSInteger)status reason:(NSString *)reason entrusted:(BOOL)entrusted expire:(NSString *)expire
{
    NSLog(@"didReceiveFriendResponseFromUser, userId : %@, status : %d, reason: %@", userId, (int)status, reason);
}

- (void)whisper:(WMWhisper *)whisper newFriendAdded:(WMWhisperFriendInfo *)newFriend
{
    NSLog(@"newFriendAdded : %@", newFriend);
    Device *device = [[Device alloc] initWithDeviceInfo:newFriend];
    [devices addObject:device];
    if (self.currentDevice == nil) {
        self.currentDevice = device;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
}

- (void)whisper:(WMWhisper *)whisper friendRemoved:(NSString *)friendId
{
    for (Device *device in devices) {
        if ([device.deviceId isEqual:friendId]) {
            [device disconnect];
            [devices removeObject:device];

            if (self.currentDevice == device) {
                self.currentDevice = nil;

                if (devices.count > 0) {
                    for (Device *device in devices) {
                        if (device.isOnline) {
                            self.currentDevice = device;
                            break;
                        }
                    }

                    if (self.currentDevice == nil) {
                        self.currentDevice = devices[0];
                    }
                }
            }

            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
            break;
        }
    }
}

@end
