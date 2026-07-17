package io.paratoner.tesseract_ocr;

import android.os.Handler;
import android.os.Looper;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import com.googlecode.tesseract.android.TessBaseAPI;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.File;

// Remove: import io.flutter.plugin.common.PluginRegistry.Registrar;

public class TesseractOcrPlugin implements MethodCallHandler, FlutterPlugin {

    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(
            flutterPluginBinding.getBinaryMessenger(),
            "tesseract_ocr"
        );
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    // Remove the registerWith method
    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "extractText":
            case "extractHocr":
                final String tessDataPath = call.argument("tessData");

                final String imagePath = call.argument("imagePath");
                String DEFAULT_LANGUAGE = "eng";

                // Check for language parameter first, then check config
                if (call.argument("language") != null) {
                    DEFAULT_LANGUAGE = call.argument("language");
                } else {
                    // Try to extract language from config object
                    Object configObj = call.argument("config");
                    if (configObj instanceof java.util.Map) {
                        java.util.Map<String, Object> config = (java.util.Map<
                                String,
                                Object
                            >) configObj;
                        Object languageObj = config.get("language");
                        if (languageObj != null) {
                            DEFAULT_LANGUAGE = languageObj.toString();
                        }
                    }
                }

                // Validate tessDataPath is not null
                if (tessDataPath == null) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "Data path must not be null! Ensure tessdata is properly loaded.",
                        null
                    );
                    return;
                }

                final String[] recognizedText = new String[1];
                final TessBaseAPI baseApi = new TessBaseAPI();

                try {
                    baseApi.init(tessDataPath, DEFAULT_LANGUAGE);
                    final File tempFile = new File(imagePath);
                    int pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO;
                    Object configuredPageSegMode = call.argument(
                        "tessedit_pageseg_mode"
                    );
                    if (configuredPageSegMode != null) {
                        try {
                            pageSegMode = Integer.parseInt(
                                configuredPageSegMode.toString()
                            );
                        } catch (NumberFormatException ignored) {}
                    }
                    baseApi.setPageSegMode(pageSegMode);

                    Object cropLeftArg = call.argument("crop_left");
                    Object cropTopArg = call.argument("crop_top");
                    Object cropRightArg = call.argument("crop_right");
                    Object cropBottomArg = call.argument("crop_bottom");
                    Object scaleArg = call.argument("scale");
                    double cropLeft = cropLeftArg instanceof Number
                        ? ((Number) cropLeftArg).doubleValue()
                        : 0.0;
                    double cropTop = cropTopArg instanceof Number
                        ? ((Number) cropTopArg).doubleValue()
                        : 0.0;
                    double cropRight = cropRightArg instanceof Number
                        ? ((Number) cropRightArg).doubleValue()
                        : 1.0;
                    double cropBottom = cropBottomArg instanceof Number
                        ? ((Number) cropBottomArg).doubleValue()
                        : 1.0;
                    double scale = scaleArg instanceof Number
                        ? ((Number) scaleArg).doubleValue()
                        : 1.0;

                    Thread t = new Thread(
                        new MyRunnable(
                            baseApi,
                            tempFile,
                            recognizedText,
                            result,
                            call.method.equals("extractHocr"),
                            cropLeft,
                            cropTop,
                            cropRight,
                            cropBottom,
                            scale
                        )
                    );
                    t.start();
                } catch (Exception e) {
                    result.error(
                        "INIT_ERROR",
                        "Failed to initialize Tesseract: " + e.getMessage(),
                        null
                    );
                    baseApi.recycle();
                }
                break;
            default:
                result.notImplemented();
        }
    }
}

class MyRunnable implements Runnable {

    private TessBaseAPI baseApi;
    private File tempFile;
    private String[] recognizedText;
    private Result result;
    private boolean isHocr;
    private double cropLeft;
    private double cropTop;
    private double cropRight;
    private double cropBottom;
    private double scale;

    public MyRunnable(
        TessBaseAPI baseApi,
        File tempFile,
        String[] recognizedText,
        Result result,
        boolean isHocr,
        double cropLeft,
        double cropTop,
        double cropRight,
        double cropBottom,
        double scale
    ) {
        this.baseApi = baseApi;
        this.tempFile = tempFile;
        this.recognizedText = recognizedText;
        this.result = result;
        this.isHocr = isHocr;
        this.cropLeft = cropLeft;
        this.cropTop = cropTop;
        this.cropRight = cropRight;
        this.cropBottom = cropBottom;
        this.scale = scale;
    }

    @Override
    public void run() {
        Bitmap source = null;
        Bitmap cropped = null;
        Bitmap scaled = null;
        try {
            boolean shouldCrop = cropLeft > 0.0 || cropTop > 0.0 ||
                cropRight < 1.0 || cropBottom < 1.0;
            if (shouldCrop) {
                source = BitmapFactory.decodeFile(this.tempFile.getAbsolutePath());
                int left = Math.max(0, (int) (source.getWidth() * cropLeft));
                int top = Math.max(0, (int) (source.getHeight() * cropTop));
                int right = Math.min(
                    source.getWidth(),
                    (int) (source.getWidth() * cropRight)
                );
                int bottom = Math.min(
                    source.getHeight(),
                    (int) (source.getHeight() * cropBottom)
                );
                cropped = Bitmap.createBitmap(
                    source,
                    left,
                    top,
                    Math.max(1, right - left),
                    Math.max(1, bottom - top)
                );
                if (scale > 1.0) {
                    scaled = Bitmap.createScaledBitmap(
                        cropped,
                        Math.max(1, (int) (cropped.getWidth() * scale)),
                        Math.max(1, (int) (cropped.getHeight() * scale)),
                        true
                    );
                    this.baseApi.setImage(scaled);
                } else {
                    this.baseApi.setImage(cropped);
                }
            } else {
                this.baseApi.setImage(this.tempFile);
            }
            if (isHocr) {
                recognizedText[0] = this.baseApi.getHOCRText(0);
            } else {
                recognizedText[0] = this.baseApi.getUTF8Text();
            }
            this.sendSuccess(recognizedText[0]);
        } catch (Exception e) {
            this.sendError(
                "OCR_ERROR",
                "Failed to recognize image: " + e.getMessage()
            );
        } finally {
            this.baseApi.recycle();
            if (scaled != null) scaled.recycle();
            if (cropped != null) cropped.recycle();
            if (source != null) source.recycle();
        }
    }

    public void sendSuccess(String msg) {
        final String str = msg;
        final Result res = this.result;
        new Handler(Looper.getMainLooper()).post(
            new Runnable() {
                @Override
                public void run() {
                    res.success(str);
                }
            }
        );
    }

    public void sendError(String code, String message) {
        final String errorCode = code;
        final String errorMessage = message;
        final Result res = this.result;
        new Handler(Looper.getMainLooper()).post(
            new Runnable() {
                @Override
                public void run() {
                    res.error(errorCode, errorMessage, null);
                }
            }
        );
    }
}
