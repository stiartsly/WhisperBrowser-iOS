//
//  Device.m
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import "Device.h"
#import "AsyncSocket.h"

static NSString * const KEY_Protocol = @"transportProtocol";
static NSString * const KEY_Service = @"portForwardingService";

@interface Device () <WMWhisperStreamDelegate>
{
    WMWhisperSession *_session;
    WMWhisperStream *_stream;
    WMWhisperStreamState _state;
    NSInteger _portForwardingID;
    int _localPort;
}

@property (nonatomic, strong) WMWhisperFriendInfo *deviceInfo;
@end

@implementation Device

- (instancetype)initWithDeviceInfo:(WMWhisperFriendInfo *)deviceInfo;
{
    if (self = [super init]) {
        _deviceInfo = deviceInfo;
        _state = 0;
        _portForwardingID = -1;
        
        NSDictionary *deviceConfig = [[NSUserDefaults standardUserDefaults] objectForKey:self.deviceId];
        if (deviceConfig) {
            NSNumber *protocol = deviceConfig[KEY_Protocol];
            if (protocol) {
                _protocol = protocol.integerValue;
            }
            else {
                _protocol = WMWhisperTransportTypeTCP;
            }

            _service = deviceConfig[KEY_Service];
            if (_service == nil) {
                _service = @"web";
            }
        }
        else {
            _protocol = WMWhisperTransportTypeTCP;
            _service = @"web";
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
    return [self.deviceInfo.presence isEqualToString:@"online"];
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
        WMWhisperSessionManager *sessionManager = [WMWhisperSessionManager getInstance];
        if (sessionManager == nil) {
            return NO;
        }

        NSError *error = nil;
        _session = [sessionManager newSessionTo:self.deviceId transport:self.protocol error:&error];
        if (_session == nil) {
            BLYLogError(@"Create session error: %@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
            return NO;
        }
    }

    if (_stream == nil) {
        WMWhisperStreamOptions options = WMWhisperStreamOptionEncrypt | WMWhisperStreamOptionMultiplexing | WMWhisperStreamOptionPortForwarding;
        if (_protocol == WMWhisperTransportTypeICE) {
            options |= WMWhisperStreamOptionReliable;
        }

        NSError *error = nil;
        _stream = [_session addStreamWithType:WMWhisperStreamTypeApplication options:options delegate:self error:&error];
        if (_stream == nil) {
            BLYLogError(@"Add stream error: %@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
            return NO;
        }

        if (_protocol != WMWhisperTransportTypeICE) {
            [self sendInviteRequest];
        }
    }
    else if (_state == WMWhisperStreamStateInitialized || _state == WMWhisperStreamStateTransportReady) {
        [self sendInviteRequest];
    }
    else if (_state == WMWhisperStreamStateConnected) {
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

- (void)setProtocol:(WMWhisperTransportType)protocol
{
    if (_protocol == protocol) {
        return;
    }

    _protocol = protocol;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *deviceConfig = [[userDefaults objectForKey:self.deviceId] mutableCopy];
    if (deviceConfig == nil) {
        deviceConfig = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    deviceConfig[KEY_Protocol] = @(protocol);
    [userDefaults setObject:deviceConfig forKey:self.deviceId];
    [userDefaults synchronize];

    [self disconnect];
    [self connect];
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

    if (_state == WMWhisperStreamStateConnected) {
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
          ^(WMWhisperSession *session, NSInteger status, NSString *reason, NSString *sdp) {
              if (session != _session || _state != WMWhisperStreamStateTransportReady) {
                  return;
              }

              if (status == 0) {
                  NSError *error = nil;
                  if (![session startWithRemoteSdp:sdp error:&error]) {
                      BLYLogError(@"Start session error: %@", error);
                      [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
                  }
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

- (void)openPortForwarding
{
    NSError *error = nil;
    uint16_t localPort = [self getAvailableLocalPort:&error];
    if (localPort == 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
        return;
    }

    NSNumber *portForwarding = [_stream openPortForwardingForService:self.service
                                                       withProtocol:WMPortForwardingProtocolTCP
                                                               host:@"localhost"
                                                               port:[@(localPort) stringValue]
                                                              error:&error];
    if (portForwarding) {
        _portForwardingID = portForwarding.integerValue;
        _localPort = localPort;
        BLYLogInfo(@"Success to open port forwarding : %d, loacl port : %d", (int)_portForwardingID, localPort);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnected object:self userInfo:nil];
    }
    else {
        BLYLogError(@"Open port forwarding error: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:@{@"error": error}];
    }
}

#pragma mark - ECSSessionDelegate
- (void)whisperStream:(WMWhisperStream *)stream stateDidChange:(enum WMWhisperStreamState)newState
{
    BLYLogInfo(@"Stream state: %d", (int)newState);

    if (stream != _stream || _state < 0) {
        return;
    }

    _state = newState;

    switch (newState) {
        case WMWhisperStreamStateInitialized:
            [self sendInviteRequest];
            break;

        case WMWhisperStreamStateConnected:
            [self openPortForwarding];
            break;

        case WMWhisperStreamStateDeactivated:
        case WMWhisperStreamStateClosed:
        case WMWhisperStreamStateError:
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeviceConnectFailed object:self userInfo:nil];
            [self disconnect];
            break;

        default:
            break;
    }
}

@end
