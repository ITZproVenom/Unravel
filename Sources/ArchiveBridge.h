#import <Foundation/Foundation.h>

@class URKFileInfo;

NS_ASSUME_NONNULL_BEGIN

@interface UNRArchive : NSObject

@property (nonatomic, readonly) BOOL isPasswordProtected;
@property (nonatomic, readonly) BOOL hasMultipleVolumes;

- (nullable instancetype)initWithURL:(NSURL *)url
                            password:(nullable NSString *)password
                               error:(NSError **)error NS_SWIFT_NAME(init(url:password:));

- (nullable NSArray<URKFileInfo *> *)listEntries:(NSError **)error NS_SWIFT_NAME(listEntries());

- (BOOL)extractEntryNamed:(NSString *)name
              destination:(NSURL *)destination
                 progress:(NSProgress *)progress
                    error:(NSError **)error NS_SWIFT_NAME(extractEntry(named:destination:progress:));

@end

NS_ASSUME_NONNULL_END
