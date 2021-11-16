/**
 * 主要参考：https://www.jianshu.com/p/76416ebc0db0
 * 以及已經擁有該商品。 ：https://juejin.cn/post/6844904170231693325
 */
public class Billing {
    private BillingClient mBillingClient;
    private boolean payEnable = false;
    private MainActivity wrActivity;


    // init方法,並髮鎖住
    public synchronized void init(MainActivity mActivity) {
        wrActivity = mActivity;
        //创建BillingClient 对面，查询 消费  支付都会使用这个对象
        mBillingClient = BillingClient.newBuilder(mActivity)
                .setListener(new PurchasesUpdatedListener() {//设置支付回调，这里其实是商品状态发生变化时就会回调
                    @Override
                    public void onPurchasesUpdated(BillingResult billingResult, @Nullable List<Purchase> purchases) {
                        int responseCode = billingResult.getResponseCode();
                        LogUtils.d("call onPurchasesUpdated ,code = " + responseCode);
                        if (responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {//支付成功
                            for (Purchase purchase : purchases) {
                                if (purchase == null || purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED)
                                    continue;

                                //通知服务器支付成功，服务端验证后，消费商品
                                showLoading("Loading wait  ... ");
                                sendCPServer1(purchase);
                            }
                            //TODO客户端同步回调支付成功
                        } else if (responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {//支付取消
                            LogUtils.d("billing cancel ");
                            hideLoading();
                            alert(" 已取消");
                        } else if (responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                            // 购买失败，因为物品已经撝有,need to set
                            LogUtils.d("billing owned  ");
                            hideLoading();
                            alert("已经拥有该商品");
                            // queryPurchasesHistory();
                        } else {//支付失败
                            hideLoading();
                            LogUtils.d("billing failed  ");
                        }
                    }
                })
                .enablePendingPurchases()
                .build();
        //链接到google play
        this.connectBillPay();
    }

    private HashMap<String, Integer> tryDict = new HashMap<>();
    //重试时间间隔
    private int[] tryDealy = {1, 1, 3, 5, 8, 13, 21, 34, 55, 100};

    private void sendCPServer1(Purchase purchase) {
        OrderManager.getInstance().paySuccess(purchase, new IPayCallback() {
            @Override
            public void onSuccess(String data) {
                consumePurchase(purchase);
                if (tryDict.containsKey(purchase.getOrderId()))
                    tryDict.remove(purchase.getOrderId());
                ;
            }

            @Override
            public void onFail(int code, String msg) {
                hideLoading();

                int tryTimes = 0;
                if (tryDict.containsKey(purchase.getOrderId())) {
                    tryTimes = tryDict.get(purchase.getOrderId()).intValue();
                }
                if (code >= 9000 && tryTimes < 10) {
                    //重试
                    int delay = tryDealy[tryTimes];
                    tryTimes++;
                    tryDict.put(purchase.getOrderId(), new Integer(tryTimes));
                    alert("与发货服务器通讯失败," + delay + "秒后重试(" + tryTimes + ")");
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            Log.i("tag", "A Kiss after 5 seconds11111 = " + delay);
                            sendCPServer1(purchase);
                        }
                    }, delay * 1000);
                } else {
                    // 重試次數過多 中，或者其他原因
                    if (code < 9000) {
                        alert("请求失败太多，请联系客服," + code + ",msg=" + msg);
                    } else
                        alert("请求失败太多，请联系客服");
                }
            }
        });
    }

