//
//  EMAppStorePay.m
//  MobileFixCar
//
//  Created by Wcting on 2018/4/11.
//  Copyright ? 2018年 XXX有限公司. All rights reserved.
//

#import "EMAppStorePay.h"
#import <StoreKit/StoreKit.h>

#import <Foundation/Foundation.h>
#include "UnityAppController+ViewHandling.h"

//保存APPLEID登陆信息
#import "SAMKeychain.h"


@interface EMAppStorePay()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (nonatomic, strong)NSString *goodsId;/**  商品id*/

@property (nonatomic, strong)NSString *serverId;/**大区id*/
@property (nonatomic, strong)NSString *username;/**用户名*/

@property(nonatomic ,strong) NSMutableDictionary *tokenDict ;
@property(nonatomic ,strong) NSMutableDictionary *transDict ;
@end

@implementation EMAppStorePay

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];// 4.设置支付服务
        self.tokenDict = [NSMutableDictionary dictionary] ;
        self.transDict = [NSMutableDictionary dictionary];
    }
    return self;
}
//结束后一定要销毁
- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - 显示提示
-(void) showLoading  : (NSString*) message {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            //your loading here
        }) ;
    });
}

-(void) hideLoading {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            //hide your loading 
        }) ;
    });
}

-(void) showAlert : (NSString*) message {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alertView show];
        }) ;
    });
    
}

#pragma mark - 开始购买
-(void)starBuyToAppStore:(NSString *)goodsID :(NSString *) username : (NSString *) serverId
{
    NSLog(@" good is = %@ "  ,goodsID) ;
    [self showLoading :@"get product message ..."];
    
    self.username = username;
    self.serverId = serverId;
    if ([SKPaymentQueue canMakePayments]) {//5.判断app是否允许apple支付
            [self getRequestAppleProduct:goodsID];// 6.请求苹果后台商品
    } else {
        NSLog(@"cant make payments-----------------");
        [self hideLoading];
        [self showAlert:@" Cannot get payment .please try your setting"] ;
    }
}

#pragma mark ------ 请求苹果商品
- (void)getRequestAppleProduct:(NSString *)goodsID
{
    NSLog(@" get REquest App product %@" , goodsID) ;
    self.goodsId = goodsID;//把前面传过来的商品id记录一下，下面要用
    NSArray *product = [[NSArray alloc] initWithObjects:goodsID,nil];
    NSSet *nsset = [NSSet setWithArray:product];
    //SKProductsRequest参考链接：https://developer.apple.com/documentation/storekit/skproductsrequest
    //SKProductsRequest 一个对象，可以从App Store检索有关指定产品列表的本地化信息。
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];// 8.初始化请求
    request.delegate = self;
    [request start];// 9.开始请求
}

#pragma mark ------ SKProductsRequestDelegate
// 10.接收到产品的返回信息,然后用返回的商品信息进行发起购买请求
- (void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *product = response.products;
    
    NSLog(@"response") ;
    NSLog(@"%@", response) ;
    NSLog(@" product list = %@" , [response products]);
    
    if([product count] == 0){//如果服务器没有产品
        NSLog(@" no server product .................") ;
        [self hideLoading];
        [self showAlert:@"No Product ................."];
        return;
    }
    
    SKProduct *requestProduct = nil;
    for (SKProduct *pro in product) {
        NSLog(@"%@", [pro description]);
        // 11.如果后台消费条目的ID与我这里需要请求的一样（用于确保订单的正确性）
        if([pro.productIdentifier isEqualToString:self.goodsId]){
            requestProduct = pro;
        }
    }
    // 12.发送购买请求，创建票据  这个时候就会有弹框了
    [self showLoading:@"In payment. please wait ......"];
    SKPayment *payment = [SKPayment paymentWithProduct:requestProduct];
    [[SKPaymentQueue defaultQueue] addPayment:payment];//将票据加入到交易队列
}

