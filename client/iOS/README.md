##  objective-c

```
#import "UnityAppController.h"
#include "EMAppStorePay.h"
  
EMAppStorePay* _appPay = nil ;
 

 

- (id)init
{
    if ((self = _UnityAppController = [super init]))
    {
       。。。。
        _appPay = [[EMAppStorePay alloc] init ];
。。。。        
    }
    return self;
}
 


 
    [_appPay starBuyToAppStore: @"your_apple_itemid" :@"username" :@"serverid" ]; 
```