#import "PKGarminBridge.h"
#import <ConnectIQ/ConnectIQ.h>

static NSString *const PKAppId = @"5fdfca89-1939-4cb8-b3bb-d96184aa208c";
static NSString *const PKStoreId = @"e5582836-4178-442e-bd16-afa95b42e9c8";
static PKGarminBridge *active;
@interface PKGarminBridge () <IQDeviceEventDelegate, IQAppMessageDelegate, IQUIOverrideDelegate>
@property (nonatomic, strong) NSArray<IQDevice *> *known;
@property (nonatomic, strong) IQApp *app;
@property (nonatomic) BOOL ready;
@property (nonatomic) BOOL initialized;
@end
@implementation PKGarminBridge
- (instancetype)init {
    if ((self = [super init])) { active = self; self.known = @[]; }
    return self;
}
- (void)start {
    if (self.initialized) return;
    self.initialized = YES;
    [[ConnectIQ sharedInstance] initializeWithUrlScheme:@"paskluis-garmin" uiOverrideDelegate:self];
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"watch.garmin.devices"];
    if (data) {
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [IQDevice class], [NSString class], [NSUUID class], nil];
        self.known = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:nil] ?: @[];
        [self attach];
    }
}
- (void)choose { [self start]; [[ConnectIQ sharedInstance] showConnectIQDeviceSelection]; }
- (void)forget {
    if (self.initialized) {
        [[ConnectIQ sharedInstance] unregisterForAllAppMessages:self];
        [[ConnectIQ sharedInstance] unregisterForAllDeviceEvents:self];
    }
    self.app = nil; self.ready = NO;
    for (NSString *suffix in @[@"device", @"pending", @"owner", @"count", @"ack", @"ackOwner"]) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:[@"watch.garmin." stringByAppendingString:suffix]];
    }
    if (self.changed) self.changed();
}
- (void)needsToInstallConnectMobile { if(self.changed) self.changed(); }
+ (BOOL)handleURL:(NSURL *)url {
    if (![url.scheme isEqualToString:@"paskluis-garmin"] || !active) return NO;
    [active start];
    NSArray *devices = [[ConnectIQ sharedInstance] parseDeviceSelectionResponseFromURL:url];
    if (!devices) return YES;
    // Keep the old device available until its copy has been explicitly cleared.
    NSMutableArray *merged = [active.known mutableCopy];
    for (IQDevice *device in devices) {
        if (![merged filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(IQDevice *old, NSDictionary *bindings) {
            return [old.uuid isEqual:device.uuid];
        }]].count) [merged addObject:device];
    }
    active.known = merged;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:merged requiringSecureCoding:YES error:nil];
    if (data) [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"watch.garmin.devices"];
    [active attach];
    if (active.changed) active.changed();
    return YES;
}
- (NSArray *)devices {
    NSMutableArray *rows = [NSMutableArray array];
    for (IQDevice *d in self.known) [rows addObject:@{@"id":d.uuid.UUIDString, @"name":d.friendlyName ?: d.modelName ?: @"Garmin"}];
    return rows;
}
- (NSDictionary *)status {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL confirmed = [d objectForKey:@"watch.garmin.pending"] &&
      [[d objectForKey:@"watch.garmin.pending"] isEqual:[d objectForKey:@"watch.garmin.ack"]] &&
      [[d stringForKey:@"watch.garmin.owner"] isEqual:[d stringForKey:@"watch.garmin.ackOwner"]];
    return @{@"device": [d stringForKey:@"watch.garmin.device"] ?: @"", @"confirmed": @(confirmed)};
}
- (BOOL)selectDevice:(NSString *)identifier {
    [self start];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *old = [d stringForKey:@"watch.garmin.device"];
    if (old.length && ![old isEqual:identifier] && [d objectForKey:@"watch.garmin.pending"] &&
        (![[self status][@"confirmed"] boolValue] || [d integerForKey:@"watch.garmin.count"] != 0)) return NO;
    BOOL exists = NO;
    for (IQDevice *device in self.known) if ([device.uuid.UUIDString isEqual:identifier]) exists = YES;
    if (!exists) return NO;
    if (![old isEqual:identifier]) [d removeObjectForKey:@"watch.garmin.ack"];
    [d setObject:identifier forKey:@"watch.garmin.device"];
    [self attach];
    return YES;
}
- (void)attach {
    ConnectIQ *sdk = ConnectIQ.sharedInstance;
    [sdk unregisterForAllAppMessages:self];
    [sdk unregisterForAllDeviceEvents:self];
    self.app = nil; self.ready = NO;
    NSString *id = [NSUserDefaults.standardUserDefaults stringForKey:@"watch.garmin.device"];
    for (IQDevice *device in self.known) if ([device.uuid.UUIDString isEqual:id]) {
        self.app = [IQApp appWithUUID:[[NSUUID alloc] initWithUUIDString:PKAppId] storeUuid:[[NSUUID alloc] initWithUUIDString:PKStoreId] device:device];
        [sdk registerForDeviceEvents:device delegate:self];
        [sdk registerForAppMessages:self.app delegate:self];
    }
}
- (void)deviceCharacteristicsDiscovered:(IQDevice *)device { self.ready = YES; if(self.changed) self.changed(); }
- (void)deviceStatusChanged:(IQDevice *)device status:(IQDeviceStatus)status {
    if(status != IQDeviceStatus_Connected) self.ready = NO;
    if(self.changed) self.changed();
}
- (void)sendLogo:(NSDictionary *)payload completion:(void (^)(BOOL))completion {
    if(!self.app || !self.ready || ![payload[@"pixels"] isKindOfClass:NSString.class] || [payload[@"pixels"] length] != 576) { completion(NO); return; }
    NSMutableDictionary *message = [payload mutableCopy]; message[@"kind"] = @"logo";
    [[ConnectIQ sharedInstance] sendMessage:message toApp:self.app progress:^(uint32_t sent, uint32_t total) {} completion:^(IQSendMessageResult result) { completion(result == IQSendMessageResult_Success); }];
}
- (void)replace:(NSDictionary *)snapshot completion:(void (^)(BOOL))completion {
    [self start];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:snapshot[@"revision"] forKey:@"watch.garmin.pending"];
    [d setObject:snapshot[@"owner"] forKey:@"watch.garmin.owner"];
    [d setInteger:[snapshot[@"cards"] count] forKey:@"watch.garmin.count"];
    if(!self.app || !self.ready) { completion(NO); return; }
    [[ConnectIQ sharedInstance] sendMessage:snapshot toApp:self.app progress:^(uint32_t sent, uint32_t total) {} completion:^(IQSendMessageResult result) {
        completion(result == IQSendMessageResult_Success);
    }];
}
- (void)receivedMessage:(id)message fromApp:(IQApp *)app {
    if (![app.device.uuid isEqual:self.app.device.uuid] || ![message isKindOfClass:NSDictionary.class]) return;
    if (![message[@"ack"] isKindOfClass:NSNumber.class] || ![message[@"owner"] isKindOfClass:NSString.class]) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:message[@"ack"] forKey:@"watch.garmin.ack"];
    [d setObject:message[@"owner"] forKey:@"watch.garmin.ackOwner"];
    if(self.changed) self.changed();
}
@end