#pragma mark ------ SKRequestDelegate (@protocol SKProductsRequestDelegate <SKRequestDelegate>)
//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"error:%@", error);
    [self hideLoading];
}
//反馈请求的产品信息结束后
- (void)requestDidFinish:(SKRequest *)request
{
    NSLog(@"信息反馈结束");
}


#pragma mark ------ SKPaymentTransactionObserver 监听购买结果
// 13.监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction
{
    for(SKPaymentTransaction *tran in transaction){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
            {
                [self hideLoading];
                NSLog(@"----交易完成   111111111111");
                //走到这就说明这单在APPLE支付完成了，但需要后端确认订单才可以，确认过了，再finishTransaction完成整个流程
                [self completeTransaction:tran];
                //[[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
                
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"-----商品添加进列表  111111111111");
                break;
                
            case SKPaymentTransactionStateRestored:
                NSLog(@"----已经购买过商品,删除队列  111111111111");
                [self hideLoading];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
                
            case SKPaymentTransactionStateFailed:
                [self hideLoading];
                NSLog(@"----交易失败，删除队列 111111111111");
                [self showAlert:@"pay failed ，please try later  (code :2001)"] ;
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
                
            case SKPaymentTransactionStateDeferred:
                NSLog(@"-----交易还在队列里面，但最终状态还没有决定 111111111111");
                break;
                
            default:
                break;
        }
    }
}


