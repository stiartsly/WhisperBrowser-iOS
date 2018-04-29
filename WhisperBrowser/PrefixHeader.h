#ifndef PrefixHeader_H
#define PrefixHeader_H
#define _INTERNAL_

#import "Common.h"

static NSString * const APP_ID = @"5guWk5ftzCzMvpxQEfPVWjKXimY4Xg973E33nph15uug";
static NSString * const APP_KEY = @"DCNCU7HfGyFx7HrnJSpZZcbCREAppv1uZy4JCbqQHM1C";

static NSString * const API_SERVER = @"https://ws.iwhisper.io/api";
static NSString * const MQTT_SERVER = @"ssl://mqtt.iwhisper.io:8883";

static NSString * const STUN_SERVER = @"ws.iwhisper.io";
static NSString * const TURN_SERVER = @"ws.iwhisper.io";
static NSString * const TURN_USERNAME = @"whisper";
static NSString * const TURN_PASSWORD = @"io2016whisper";

static const WHWhisperTransportType defaultProtocol = WHWhisperTransportTypeICE;
static NSString * const defaultService = @"web";

static NSString * const Bugly_APP_ID = @"9dc9b11a50";

#endif
