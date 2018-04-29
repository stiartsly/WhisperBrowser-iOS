#import "DeviceManager.h"

static NSString * const KEY_Username = @"username";
static NSString * const KEY_SelfIdentifier = @"selfIdentifier";
static NSString * const KEY_CurrentDeviceId = @"currentDeviceIdentifier";

@interface DeviceManager () <WHWhisperDelegate>
{
    BOOL initializerd;
    WHWhisper *whisperInstance;
    WHWhisperConnectionStatus connectStatus;
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
        connectStatus = WHWhisperConnectionStatusDisconnected;
        managerDeviceQueue = dispatch_queue_create("managerDeviceQueue", NULL);
        [WHWhisper setLogLevel:WHWhisperLogLevelDebug];

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
    if (initializerd) {
        return;
    }
    
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
                    connectStatus = WHWhisperConnectionStatusDisconnected;
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

            WHWhisperOptions *options = [[WHWhisperOptions alloc] init];
            [options setAppId:APP_ID andKey:APP_KEY];
            [options setLogin:username andPassword:password];
            [options setApiServerUrl: API_SERVER];
            [options setMqttServerUri: MQTT_SERVER];
            [options setTrustStore: [[NSBundle mainBundle] pathForResource:@"whisper" ofType:@"pem"]];
            [options setPersistentLocation: whisperDirectory];
            [options setDeviceId: deviceId];
            [options setConnectTimeout: 5];

            whisperInstance = [WHWhisper getInstanceWithOptions:options delegate:self error:&error];
            if (whisperInstance == nil) {
                BLYLogError(@"Create whisper instance failed: %@", error);
                connectStatus = WHWhisperConnectionStatusDisconnected;
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
            connectStatus = WHWhisperConnectionStatusDisconnected;
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

    [[WHWhisperSessionManager getInstance] cleanup];
    [whisperInstance kill];
    whisperInstance = nil;

    initializerd = NO;
    connectStatus = WHWhisperConnectionStatusDisconnected;
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
    if ([whisperInstance addFriendWith:deviceID withGreeting:password error:&err]) {
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

- (WHWhisperUserInfo *)selfInfo
{
    return [whisperInstance getSelfUserInfo:nil];
}

#pragma mark - WHWhisperDelegate

//- (void)whisperWillBecomeIdle:(WHWhisper * _Nonnull) whisper
//{
//    BLYLogDebug(@"whisperWillBecomeIdle");
//}

- (void)whisper:(WHWhisper *)whisper connectionStatusDidChange:(enum WHWhisperConnectionStatus)newStatus
{
    BLYLogInfo(@"connectionStatusDidChange : %d", (int)newStatus);
    connectStatus = newStatus;

    if (connectStatus == WHWhisperConnectionStatusDisconnected) {
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

- (void)whisperDidBecomeReady:(WHWhisper *)whisper
{
    BLYLogInfo(@"didBecomeReady");
    WHWhisperUserInfo *selfInfo = [whisper getSelfUserInfo:nil];
    if (selfInfo.name.length == 0) {
        selfInfo.name = [UIDevice currentDevice].name;
        [whisper setSelfUserInfo:selfInfo error:nil];
    }

    [WHWhisperSessionManager getInstance:whisper error:nil];

    WHIceTransportOptions *iceOptions = [[WHIceTransportOptions alloc] init];
    [iceOptions setStunHost:STUN_SERVER];
    [iceOptions setTurnHost:TURN_SERVER];
    [iceOptions setTurnUsername:TURN_USERNAME];
    [iceOptions setTurnPassword:TURN_PASSWORD];
    [iceOptions setThreadModel:WHTransportOptions.SharedThreadModel];
    [[WHWhisperSessionManager getInstance] addTransport:iceOptions error:nil];

    WHUdpTransportOptions *udpOptions = [[WHUdpTransportOptions alloc] init];
    [udpOptions setHost: @"localhost"];
    [udpOptions setThreadModel:WHTransportOptions.SharedThreadModel];
    [[WHWhisperSessionManager getInstance] addTransport:udpOptions error:nil];

    WHTcpTransportOptions *tcpOptions = [[WHTcpTransportOptions alloc] init];
    [tcpOptions setHost: @"localhost"];
    [tcpOptions setThreadModel:WHTransportOptions.SharedThreadModel];
    [[WHWhisperSessionManager getInstance] addTransport:tcpOptions error:nil];

    [self.currentDevice connect];
}

- (void)whisper:(WHWhisper *)whisper selfUserInfoDidChange:(WHWhisperUserInfo *)newInfo
{
    BLYLogInfo(@"selfUserInfoDidChange : %@", newInfo);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSelfInfoUpdated object:newInfo userInfo:nil];
}

- (void)whisper:(WHWhisper *)whisper didReceiveFriendsList:(NSArray<WHWhisperFriendInfo *> *)friends
{
    BLYLogInfo(@"didReceiveFriendsList : %@", friends);

    NSString *savedDeviceId = [[NSUserDefaults standardUserDefaults] objectForKey:KEY_CurrentDeviceId];

    for (WHWhisperFriendInfo *friend in friends) {
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

- (void)whisper:(WHWhisper *)whisper friendInfoDidChange:(NSString *)friendId newInfo:(WHWhisperFriendInfo *)newInfo
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

- (void)whisper:(WHWhisper *)whisper friendConnectionDidChange:(NSString *)friendId newStatus:(enum WHWhisperConnectionStatus)newStatus
{
    BLYLogInfo(@"friendConnectionDidChange, userId : %@, newStatus : %@", friendId, newStatus);
    for (Device *device in devices) {
        if ([device.deviceId isEqual:friendId]) {
            device.deviceInfo.status = newStatus;
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

- (void)whisper:(WHWhisper *)whisper didReceiveFriendRequestFromUser:(NSString *)userId withUserInfo:(WHWhisperUserInfo *)userInfo hello:(NSString *)hello
{
    BLYLogInfo(@"didReceiveFriendRequestFromUser, userId : %@", userId);
}

- (void)whisper:(WHWhisper *)whisper didReceiveFriendResponseFromUser:(NSString *)userId withStatus:(NSInteger)status reason:(NSString *)reason entrusted:(BOOL)entrusted expire:(NSString *)expire
{
    BLYLogInfo(@"didReceiveFriendResponseFromUser, userId : %@, status : %d, reason: %@", userId, (int)status, reason);
}

- (void)whisper:(WHWhisper *)whisper newFriendAdded:(WHWhisperFriendInfo *)newFriend
{
    BLYLogInfo(@"newFriendAdded : %@", newFriend);
    Device *device = [[Device alloc] initWithDeviceInfo:newFriend];
    [devices addObject:device];
    if (self.currentDevice == nil) {
        self.currentDevice = device;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceListUpdated object:nil userInfo:nil];
}

- (void)whisper:(WHWhisper *)whisper friendRemoved:(NSString *)friendId
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