#pragma mark - 支付完成,但需要去后端验证，再：finishTransaction完成订单
- (void)completeTransaction:(SKPaymentTransaction *)transaction{
    NSLog(@" payment transaction ====== ") ;
    
    [self showLoading:@"訂單確認中，請稍等..."];
    //此时告诉后台交易成功，并把receipt传给后台验证
    NSString *transactionReceiptString= nil;
    //new
    NSURL *receiptLocal= [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptLocal];
    transactionReceiptString = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSLog(@"requestContentstr:%@",transactionReceiptString);
    
    //orderID
    NSString *orderId = transaction.transactionIdentifier;
    NSString *productId = transaction.payment.productIdentifier;
    NSString *token= [transactionReceiptString stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    
    //如果是没有完成的订单，需要从本地存储中查找对应的serverid ,username
    NSDictionary *savedTransDict  = [self getLocalTrans:orderId] ;
    if( savedTransDict ==nil ) {
        //写入订单情况
        if(self.username !=nil ) {
            NSDictionary *transDict = @{@"productId":productId, @"serverid" : self.serverId ,@"username":self.username ,@"try":@0 ,@"tryDate":@"0"} ;
            [self saveLocalTrans:orderId :transDict];
        }
        else {
            //充了钱，但没有写入数据completeTrans，这里可以在充值完成后，关掉APP复现。。。
            NSLog(@"-------order no  extra data ====== %@  ,daga= %@" , orderId  ,savedTransDict) ;
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            [self showAlert:@"an uncomplete order .please contact apple "];
            [self hideLoading];
            return ;
        }
    }
    NSLog(@"----new order %@" , orderId);
    //写入重试的订单,只对本次APP生命周期有效
    [self.tokenDict setObject:token forKey:orderId] ;
    
    //订单
    [self.transDict setObject:transaction forKey:orderId];
    
    //发送请求
    [self prepareVerify: orderId :YES] ;
 
    //充值事务完成 ！，放到服务器完成发货后
    //[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


-(void) prepareVerify : (NSString*) orderId  : (BOOL) showAlert{
    NSDictionary *savedTransDict  = [self getLocalTrans:orderId] ;
    if( savedTransDict ==nil ) {
        NSLog(@"---------找不到对应的保存订单参数了 ,transdata %@，跳过" , orderId) ;
        [self getAllLocalTrans];
        [self hideLoading];
        return ;
    }
    NSString *orderServerId =[savedTransDict objectForKey:@"serverid"];
    NSString *orderUsername =[savedTransDict objectForKey:@"username"];
    NSString *productId =[savedTransDict objectForKey:@"productId"];
    NSString *token =[self.tokenDict objectForKey:orderId];
    if(token ==nil ) {
        NSLog(@"----------找不到对应的订单 token ，跳过 %@" , orderId) ;
        for( NSString *k1 in self.tokenDict) {
            NSLog(@"---- token %@" ,k1);
        }
        return ;
    }
    
    SKPaymentTransaction *transaction = [self.transDict objectForKey:orderId];
    if(transaction == nil ) {
        NSLog(@"----------找不到对应的订单 transaction ，跳过 %@" , orderId) ;
        for( NSString *k1 in self.transDict) {
            NSLog(@"---- trans %@" ,k1);
        }
        [self hideLoading];
        return ;
    }
    
    NSString *payUrl = @"";
    payUrl= [ payUrl stringByAppendingFormat:@"https://xxxxxxx/aaaa/bbbb" ,orderServerId,orderUsername ,orderId,productId] ;
    
    [self showLoading:@"Verify order .please wait ......"] ;
    NSLog(@" pay url = %@" , payUrl) ;

    //异常发送请求中。。。
    [self verifyReceipt:showAlert:payUrl :token  :^{
        NSLog(@"------操作订单成功， %@" ,orderId ) ;
        //删除这个订单的情况
        [self removeLocalTrans:orderId];
        //删除这个token
        [self.tokenDict removeObjectForKey: orderId] ;
        [self.transDict removeObjectForKey:orderId];
        //通知apple关闭事务
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        
    } :^{
        
        NSLog(@"----------操作订单失败。。。。。， %@" ,orderId ) ;
        //验证订单失败情况
        NSDate *date = [NSDate date];
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        formater.dateFormat = @"yyyyMMd";
        NSTimeZone *timezone = [[NSTimeZone alloc] initWithName:@"China/Shanghai"];
        formater.timeZone = timezone;
        NSString *todayString = [formater stringFromDate:date] ;
        
        //重试时间间隔
        NSDictionary *retryInterval =@{@1:@1,@2:@1,@3:@3,@4:@5,@5:@8,@6:@13,@7:@21,@8:@34,@9:@55,@10:@100};
        
        //从失败列表中查找要重试，超过10次今天就不重试了
        for( id key in self.tokenDict) {
            NSDictionary *transData = [self getLocalTrans:key] ;
            NSLog(@"trandata = %@" ,transData) ;
            
            if(transData!=nil ) {
               // int tryTimes =transData[@"try"];// [[transData objectForKey:@"try"] intValue] ;
                int tryTimes = [[transData objectForKey:@"try"] intValue];
                NSString *tryDate =
                [transData objectForKey:@"tryDate"];
                BOOL isToday =[tryDate isEqualToString:todayString];
                if( tryTimes >= 10 &&  (tryDate!=nil && isToday)) {
                    NSLog(@" ------ try more times  today , skip .... %@" ,key) ;
                    continue;
                }
                //开启重试
                if(isToday) {
                    tryTimes++;
                }else {
                    tryTimes =1;
                }
                
                NSString *trytime3 = [NSString  stringWithFormat:@"%d",tryTimes];
                 
                //new values
                NSMutableDictionary *transData2 = [NSMutableDictionary dictionaryWithDictionary:transData];
                [transData2 setObject:trytime3 forKey:@"try"];
                [transData2 setObject:todayString forKey:@"tryDate"];
                [self saveLocalTrans:key :transData2] ;
                
                //重试订单
                NSLog(@"--------order try -- order = %@  ,  times = %@" ,orderId ,trytime3  );
                
                NSNumber *t1 = [NSNumber   numberWithInteger: tryTimes];
                NSString *tryT1 =[retryInterval objectForKey:t1];
                NSTimeInterval value= [tryT1 intValue];
                [NSTimer scheduledTimerWithTimeInterval:value target:self selector:@selector(retryVerify:) userInfo:key repeats:NO];
                break ;
            }
        }
        
    }];
}

-(void)retryVerify: (NSTimer *) timer  {
    NSString *orderId = timer.userInfo;// [[[timer userInfo] objectForKey:@"id"] stringValue] ;
    NSLog(@"----- try order %@ " ,orderId );
    [self prepareVerify:orderId :NO];
}


//-- HTTP POST
-(void) verifyReceipt : (BOOL) showAlertMsg: (NSString *) urlString  :(NSString *) token :   (void (^)(  void)) onComplete : (void (^)(  void)) onFailed     {
    //NSArray * array = [urlString componentsSeparatedByString:@"?"];
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"`#%^{}\"[]|\\<> "].invertedSet];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSString *token2 = @"";
    token2 = [token2 stringByAppendingFormat:@"token=%@",token];
    NSData *postData = [token2 dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url] ;
    //post
    request.HTTPMethod=@"POST";
    //timeout
    request.timeoutInterval =10.0;
    //params
    request.HTTPBody=postData;
    //NSLog(@"post data = %@" ,postData);
    //NSLog(@" arr = %@ " , array);
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if( connectionError) {
            //加入重试队列
            NSLog(@"connectionError =  %@" ,connectionError );
            onFailed();
            
            [self hideLoading];
            if(showAlertMsg)
            [self showAlert:@"verifyReceipt failed too many times ."];
        }
        else if(  ((NSHTTPURLResponse * ) response).statusCode == 200) {
            NSLog(@" http resutrn data = %@",  [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]) ;
            [self jsonParseData:data : onComplete :onFailed :showAlertMsg];
        }else {
            //加入重试队列
            NSLog(@"connectionError not 200 other  =  "  );
            onFailed();
            [self hideLoading];
            if(showAlertMsg)
            [self showAlert:@"verifyReceipt failed too many times (2) "];
        }
    }];
}
 
