//
//  PrefixHeader.h
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#ifndef PrefixHeader_H
#define PrefixHeader_H
#define _INTERNAL_

#import "Common.h"

static NSString * const APP_ID = @"5guWk5ftzCzMvpxQEfPVWjKXimY4Xg973E33nph15uug";
static NSString * const APP_KEY = @"DCNCU7HfGyFx7HrnJSpZZcbCREAppv1uZy4JCbqQHM1C";

static NSString * const API_SERVER = @"https://whisper.freeddns.org:8443/web/api";
static NSString * const MQTT_SERVER = @"ssl://whisper.freeddns.org:8883";

static NSString * const STUN_SERVER = @"whisper.freeddns.org";
static NSString * const TURN_SERVER = @"whisper.freeddns.org";
static NSString * const TURN_USERNAME = @"whisper";
static NSString * const TURN_PASSWORD = @"io2016whisper";

static const WMWhisperTransportType defaultProtocol = WMWhisperTransportTypeICE;
static NSString * const defaultService = @"web";

static NSString * const Bugly_APP_ID = @"9dc9b11a50";

#endif