//重进APP时，那些未支付完成的重发货
    private void sendCpServer11(Purchase purchase) {
        OrderManager.getInstance().paySuccess(purchase, new IPayCallback() {
            @Override
            public void onSuccess(String data) {
                LogUtils.d("call paySuccess IHttpDataCallback ,code = " + data);
                consumePurchase(purchase);
                if (tryDict.containsKey(purchase.getOrderId()))
                    tryDict.remove(purchase.getOrderId());
            }

            @Override
            public void onFail(int code, String msg) {
                int tryTimes = 0;
                if (tryDict.containsKey(purchase.getOrderId())) {
                    tryTimes = tryDict.get(purchase.getOrderId()).intValue();
                }
                if (code >= 9000 && tryTimes < 10) {
                    //重试
                    int delay = tryDealy[tryTimes];
                    tryTimes++;
                    tryDict.put(purchase.getOrderId(), new Integer(tryTimes));
                    alert("重发货失败，," + delay + "秒后重试(" + tryTimes + ")");
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            Log.i("tag", "A Kiss after 5 seconds22222 :" + delay);
                            sendCpServer11(purchase);
                        }
                    }, delay * 1000);
                } else {
                     if (code < 9000) {
                        alert("请求失败太多，请联系客服," + code + ",msg=" + msg);
                    } else
                        alert("请求失败太多，请联系客服");
                }
            }
        });
    }

    private void connectBillPay() {
        LogUtils.d("connectBillPay");
        mBillingClient.startConnection(new BillConnectListener());
    }

    class BillConnectListener implements BillingClientStateListener {
        @Override
        public void onBillingSetupFinished(BillingResult billingResult) {
            LogUtils.d("onBillingSetupFinished,code = " + billingResult.getResponseCode());
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                //链接到google服务
                payEnable = true;
                //查询有没有未完成的订单
                queryPurchases();
            }
        }

        @Override
        public void onBillingServiceDisconnected() {
            //未链接到google服务
            LogUtils.d("onBillingServiceDisconnected");
            payEnable = false;
            connectBillPay();
        }
    }


    //查询已支付的商品,但未消費，并通知服务器后消费（google的支付里面，没有消费的商品，不能再次购买）
    private void queryPurchases() {
        LogUtils.d("未消費訂單 queryPurchases ");
        PurchasesResponseListener mPurchasesResponseListener = new PurchasesResponseListener() {
            @Override
            public void onQueryPurchasesResponse(@NonNull BillingResult billingResult, @NonNull List<Purchase> purchasesResult) {
                if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK || purchasesResult == null)
                    return;
                LogUtils.d("未消费订单数量 =  " + purchasesResult.size());
                for (Purchase purchase : purchasesResult) {
                    if (purchase != null) {
                        LogUtils.d(" purchase sate = " + purchase.getPurchaseState());
                    }
                    if (purchase == null || purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED)
                        continue;
                    //这里处理已经支付过的订单，通知服务器去验证
                    sendCpServer11(purchase);
                }
            }
        };
        mBillingClient.queryPurchasesAsync(BillingClient.SkuType.INAPP, mPurchasesResponseListener);
    }


    /**
     * 髮起支付
     *
     * @param cpOrder   你自己的订单号或者用户id，用于关联到对应的用户，发放道具时使用
     * @param productId google后台配置产品ID
     */
    public void pay(final String cpOrder, final String productId) {
        if (mBillingClient == null || wrActivity == null || !payEnable) {
            //TODO客户端同步回调支付失败，原因是为链接到google或者google的支付服务不能使用
            if (wrActivity != null) wrActivity.alert(" google play无法启动");
            return;
        }
        //查询商品详情
        LogUtils.d("cpOrder " + cpOrder + ", productid = " + productId);
        querySkuDetailsAsync(cpOrder, productId);
    }

    //查询商品详情
    private void querySkuDetailsAsync(final String cpOrder, final String productId) {
        //wrActivity.showLoading("查询商品详情");
        List<String> skuList = new ArrayList<>();
        skuList.add(productId);
        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(skuList).setType(BillingClient.SkuType.INAPP);
        mBillingClient.querySkuDetailsAsync(params.build(),
                new SkuDetailsResponseListener() {
                    @Override
                    public void onSkuDetailsResponse(BillingResult billingResult,
                                                     List<SkuDetails> skuDetailsList) {
                        hideLoading();
                        int code = billingResult.getResponseCode();

                        LogUtils.d("skuDetailsList 2222222= " + skuDetailsList.toString());
                        LogUtils.d(" onSkuDetailsResponse 333333333:billingResult.getResponseCode() = " + code);
                        if (skuDetailsList != null && code == BillingClient.BillingResponseCode.OK) {
                            if (skuDetailsList.size() == 0) {
                                wrActivity.alert("商品列表为空");
                            }
                            for (SkuDetails skuDetails : skuDetailsList) {
                                if (productId.equals(skuDetails.getSku())) {
                                    //发起支付
                                    LogUtils.d("getSKu");
                                    launchBillingFlow(cpOrder, skuDetails);
                                }
                            }
                        } else {
                            if (skuDetailsList == null) {
                            }

                            if (code != BillingClient.BillingResponseCode.OK) {
                                wrActivity.alert("GOOGLE PLAY  失败， CODE=" + code);
                            }
                        }
                    }
                });
    }

    //吊起google支付页面
    void launchBillingFlow(String cpOrder, SkuDetails skuDetails) {
        LogUtils.d("launchBillingFlow");
        mBillingClient.launchBillingFlow(
                wrActivity,
                BillingFlowParams
                        .newBuilder()
                        .setSkuDetails(skuDetails)
                        .setObfuscatedAccountId(cpOrder)//这里本来的意思存放用户信息，类似于国内的透传参数，我这里传的我们的订单号。老版本使用DeveloperPayload字段，最新版本中这个字段已不可用了
                        .build()
        );
    }

    private void alert(String text) {
        wrActivity.alert(text + "");
    }

    private void showLoading(String text) {
        wrActivity.showLoading(text + "");
    }

    private void hideLoading() {
        wrActivity.hideLoading();
    }

    /**
     * 数据上报
     */
    private void onPurchaseFinish() {
        wrActivity.onPurchaseFinish();
    }

    //消費商品
    public void consumePurchase(final Purchase purchase) {
        LogUtils.d("consumePurchase");
        if (mBillingClient == null || purchase == null || purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) {
            return;
        }

        showLoading("内购准备中.");

        LogUtils.d("消耗商品：\n商品id：" + purchase.getSkus() + "\n商品OrderId：" + purchase.getOrderId() + "\ntoken:" + purchase.getPurchaseToken());
        LogUtils.d("消耗商品：" + purchase.getAccountIdentifiers().getObfuscatedAccountId());
        ConsumeParams consumeParams = ConsumeParams.newBuilder()
                .setPurchaseToken(purchase.getPurchaseToken())
                .build();
        ConsumeResponseListener listener = new ConsumeResponseListener() {
            @Override
            public void onConsumeResponse(BillingResult billingResult, String purchaseToken) {
                int responseCode = billingResult.getResponseCode();
                if (responseCode == BillingClient.BillingResponseCode.ERROR) {
                    //消费失败将商品重新放入消费队列
                    hideLoading();
                    alert("GOOGLE PLAY消费失败");
                    return;
                } else if (responseCode == BillingClient.BillingResponseCode.OK) {
                    //处理消费成功
                    LogUtils.d("KO=======================通知发货----------");
                    showLoading("支付完成，与CP服务器通讯也完成");

                    onPurchaseFinish();

                    sendCPServerFinal(purchase);
 
                } else {
                    hideLoading();
                    alert("消费失败，未知错误");
                }
                LogUtils.d("消费成功");
            }
        };
        mBillingClient.consumeAsync(consumeParams, listener);
    }


    private void sendCPServerFinal(Purchase purchase) {
        OrderManager.getInstance().consumeFinal(purchase, new IPayCallback() {
            @Override
            public void onSuccess(String data) {
                LogUtils.d("call paySuccess IHttpDataCallback ,code = " + data);
                hideLoading();
                alert("发货成功，请检查服务端到账了没有");
                if (tryDict.containsKey(purchase.getOrderId()))
                    tryDict.remove(purchase.getOrderId());
            }

            @Override
            public void onFail(int code, String msg) {
                hideLoading();

                int tryTimes = 0;
                if (tryDict.containsKey(purchase.getOrderId())) {
                    tryTimes = tryDict.get(purchase.getOrderId()).intValue();
                }
                if (code >= 9000 && tryTimes < 10) {
                    //重试
                    int delay = tryDealy[tryTimes];
                    tryTimes++;
                    tryDict.put(purchase.getOrderId(), new Integer(tryTimes));
                    alert("联系不上发货服务器," + delay + "秒后重试(" + tryTimes + ")");
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            Log.i("tag", "333 try  = " + delay);
                            sendCPServerFinal(purchase);
                        }
                    }, delay * 1000);
                } else {
                    // 重試次數過多 中，或者其他原因
                    if (code < 9000) {
                        alert("发货失败太多," + code + ",msg=" + msg);
                    } else
                        alert("发货失败太多");
                }
            }
        });
    }
}


class LogUtils {
    public static void d(String s) {
        Log.d("billing", s + "");
    }
}

class OrderManager {
    private static OrderManager instance;
    public static boolean requesting = false;
    private static String payNotify = " ";
    private static String consumeNotify = " ";
    private static String echoNotify = " ";

    public static OrderManager getInstance() {
        if (instance == null) {
            instance = new OrderManager();
        }
        return instance;
    }

    private void requestServer(Purchase purchase, IPayCallback callback, String url) {
       //your http request ...........
       
                      //  callback.onFail(code, "err: code=" + code + ", msg=" + errMsg);
                   
                      //  callback.onSuccess("");
    }

    //消費成功，通知server
    public void consumeFinal(Purchase purchase, IPayCallback callback) {
        String url = String.format(consumeNotify, purchase.getPurchaseToken());
        requestServer(purchase, callback, url);
    }

    //支付成功，通知server
    public void paySuccess(Purchase purchase, IPayCallback callback) {
        String itemId = purchase.getSkus().get(0);
        String url = String.format(payNotify, purchase.getPurchaseToken(), itemId);
        requestServer(purchase, callback, url);
    }

    public void echo(IPayCallback callback) {
        requestServer(null, callback, echoNotify);
    }
}