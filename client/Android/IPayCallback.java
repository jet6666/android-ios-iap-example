package utils;

public interface IPayCallback {
    public void onSuccess(String data);

    public void onFail(int code, String msg);
}
