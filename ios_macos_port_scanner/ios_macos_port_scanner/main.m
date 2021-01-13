@import Foundation;
#include <err.h>
#import <errno.h>
#import <netdb.h>
#import <arpa/inet.h>
#include <pthread.h>

#ifdef DEBUG
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...) {}
#endif

/********************************************************************************/
/*   Found Open Ports are stored in a Class NSMutableArray ( singleton )        */
/*   Class inherits from NSOperation                                            */
/*   The Class represents the smallest unit of work ( the Operation )           */
/*   Each Operation is added to a single NSOperationQueue                       */
/*   After each Operation is finished, it publishes a Notification              */
/*   [queue setMaxConcurrentOperationCount:5];  makes it multi-threaded         */
/********************************************************************************/

static NSString *YDhostname = @"127.0.0.1";
static NSUInteger YDstartPort = 0;
static NSUInteger const YDendPort = 2000;

@interface YDOperation : NSOperation

- (void) start;
- (void) finished;

@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign)  BOOL isExecuting, isFinished;
@property (class, nonatomic, strong) NSMutableArray *openPorts;
@property (class, nonatomic, strong) NSMutableArray *usedThreads;

@end

@implementation YDOperation

static NSMutableArray *_openPorts;
static NSMutableArray *_usedThreads;

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
        // NSMutable Array is not thread safe. It crashes. Added a synchronize wrapper.
        @synchronized(_usedThreads) {
            [_usedThreads addObject:[self getThreadID]];
        }
     }];
}

-(instancetype)init:(NSUInteger)enteredPort {
    self = [super init];
    if (self) {
        _port = enteredPort;
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
    sa.sin_addr.s_addr = inet_addr(YDhostname.UTF8String);

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
        
        NSDate *startTime = [NSDate date];
        [YDOperation setOpenPorts: [NSMutableArray array]];
        [YDOperation setUsedThreads:[NSMutableArray array]];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:5];
        
        do {
            YDOperation *operation = [[YDOperation alloc] init:YDstartPort];
            operation.queuePriority = NSOperationQueuePriorityNormal;
            operation.qualityOfService = NSOperationQualityOfServiceUserInteractive;
            [queue addOperation:operation];
            [operation setNotification];
            YDstartPort++;
        } while (YDstartPort < YDendPort);
        
        [queue waitUntilAllOperationsAreFinished];
        NSTimeInterval difference = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"Open Ports %@ %@", [YDOperation openPorts], [NSString stringWithFormat:@"\n\nFinished in: %.3f seconds\n", difference]);
        NSCountedSet *set = [[NSCountedSet alloc] initWithArray:[YDOperation usedThreads]];
        for (id t in set)
            NSLog(@"Thread=%@, Count=%lu", t, (unsigned long)[set countForObject:t]);
    }

    return 0;
}


