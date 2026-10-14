#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface PKGarminBridge : NSObject
@property (nonatomic, copy, nullable) void (^changed)(void);
- (void)choose;
- (void)forget;
- (NSArray *)devices;
- (NSDictionary *)status;
- (BOOL)selectDevice:(NSString *)identifier NS_SWIFT_NAME(selectDevice(_:));
- (void)sendLogo:(NSDictionary *)payload completion:(void (^)(BOOL))completion;
- (void)replace:(NSDictionary *)snapshot completion:(void (^)(BOOL))completion;
+ (BOOL)handleURL:(NSURL *)url NS_SWIFT_NAME(handleURL(_:));
@end
NS_ASSUME_NONNULL_END
