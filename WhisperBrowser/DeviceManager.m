//
//  DeviceManager.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import "DeviceManager.h"

static NSString * const KEY_Username = @"username";
static NSString * const KEY_SelfIdentifier = @"selfIdentifier";
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

- (instancetype)init {
    if (self = [super init]) {
        initializerd = NO;
        connectStatus = WMWhisperConnectionStatusDisconnected;
        managerDeviceQueue = dispatch_queue_create("managerDeviceQueue", NULL);
        [WMWhisper setLogLevel:WMWhisperLogLevelDebug];

        _username = [[NSUserDefaults standardUserDefaults] stringForKey:KEY_Username];
        if (_username) {
            [self login:_username password:nil completion:nil];
        }
        else {
            [self checkNetworkConnection];
        }
    }
    return self;
}

- (void)checkNetworkConnection
{
    NSURL *url = [NSURL URLWithString:[API_SERVER stringByAppendingString:@"/version"]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:3];
    NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:nil delegateQueue:nil];
    [[urlSession dataTaskWithRequest:urlRequest] resume];
}

- (void)login:(NSString *)username password:(NSString *)password completion:(void (^)(NSError *error))completion
{
    if (initializerd || connectStatus == WMWhisperConnectionStatusConnecting) {
        return;
    }
    
    connectStatus = WMWhisperConnectionStatusConnecting;
    
    dispatch_async(managerDeviceQueue, ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSError *error = nil;
        if (whisperInstance == nil) {
#ifdef _INTERNAL_
            NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
#else
            NSString *directory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
#endif
            NSString *whisperDirectory = [directory stringByAppendingPathComponent:@"whisper"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:whisperDirectory]) {
                NSURL *url = [NSURL fileURLWithPath:whisperDirectory];
                if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error]) {
                    BLYLogError(@"Create whisper persistent directory failed: %@", error);
                    connectStatus = WMWhisperConnectionStatusDisconnected;
                    if (completion) {
                        completion(error);
                    }
                    return;
                }

                [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
            }
            else if (password) {
                NSArray *subPaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:whisperDirectory error:nil];
                for (NSString *path in subPaths) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
            }

            NSString *deviceId = [userDefaults stringForKey:KEY_SelfIdentifier];
            if (deviceId == nil) {
                deviceId = [[UIDevice currentDevice] identifierForVendor].UUIDString;
                [userDefaults setObject:deviceId forKey:KEY_SelfIdentifier];
                [userDefaults synchronize];
            }

            WMWhisperOptions *options = [[WMWhisperOptions alloc] init];
            [options setAppId:APP_ID andKey:APP_KEY];
            [options setLogin:username andPassword:password];
            options.apiServerUrl = API_SERVER;
            options.mqttServerUri = MQTT_SERVER;
            options.trustStore = [[NSBundle mainBundle] pathForResource:@"whisper" ofType:@"pem"];
            options.persistentLocation = whisperDirectory;
            options.deviceId = deviceId;
            options.connectTimeout = 5;

            whisperInstance = [WMWhisper getInstanceWithOptions:options delegate:self error:&error];
            if (whisperInstance == nil) {
                BLYLogError(@"Create whisper instance failed: %@", error);
                connectStatus = WMWhisperConnectionStatusDisconnected;
                if (completion) {
                    completion(error);
                }
                return;
            }
        }

        initializerd = [whisperInstance startWithIterateInterval:1000 error:&error];
        if (initializerd) {
            [userDefaults setObject:username forKey:KEY_Username];
            [userDefaults synchronize];

            _username = username;
            devices = [[NSMutableArray alloc] init];
        }
        else {
            BLYLogError(@"Start whisper instance failed: %@", error);
            [whisperInstance kill];
            whisperInstance == nil;
            connectStatus = WMWhisperConnectionStatusDisconnected;
        }

        if (completion) {
            completion(error);
        }
    });
}

- (void)logout
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KEY_Username];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _username = nil;

    [self cleanup];

