# iOS and macOS Port Scanner
Port Scanner for iOS and macOS

### Speed overview

Language  |Threads |Time | Data structure
--|---|--|--
Objective-C | 5 | 13.5-15 seconds | Queue
Python | 5 |  13.5-15 seconds | Queue
C  | 1 | 13 seconds | Sequential array


### Objective-C and C design choices
I expected the `Objective-C` code to be quick, as it still used `Sockets()` but I was able to leverage:
 - An `operation` represented the smallest unit of work.
 - Create a `Class` that inherits from `NSOperation`.
 - This class had one `Instance Property` for the `socket` check; the `port` number.
 - The class had instance properties related to `Operation`; `BOOL isExecuting, isFinished;`

 - Each `Operation` was added to a single `NSOperationQueue`.
 - The `queue` was setup to be `multi-threaded` by `[queue setMaxConcurrentOperationCount:5];`
 - After each `Operation` is finished, it published a `Notification`.
 - On the `finished notification` the `Port` tested and `Thread ID` were added to an `Array`.  The `usedThreads` array crashed consistently without a `synchronize` wrapper.  `NSMutable Arrays` are not thread safe.  I could have `locked` the `Open Ports` arrays.  But `Open Ports` was so frequently used it never caused `undefined behavior`.

### Results
```
[*]Ports checked:  2000
		hostname:127.0.0.1
[*]main thread:  0x063d09
[*]Threads used:  9
		Thread=0x063e77, Count=285
		Thread=0x063e7b, Count=226
		Thread=0x063e76, Count=222
		Thread=0x063e7a, Count=208
		Thread=0x063e97, Count=132
		Thread=0x063e75, Count=295
		Thread=0x063e79, Count=254
		Thread=0x063e7d, Count=141
		Thread=0x063e78, Count=234
[*]Open ports:  2
		port=22
		port=631

[*]Finished in:  14.131 seconds
```
### Concurrent Threads
```
Port=0, STARTED, Thread=0x066eec
Port=1, STARTED, Thread=0x066eed
Port=2, STARTED, Thread=0x066eee
Port=3, STARTED, Thread=0x066eef
Port=4, STARTED, Thread=0x066ef0
				Port=1, FINISHED Thread=0x066eed
				Port=2, FINISHED Thread=0x066eee
				Port=3, FINISHED Thread=0x066eef
Port=5, STARTED, Thread=0x066eed
Port=6, STARTED, Thread=0x066eef
				Port=4, FINISHED Thread=0x066ef0
Port=7, STARTED, Thread=0x066ef0
				Port=5, FINISHED Thread=0x066eed
				Port=6, FINISHED Thread=0x066eef
Port=9, STARTED, Thread=0x066eee
Port=10, STARTED, Thread=0x066eef
```
### Time Profiler
Within `Xcode` select `Product\Profile` to launch `Instruments`. Then select `time profiler`:

![time_profiler](/images/2021/01/time-profiler.png)


This showed the `Heaviest Stack Trace`. Huh.  Something not related to the `port scan`.

![heaviest_stack_trace](images/2021/01/heaviest-stack-trace.png)

### Re-design 1
An obvious improvement was to change the `Notification` to a `Class Function`. It was no longer called many times [ when a new class was created ].

![wait_until_ops_are_finished](images/2021/01/wait-until-ops-are-finished.png)

### Re-design 2
There was no immediate evidence of a speed-up.  But, before I look at speed, there were obvious `Objective-C` improvements to make:

Issue  | Description
--|--
Retire `transient` collections of objects |  Replace a `NSMutableArray` that was a "transient" structure to get data into a `NSMutableCountedSet`.
`Properties`|  Replace `Class Properties` to better enforce `encapsulation` [ by hiding more `instance variables` from the calling code ]
`Instance Methods`  |  Replace `getter` and `setter` with `methods`


#### Code style guides
https://google.github.io/styleguide/objcguide.html

https://github.com/raywenderlich/objective-c-style-guide#spacing

#### Summary of redesign
My code stopped completing.  It was getting stuck on this line:  `[queue waitUntilAllOperationsAreFinished];`

Setting a breakpoint revealed:
```
(lldb) po [queue operationCount]
30
```
This caused memory to be written to disk and not freed:

![writing_to_disk](images/2021/01/writing-to-disk.png)

The issue was `NSOperation`. I had to override the following:

```
isExecuting - read-only
isFinished - read-only
```
### Finding bottlenecks
Re-select `Time Profiler` and run the app.  You could observe:

- Tasks were split across `machine CPUs`
- But the threads appear to all send at the same time ( or were they waiting behind `locks`?)
- Time to start a thread was costly
- The `socket` call was expensive ( like not freeing )


![analyze_in_instruments](images/2021/01/analyze-in-instruments.png)



### Re-design 3
The `Operations` themselves were `synchronous`. Does that mean it blocks all the other threads?  No. Reference below:

>@property(readonly, getter=isAsynchronous) BOOL asynchronous;
Discussion
NO for operations that run synchronously on the current thread. The default value of this property is NO.

I overrode `self.isAsynchronous = YES;` to check if there was a speed improvement. No.

What about if I didn't have to `close` the `socket` so frequently?

```
sock = socket( AF_INET, SOCK_STREAM, 0 );

for ( int p = START;  p <= END; p++ ){
  //  try connect  
}

close ( sock );
```

### Re-design 4
What about moving the code away from a `Class instance` and move to a `Block`?



### What about
- `NSPort`            ->
- `NSStream`          -> complex, when I only want to check whether a `port` is `open`.
 - `NSSocketPort` -> only available on `macOS`.
 - `TCP Half Open` scan ( for speed)
 - `TCP Connect` for complete `TCP connection`
