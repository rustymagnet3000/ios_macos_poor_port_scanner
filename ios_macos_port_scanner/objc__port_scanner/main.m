@import Foundation;
#import <arpa/inet.h>
#include <pthread.h>

#ifdef DEBUG
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...) {}
#endif


@interface YDOperation : NSOperation{
    @protected
        BOOL _isExecuting, _isFinished;
        NSUInteger _port;
}

- (void) start;
- (void) finished;

@property (class, readonly, nonnull) NSString *hostname;
@property (class, atomic, readwrite) NSUInteger endPort;
@property (class, atomic, readwrite) NSUInteger startPort;

@end

@implementation YDOperation

-(NSMutableArray*) openPorts
{
    static NSMutableArray *_openPorts = nil;
    if (_openPorts == nil)
        _openPorts = [NSMutableArray array];

    return _openPorts;
}

-(NSMutableArray*) usedThreads
{
    static NSMutableArray *_usedThreads = nil;
    if (_usedThreads == nil)
        _usedThreads = [NSMutableArray array];

    return _usedThreads;
}


static NSString *_hostname = @"127.0.0.1";
// default values. These Properties can be overidden
static NSUInteger _startPort = 0;
static NSUInteger _endPort = 2000;

+(NSString *)hostname{
    return _hostname;
}

+(NSUInteger)endPort{
    return _endPort;
}

+(void) setEndPort:(NSUInteger)endPort{
    _endPort = endPort;
}

+(NSUInteger)startPort{
    return _startPort;
}

+(void)setStartPort:(NSUInteger)startPort{
    _startPort = startPort;
}



+ (void) setNotification {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"foobar" object:self queue:nil usingBlock:^(NSNotification *note)
     {
        @synchronized(_usedThreads) {
            [_usedThreads addObject:[self getThreadID]];
        }
     }];
}

-(instancetype)init {
    self = [super init];
    if (self) {
        _port = _startPort;
        return self;
    }
    return nil;
}
   

- (void)start {
    _isExecuting = YES;
    _isFinished = NO;
    if ([self checkSocket]) {
        [_openPorts addObject:[NSNumber numberWithUnsignedLong:_port]];
    }
    [self finished];
}


-(BOOL)checkSocket {
    int result, sock;
    struct sockaddr_in sa = {0};
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = inet_addr(_hostname.UTF8String);

    sa.sin_port = htons(_port);
    sock = socket(AF_INET, SOCK_STREAM, 0);
    result = connect(sock , (struct sockaddr *) &sa , sizeof sa);
    close (sock);
    if (result == 0)
        return YES;
    return NO;
}

- (void)finished {
    _isExecuting = NO;
    _isFinished = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"foobar" object:self userInfo:nil];
}

+ (NSString *)getThreadID{
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    NSString *tidStr = [[NSString alloc] initWithFormat:@"%#08x", (unsigned int) tid];
    return tidStr;
}

+ (NSString *)prettyStart{
    return([NSString stringWithFormat:@"[*]Ports to check = %lu on: %@", YDOperation.endPort - YDOperation.startPort, YDOperation.hostname]);
}

+ (NSString *)prettySummary: (NSTimeInterval)timeDiff{
    NSCountedSet *set = [[NSCountedSet alloc] initWithArray:YDOperation.usedThreads];
    for (id t in set)
        NSLog(@"[*]Thread=%@, Count=%lu", t, (unsigned long)[set countForObject:t]);
    
    return([NSString stringWithFormat:@"\n\n[*]Finished in: %.3f seconds\n", timeDiff]);
}


@end

int main() {
    @autoreleasepool {
        
        NSLog( @"%@", [YDOperation prettyStart] );
        NSDate *startTime = [NSDate date];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:5];
        [YDOperation setNotification];
        
        do {
            YDOperation *operation = [[YDOperation alloc] init];
            operation.queuePriority = NSOperationQueuePriorityNormal;
            operation.qualityOfService = NSOperationQualityOfServiceUserInteractive;
            [queue addOperation:operation];
            YDOperation.startPort++;
        } while (YDOperation.startPort < YDOperation.endPort);
        
        [queue waitUntilAllOperationsAreFinished];
        NSTimeInterval difference = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog( @"%@", [YDOperation prettySummary:difference] );
    }

    return 0;
}


