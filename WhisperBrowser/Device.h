#import <Foundation/Foundation.h>
#if USE_VANILLA
#import <WhisperVanilla/WhisperVanilla.h>
#endif

#define kNotificationDeviceConnected        @"kNotificationDeviceConnected"
#define kNotificationDeviceConnectFailed    @"kNotificationDeviceConnectFailed"

@interface Device : NSObject

@property (nonatomic, strong, readonly) NTWhisperFriendInfo *deviceInfo;
@property (nonatomic, strong, readonly) NSString *deviceId;
@property (nonatomic, strong, readonly) NSString *deviceName;
@property (nonatomic, assign, readonly) BOOL isOnline;

@property (nonatomic, strong) NSString *service;
@property (nonatomic, assign, readonly) int localPort;

- (instancetype)initWithDeviceInfo:(NTWhisperFriendInfo *)deviceInfo;

- (BOOL)connect;
- (void)disconnect;

@end
