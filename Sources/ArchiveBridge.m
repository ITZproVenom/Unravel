#import "ArchiveBridge.h"
#import "UnrarKit.h"

@implementation UNRArchive {
    URKArchive *_archive;
}

- (instancetype)initWithURL:(NSURL *)url password:(NSString *)password error:(NSError **)error {
    self = [super init];
    if (self) {
        _archive = [[URKArchive alloc] initWithURL:url password:password error:error];
        if (!_archive) { return nil; }
    }
    return self;
}

- (BOOL)isPasswordProtected { return _archive.isPasswordProtected; }
- (BOOL)hasMultipleVolumes { return _archive.hasMultipleVolumes; }
- (NSArray<URKFileInfo *> *)listEntries:(NSError **)error { return [_archive listFileInfo:error]; }

- (BOOL)extractEntryNamed:(NSString *)name
              destination:(NSURL *)destination
                 progress:(NSProgress *)progress
                    error:(NSError **)error {
    if (![[NSFileManager defaultManager] createFileAtPath:destination.path contents:nil attributes:nil]) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{
                NSLocalizedDescriptionKey: @"Could not create the temporary output file."
            }];
        }
        return NO;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:destination error:error];
    if (!handle) { return NO; }

    __block NSError *writeError = nil;
    NSError *engineError = nil;
    _archive.progress = progress;
    BOOL decoded = [_archive extractBufferedDataFromFile:name error:&engineError action:^(NSData *chunk, CGFloat percent) {
        if (writeError || progress.isCancelled) { return; }
        NSError *chunkError = nil;
        if (![handle writeData:chunk error:&chunkError]) {
            writeError = chunkError;
            [progress cancel];
        }
    }];
    NSError *closeError = nil;
    [handle closeAndReturnError:&closeError];

    if (writeError) {
        if (error) { *error = writeError; }
        return NO;
    }
    if (!decoded) {
        if (error) { *error = engineError; }
        return NO;
    }
    if (closeError) {
        if (error) { *error = closeError; }
        return NO;
    }
    return YES;
}

@end
