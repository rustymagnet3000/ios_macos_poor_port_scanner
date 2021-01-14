@import Foundation;
#import <arpa/inet.h>
#include <pthread.h>

#ifdef DEBUG
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...) {}
#endif


@interface YDOperation : NSOperation{
        NSUInteger _port;
}

- (void) start;
- (void) finished;

@property (class, readwrite, nonnull) NSString *hostname;
@property (class, atomic, readwrite) NSUInteger endPort;
@property (class, atomic, readwrite) NSUInteger startPort;
@property (readwrite) BOOL isExecuting, isFinished;
@end

@implementation YDOperation

#pragma mark: Default values. These Properties can be overidden
static NSString *_hostname = @"127.0.0.1";
static NSUInteger _startPort = 0;
static NSUInteger _endPort = 2000;

+(NSMutableArray*) openPorts
{
    static NSMutableArray *_openPorts = nil;
    if (_openPorts == nil)
        _openPorts = [NSMutableArray array];

    return _openPorts;
}

+(NSCountedSet*) usedThreads
{
    static NSCountedSet *_usedThreads = nil;
    if (_usedThreads == nil)
        _usedThreads = [NSCountedSet set];

    return _usedThreads;
}


+(void) setHostname:(NSString *)hostname{
    _hostname = hostname;
}


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



- (void) setNotification {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"openSocketFoundNotification" object:self queue:nil usingBlock:^(NSNotification *note)
     {
        @synchronized([YDOperation openPorts]) {
            [[YDOperation openPorts] addObject: [NSNumber numberWithUnsignedLong:self->_port]];
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
    if ([self checkSocket])
        [[NSNotificationCenter defaultCenter] postNotificationName:@"openSocketFoundNotification" object:self userInfo:nil];
    
    @synchronized([YDOperation usedThreads]) {
        [[YDOperation usedThreads] addObject: [YDOperation getThreadID]];
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
}


+ (NSString *)getThreadID{
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    NSString *tidStr = [[NSString alloc] initWithFormat:@"%#08x", (unsigned int) tid];
    return tidStr;
}


+ (NSString *)prettyStart{
    return([NSString stringWithFormat:@"[*]Ports checked:  %lu\n\t\thostname:%@", YDOperation.endPort - YDOperation.startPort, YDOperation.hostname]);
}


+ (NSString *)prettySummary: (NSTimeInterval)timeDiff{

    NSLog(@"[*]Threads used:  %lu", [[YDOperation usedThreads] count]);
    
    for (id t in [YDOperation usedThreads])
        NSLog(@"\t\tThread=%@, Count=%lu", t, (unsigned long)[[YDOperation usedThreads] countForObject:t]);

    NSLog(@"[*]Open ports:  %lu", [[YDOperation openPorts] count]);
    for (id p in [YDOperation openPorts])
        NSLog(@"\t\tport=%@", p);
    
    return([NSString stringWithFormat:@"\n[*]Finished in:  %.3f seconds\n", timeDiff]);
}


@end

int main() {
    @autoreleasepool {
        
        NSLog( @"%@", [YDOperation prettyStart] );
        NSLog(@"[*]main thread:  %@", [YDOperation getThreadID]);
        NSDate *startTime = [NSDate date];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:5];
        
        do {
            YDOperation *operation = [[YDOperation alloc] init];
            operation.queuePriority = NSOperationQueuePriorityNormal;
            operation.qualityOfService = NSOperationQualityOfServiceUserInteractive;
            [operation setNotification];
            [queue addOperation:operation];
            YDOperation.startPort++;
        } while (YDOperation.startPort < YDOperation.endPort);
        
        [queue waitUntilAllOperationsAreFinished];
        NSTimeInterval difference = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog( @"%@", [YDOperation prettySummary:difference] );
    }

    return 0;
}


