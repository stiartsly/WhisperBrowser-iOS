#import "Device.h"
#import "AsyncSocket.h"

static NSString * const KEY_Service = @"portForwardingService";

@interface Device () <NTWhisperStreamDelegate>
{
    NTWhisperSession *_session;
    NTWhisperStream *_stream;
    NTWhisperStreamState _state;
    NSInteger _portForwardingID;
    int _localPort;
    BOOL _didReceivedConfirmResponse;
    NSString *_sdp;
}

@property (nonatomic, strong) NTWhisperFriendInfo *deviceInfo;
@end

@implementation Device

- (instancetype)initWithDeviceInfo:(NTWhisperFriendInfo *)deviceInfo;
{
    if (self = [super init]) {
        _deviceInfo = deviceInfo;
        _state = 0;
        _portForwardingID = -1;
        _didReceivedConfirmResponse = FALSE;
        _sdp = nil;

        NSDictionary *deviceConfig = [[NSUserDefaults standardUserDefaults] objectForKey:self.deviceId];
        if (deviceConfig) {
            _service = deviceConfig[KEY_Service];
            if (_service == nil) {
                _service = defaultService;
            }
        }
        else {
            _service = defaultService;
        }
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (NSString *)deviceId
{
    return self.deviceInfo.userId;
}

- (NSString *)deviceName
{
    NSString *deviceName = self.deviceInfo.label;
    if (deviceName.length == 0) {
        deviceName = self.deviceInfo.name;
        if (deviceName.length == 0) {
            deviceName = self.deviceInfo.userId;
        }
    }
    return deviceName;
}

- (BOOL)isOnline
{
    return (self.deviceInfo.status == NTWhisperConnectionStatusConnected);
}

- (BOOL)connect
{
    if (!self.isOnline) {
        return NO;
    }

    if (_localPort > 0) {
        return YES;
    }

    if (_session == nil) {
        NTWhisperSessionManager *sessionManager = [NTWhisperSessionManager getInstance];
        if (sessionManager == nil) {
            return NO;
        }

        NSString *plistPath = [[NSBundle mainBundle]pathForResource:@"Config" ofType:@"plist"];
        NSDictionary *config = [[NSDictionary alloc]initWithContentsOfFile:plistPath];

        NTIceTransportOptions *iceOptions = [[NTIceTransportOptions alloc] init];
        [iceOptions setStunHost:config[@"StunServer"]];
        [iceOptions setTurnHost:config[@"TurnServer"]];
        [iceOptions setTurnUsername:config[@"TurnUserName"]];
        [iceOptions setTurnPassword:config[@"TurnPassword"]];
        [iceOptions setThreadModel:NTTransportOptions.SharedThreadModel];

        NSError *error = nil;
        _session = [sessionManager newSessionTo:self.deviceId:iceOptions error:&error];
        if (_session == nil) {
            BLYLogError(@"Create session error: %@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
            return NO;
        }
    }

    if (_stream == nil) {
        NTWhisperStreamOptions options = NTWhisperStreamOptionMultiplexing | NTWhisperStreamOptionPortForwarding | NTWhisperStreamOptionReliable;

        NSError *error = nil;
        _stream = [_session addStreamWithType:NTWhisperStreamTypeApplication options:options delegate:self error:&error];
        if (_stream == nil) {
            BLYLogError(@"Add stream error: %@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
            return NO;
        }
    }
    else if (_state == NTWhisperStreamStateInitialized || _state == NTWhisperStreamStateTransportReady) {
        [self sendInviteRequest];
    }
    else if (_state == NTWhisperStreamStateConnected) {
        [self openPortForwarding];
    }

    return NO;
}

- (void)disconnect
{
    _localPort = 0;

    if (_session) {
        _state = -1;

        if (_stream) {
            NSError *error = nil;

            if (_portForwardingID >= 0) {
                if (![_stream closePortForwarding:_portForwardingID error:&error]) {
                    BLYLogError(@"Close port forwarding error: %@", error);
                }
                _portForwardingID = -1;
            }

            if (![_session removeStream:_stream error:&error]) {
                BLYLogError(@"Remove stream error: %@", error);
            }
            _stream = nil;
        }

        [_session close];
        _session = nil;
        _state = 0;
    }
}

- (void)setService:(NSString *)service
{
    if (_service.length == 0) {
        return;
    }

    if ([_service isEqualToString:service]) {
        return;
    }

    _service = service;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *deviceConfig = [[userDefaults objectForKey:self.deviceId] mutableCopy];
    if (deviceConfig == nil) {
        deviceConfig = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    deviceConfig[KEY_Service] = service;
    [userDefaults setObject:deviceConfig forKey:self.deviceId];
    [userDefaults synchronize];
    
    if (_localPort > 0) {
        _localPort = 0;

        NSError *error = nil;
        if (![_stream closePortForwarding:_portForwardingID error:&error]) {
            BLYLogError(@"Close port forwarding error: %@", error);
        }
        _portForwardingID = -1;
    }

    if (_state == NTWhisperStreamStateConnected) {
        [self openPortForwarding];
    }
}

- (uint16_t)getAvailableLocalPort:(NSError * __autoreleasing *)error
{
    static AsyncSocket *asyncSocket;
    static dispatch_once_t onceTag;
    dispatch_once(&onceTag, ^{
        asyncSocket = [[AsyncSocket alloc] init];
    });
    asyncSocket.delegate = self;
    
    uint16_t localPort = 0;
    if ([asyncSocket acceptOnInterface:@"127.0.0.1" port:0 error:error]) {
        localPort = [asyncSocket localPort];
        BLYLogInfo(@"localPort: %d", localPort);
        [asyncSocket disconnect];
    } else {
        BLYLogError(@"Get free localPort failed: %@", *error);
    }
    
    return localPort;
}

- (void)sendInviteRequest
{
    NSError *error = nil;
    if (![_session sendInviteRequestWithResponseHandler:
          ^(NTWhisperSession *session, NSInteger status, NSString *reason, NSString *sdp) {
              if (session != _session || _state != NTWhisperStreamStateTransportReady) {
                  return;
              }

              if (status == 0) {
                _didReceivedConfirmResponse = TRUE;
                _sdp = sdp;
              }
              else {
                  BLYLogWarn(@"Remote refused session invite: %d, sdp: %@", (int)status, reason);
                  [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:nil];
              }
          } error:&error]) {
              BLYLogError(@"Session send invite request error: %@", error);
              [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
          }
}

- (void)startSession
{
    NSError *error = nil;
    if (![_session startWithRemoteSdp:_sdp error:&error]) {
        BLYLogError(@"Start session error: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
    } else {
        BLYLogInfo(@"Start session success");
    }
}

- (void)openPortForwarding
{
    NSError *error = nil;
    uint16_t localPort = [self getAvailableLocalPort:&error];
    if (localPort == 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
        return;
    }

    NSNumber *portForwarding = [_stream openPortForwardingForService:self.service
                                                       withProtocol:NTPortForwardingProtocolTCP
                                                               host:@"localhost"
                                                               port:[@(localPort) stringValue]
                                                              error:&error];
    if (portForwarding) {
        _portForwardingID = portForwarding.integerValue;
        _localPort = localPort;
        BLYLogInfo(@"Success to open port %@ forwarding : %d, local port : %d", self.service, (int)_portForwardingID, localPort);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnected object:self userInfo:nil];
    }
    else {
        BLYLogError(@"Open port forwarding error: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
    }
}

#pragma mark - ECSessionDelegate
- (void)whisperStream:(NTWhisperStream *)stream stateDidChange:(enum NTWhisperStreamState)newState
{
    BLYLogInfo(@"Stream state: %d", (int)newState);

    if (stream != _stream || _state < 0) {
        return;
    }

    _state = newState;

    switch (newState) {
        case NTWhisperStreamStateInitialized:
            [self sendInviteRequest];
            break;

        case NTWhisperStreamStateTransportReady:
            while (!_didReceivedConfirmResponse) {
                [NSThread sleepForTimeInterval:0.2];
            }
            [self startSession];
            //TODO:
            break;

        case NTWhisperStreamStateConnected:
            [self openPortForwarding];
            break;

        case NTWhisperStreamStateDeactivated:
        case NTWhisperStreamStateClosed:
        case NTWhisperStreamStateError:
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:nil];
            [self disconnect];
            break;

        default:
            break;
    }
}

@end
