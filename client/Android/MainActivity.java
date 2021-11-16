public class MainActivity extends UnityPlayerActivity {
    private Billing billingClient;
 
    //初始化
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        billingClient = new Billing();
          billingClient.init(this);
    }

    // 支付
    public void doPay( ) {
        String callbackData = "";
        billingClient.pay(callbackData );
         
    }
}