-(void ) jsonParseData : (NSData *) data :    (void (^)(  void)) onComplete : (void (^)(  void)) onFailed  :(BOOL) showAlert {
    NSLog(@"data =  %@ " ,data ) ;
    [self hideLoading];
            onComplete();
    [self showAlert:@" Succcess !!!!!!"] ;
     
    
}


#pragma mark - 本地化一些数据，保存订单数据
//-- ['extra' => 'extra' , 'try' => 重试次数 ，用这个作为发送请求权重 ]
-(void) saveLocalTrans: (NSString*) transId :  (NSDictionary *) dict {
    NSString *bundleId =[NSBundle mainBundle].bundleIdentifier;
    NSData *testData1 = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    [SAMKeychain setPasswordData:testData1 forService:bundleId account:transId];
}

-(void) removeLocalTrans: (NSString *) transId {
    NSString *bundleId =[NSBundle mainBundle].bundleIdentifier;
    [SAMKeychain deletePasswordForService:bundleId account:transId] ;
}

-(void) getAllLocalTrans {
  
     NSString *bundleId =[NSBundle mainBundle].bundleIdentifier;
     NSArray * accounts =[SAMKeychain allAccounts] ;
     if(accounts.count >0 ) {
     NSLog(@"acocunt %@" , accounts) ;
     for(int i =0 ; i<accounts.count ;i++) {
     // NSLog(@" array[%i] = %@ " , i , accounts[i]) ;
     NSDictionary *dict = accounts[i] ;
     // for (NSString * key1 in dict) {
     //     NSLog(@" %@ = %@ " ,key1 ,dict[key1]);
     // }
     NSString *key2 =dict[@"acct"];
     NSLog(@"------ key =%@ value = %@" , key2 , [SAMKeychain passwordForService:bundleId account:key2]) ;
     
     //NSString *v = [SAMKeychain passwordForService:bundleId account:key2];
     //NSLog(@"v = %@" , v);
     
     //delete one
     }
     }
      
}

 

-(NSDictionary *) getLocalTrans : (NSString *) transId {
    NSString *bundelrId =[NSBundle mainBundle].bundleIdentifier;
    NSData *testData2 = [SAMKeychain passwordDataForService:bundelrId account:transId];
    if( testData2 == nil ) return nil ;
    NSDictionary *r1 = [NSJSONSerialization JSONObjectWithData:testData2 options:NSJSONReadingMutableLeaves error:nil] ;
    return r1 ;
}
@end
