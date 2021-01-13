# iOS and macOS Port Scanner
Port Scanner for iOS and macOS


### The Name of an Operation
Setup one:

- Found Open Ports are stored in a Class NSMutableArray ( singleton )
- Class inherits from NSOperation
- The Class represents the smallest unit of work ( the Operation )
- Each Operation is added to a single NSOperationQueue
-After each Operation is finished, it publishes a Notification
- `[queue setMaxConcurrentOperationCount:5];`  makes it multi-threaded



Language  |Threads |Time
--|---|--
Objective-C queued | 5  | 15 seconds  
Python queued   |  3 |  14 seconds
  |   |  

##### Option 1
/********************************************************************************/
/*   Found Open Ports are stored in a Class NSMutableArray ( singleton )        */
/*   Class inherits from NSOperation                                            */
/*   The Class represents the smallest unit of work ( the Operation )           */
/*   Each Operation is added to a single NSOperationQueue                       */
/*   After each Operation is finished, it publishes a Notification              */
/*   [queue setMaxConcurrentOperationCount:5];  makes it multi-threaded         */
/********************************************************************************/

##### Results
A Thread has no permanent linkage to an NSOperation.

[queue setMaxConcurrentOperationCount:5];  makes it multi-threaded

```
NSMutableArray *animalNames = [NSMutableArray arrayWithObjects:     @"Dog",....

do {
    .....
    operation.name = animalNames.lastObject;
    [animalNames removeLastObject];
```
This causes:
```
[*]14 port done. Baboon:🐝0xac7373
[*]10 port done. Lion:🐝0xac736f
[*]13 port done. Scorpion:🐝0xac7372
[*]12 port done. Ant:🐝0xac7371
[*]11 port done. Fish:🐝0xac7370
[*]18 port done. (null):🐝0xac7370
[*]17 port done. (null):🐝0xac7374
[*]19 port done. (null):🐝0xac736f
[*]15 port done. Cat:🐝0xac7373
[*]16 port done. Dog:🐝0xac7371
[*]20 port done. (null):🐝0xac7370
[*]21 port done. (null):🐝0xac7374
[*]22 port done. (null):🐝0xac736f
[*]23 port done. (null):🐝0xac7373
[*]24 port done. (null):🐝0xac7371
[*]25 port done. (null):🐝0xac7370
[*]27 port done. (null):🐝0xac736f
[*]26 port done. (null):🐝0xac7374
[*]28 port done. (null):🐝0xac7373
[*]29 port done. (null):🐝0xac7371
Open Ports (
    22
)

Finished in: 0.005 seconds
```
### What about
`NSStream`          -> complex, when I only want to check whether a `port` is `open`.
`NSSocketPort` -> only available on `macOS`.


### Design
`TCP Half Open` scan ( for speed)
`TCP Connect` for complete `TCP connection`
