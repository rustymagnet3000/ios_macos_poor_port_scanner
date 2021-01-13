@import Foundation;
#import <arpa/inet.h>
#include <pthread.h>

#ifdef DEBUG
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...) {}
#endif

/**
*   Found Open Ports are stored in a Class NSMutableArray ( singleton )
*   Class inherits from NSOperation
*   The Class represents the smallest unit of work ( the Operation )
*   Each Operation is added to a single NSOperationQueue
*   After each Operation is finished, it publishes a Notification
*   [queue setMaxConcurrentOperationCount:5];  makes it multi-threaded
*   NSMutable Array is not thread safe, even if you set the Property to atomic.
*   The usedThreads array crashes without the synchronize wrapper.
*/

@interface YDOperation : NSOperation
- (void) start;
- (void) finished;

@property (class, nonatomic, strong) NSMutableArray *openPorts;
@property (class, nonatomic, strong) NSMutableArray *usedThreads;
@property (class, readonly, nonnull) NSString *hostname;
@property (class, atomic, readonly) NSUInteger endPort;
@property (class, atomic, readwrite) NSUInteger startPort;
@property (nonatomic, assign, readwrite) NSUInteger port;
@property (nonatomic, assign, readwrite) BOOL isExecuting, isFinished;

@end

@implementation YDOperation

static NSMutableArray *_openPorts;
static NSMutableArray *_usedThreads;
static NSString *_hostname = @"127.0.0.1";
static NSUInteger _startPort = 0;
static NSUInteger _endPort = 2000;

+(NSString *)hostname{
    return _hostname;
}

+(NSUInteger)endPort{
    return _endPort;
}

+(NSUInteger)startPort{
    return _startPort;
}

+(void)setStartPort:(NSUInteger)startPort{
    _startPort = startPort;
}

+ (NSMutableArray *)usedThreads{
   return _usedThreads;
}

+(void)setUsedThreads:(NSMutableArray *)usedThreads{
    _usedThreads = usedThreads;
}

+ (NSMutableArray *)openPorts{
   return _openPorts;
}

+(void)setOpenPorts:(NSMutableArray *)ports{
    _openPorts = ports;
}

- (void) setNotification {
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
    self.isExecuting = YES;
    self.isFinished = NO;
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
    self.isExecuting = NO;
    self.isFinished = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"foobar" object:self userInfo:nil];
}

- (NSString *)getThreadID{
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    NSString *tidStr = [[NSString alloc] initWithFormat:@"%#08x", (unsigned int) tid];
    return tidStr;
}
@end

int main() {
    @autoreleasepool {
        
        NSLog(@"[*]Ports to check = %lu on: %@", YDOperation.endPort - YDOperation.startPort, YDOperation.hostname);
        NSDate *startTime = [NSDate date];
        [YDOperation setOpenPorts: [NSMutableArray array]];
        [YDOperation setUsedThreads:[NSMutableArray array]];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:3];
        
        do {
            YDOperation *operation = [[YDOperation alloc] init];
            operation.queuePriority = NSOperationQueuePriorityNormal;
            operation.qualityOfService = NSOperationQualityOfServiceUserInteractive;
            [queue addOperation:operation];
            [operation setNotification];
            YDOperation.startPort++;
        } while (YDOperation.startPort < YDOperation.endPort);
        
        [queue waitUntilAllOperationsAreFinished];
        NSTimeInterval difference = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"[*]Open Ports %@ %@", YDOperation.openPorts, [NSString stringWithFormat:@"\n\n[*]Finished in: %.3f seconds\n", difference]);
        NSCountedSet *set = [[NSCountedSet alloc] initWithArray:YDOperation.usedThreads];
        for (id t in set)
            NSLog(@"[*]Thread=%@, Count=%lu", t, (unsigned long)[set countForObject:t]);
    }

    return 0;
}


