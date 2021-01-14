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
[*]Ports to check = 2000 on: 127.0.0.1
[*]Open Ports (
    ...,
    ...
)
[*]Finished in: 15.104 seconds

[*]Thread=0xae9643, Count=218
[*]Thread=0xae9634, Count=250
[*]Thread=0xae9633, Count=368
[*]Thread=0xae9636, Count=419
[*]Thread=0xae9632, Count=353
[*]Thread=0xae9635, Count=392
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
Retire `transient` Type |  Replace a `NSMutableArray` that was a "transient" structure to get data into a `NSCountedSet`.
`Properties`|  Replace `Class Properties` to better enforce `encapsulation` [ by hiding more `instance variables` from the calling code.and
`Instance Methods`  |  Replace `getter` and `setter` with `methods`


### Re-design 3
What about moving the code away from a `Class instance` and move to a `Block`?



### What about
`NSPort`            ->
`NSStream`          -> complex, when I only want to check whether a `port` is `open`.
`NSSocketPort` -> only available on `macOS`.
`TCP Half Open` scan ( for speed)
`TCP Connect` for complete `TCP connection`