#ifdef _INTERNAL_
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
#else
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
#endif
    NSString *whisperDirectory = [directory stringByAppendingPathComponent:@"whisper"];
    [[NSFileManager defaultManager] removeItemAtPath:whisperDirectory error:nil];
}

- (void)cleanup
{
    for (Device *device in devices) {
        [device disconnect];
    }

    devices = nil;
    currentDevice = nil;

    [[WMWhisperSessionManager getInstance] cleanup];
    [whisperInstance kill];
    whisperInstance = nil;

    initializerd = NO;
    connectStatus = WMWhisperConnectionStatusDisconnected;
}

- (NSArray *)devices
{
    return devices;
}

- (Device *)currentDevice
{
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

    if (err.code == 0x100000C) {
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

- (WMWhisperUserInfo *)selfInfo
{
    return [whisperInstance getSelfUserInfo:nil];
}

#pragma mark - WMWhisperDelegate

//- (void)whisperWillBecomeIdle:(WMWhisper * _Nonnull)whisper
//{
//    BLYLogDebug(@"whisperWillBecomeIdle");
//}

- (void)whisper:(WMWhisper *)whisper connectionStatusDidChange:(enum WMWhisperConnectionStatus)newStatus
{
    BLYLogInfo(@"connectionStatusDidChange : %d", (int)newStatus);
    connectStatus = newStatus;

    if (connectStatus == WMWhisperConnectionStatusDisconnected) {
        for (Device *device in devices) {
            [device disconnect];
        }

        [devices removeAllObjects];
        currentDevice = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD showToast:NSLocalizedString(@"连接服务器失败", nil) inView:[UIApplication sharedApplication].delegate.window duration:3 animated:YES];
            });
        }
    }
}

- (void)whisperDidBecomeReady:(WMWhisper *)whisper
{
    BLYLogInfo(@"didBecomeReady");
    WMWhisperUserInfo *selfInfo = [whisper getSelfUserInfo:nil];
    if (selfInfo.name.length == 0) {
        selfInfo.name = [UIDevice currentDevice].name;
        [whisper setSelfUserInfo:selfInfo error:nil];
    }

    WMWhisperSessionManagerOptions *options = [[WMWhisperSessionManagerOptions alloc] initWithTransports:
                                               WMWhisperTransportOptionICE | WMWhisperTransportOptionUDP | WMWhisperTransportOptionTCP];
    options.stunHost = STUN_SERVER;
    options.turnHost = TURN_SERVER;
    options.turnUsername = TURN_USERNAME;
    options.turnPassword = TURN_PASSWORD;
    [WMWhisperSessionManager getInstance:whisper withOptions:options error:nil];

    [self.currentDevice connect];
}

- (void)whisper:(WMWhisper *)whisper selfUserInfoDidChange:(WMWhisperUserInfo *)newInfo
{
    BLYLogInfo(@"selfUserInfoDidChange : %@", newInfo);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSelfInfoUpdated object:newInfo userInfo:nil];
}

- (void)whisper:(WMWhisper *)whisper didReceiveFriendsList:(NSArray<WMWhisperFriendInfo *> *)friends
{
    BLYLogInfo(@"didReceiveFriendsList : %@", friends);

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
    BLYLogInfo(@"friendInfoDidChange : %@", newInfo);
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
    BLYLogInfo(@"friendPresenceDidChange, userId : %@, newPresence : %@", friendId, newPresence);
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
    BLYLogInfo(@"didReceiveFriendRequestFromUser, userId : %@", userId);
}

- (void)whisper:(WMWhisper *)whisper didReceiveFriendResponseFromUser:(NSString *)userId withStatus:(NSInteger)status reason:(NSString *)reason entrusted:(BOOL)entrusted expire:(NSString *)expire
{
    BLYLogInfo(@"didReceiveFriendResponseFromUser, userId : %@, status : %d, reason: %@", userId, (int)status, reason);
}

- (void)whisper:(WMWhisper *)whisper newFriendAdded:(WMWhisperFriendInfo *)newFriend
{
    BLYLogInfo(@"newFriendAdded : %@", newFriend);
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
