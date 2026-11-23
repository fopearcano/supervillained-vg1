package com.zampano.svspike;

import android.app.Activity;
import android.content.pm.PackageInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Date;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * THROWAWAY M1 feasibility spike (docs/porting MILESTONES.md M1): reads the five legacy
 * SUPERVILLAINED Capacitor localStorage keys after a same-package/same-signature upgrade.
 *
 * It opens the app's default WebView profile (the directory the old Capacitor WebView used) on
 * the verified Capacitor origin https://localhost, served by request interception (no network,
 * no INTERNET permission), and calls localStorage.getItem for exactly the five approved keys.
 * It never calls setItem/removeItem/clear or any WebStorage/CookieManager deletion API, never
 * parses or normalizes the values, never reads LevelDB/SQLite files, and writes no save.
 * The result is one JSON string emitted with the "legacy_read_completed" signal.
 *
 * Safe from minSdk 24: WebView.getCurrentWebViewPackage() (API 26) is only called on API 26+,
 * and every diagnostic is gathered behind a Throwable guard so it can never stop the raw read
 * result from being emitted. One read is active at a time; its WebView, timeout and generation
 * are fields, so Activity destruction or Godot termination cancels the timeout and destroys the
 * WebView on the UI thread, and every late page, interception or evaluateJavascript callback of
 * a finished or cancelled generation is ignored (nothing is emitted for a cancelled read).
 */
public class MigrationSpikePlugin extends GodotPlugin {
	private static final String TAG = "SvMigrationSpike";
	/** Capacitor 8 default: androidScheme "https", hostname "localhost" (no server config). */
	static final String ORIGIN = "https://localhost";
	/** A path the old game never served; intercepted here, so nothing is fetched. */
	static final String PAGE_URL = ORIGIN + "/__sv_m1_migration_spike__/read.html";
	static final String PREFIX = "supervillained:";
	static final String[] KEYS = { "settings", "records", "coins", "story", "story-v1-backup" };
	static final long TIMEOUT_MS = 20000;
	/** Development-only lifecycle test: the page response is held this long, so the read stays active. */
	static final long LIFECYCLE_HOLD_MS = 20000;

	private static final String PAGE = "<!doctype html><html><head><meta charset=\"utf-8\"><title>m1</title></head><body></body></html>";
	/** Read-only: getItem on the five prefixed keys, nothing else (plus navigator.userAgent). */
	private static final String READ_JS =
			"(function(){var keys=['settings','records','coins','story','story-v1-backup'];"
			+ "var out={origin:location.origin,href:location.href,user_agent:navigator.userAgent,keys:{},storage_error:null};var ls=null;"
			+ "try{ls=window.localStorage;}catch(e){out.storage_error='localStorage access: '+String(e);return JSON.stringify(out);}"
			+ "if(!ls){out.storage_error='localStorage unavailable';return JSON.stringify(out);}"
			+ "for(var i=0;i<keys.length;i++){var r={present:false,value:null,error:null};"
			+ "try{var v=ls.getItem('" + PREFIX + "'+keys[i]);r.present=(v!==null);r.value=v;}catch(e){r.error=String(e);}"
			+ "out.keys[keys[i]]=r;}return JSON.stringify(out);})()";

	private final Handler handler = new Handler(Looper.getMainLooper());
	private final AtomicInteger attempts = new AtomicInteger(0);
	/** Generation of the active read, 0 when none; read by the WebView's interception thread. */
	private final AtomicInteger liveGeneration = new AtomicInteger(0);
	// Active-read state: UI thread only.
	private int generationCounter = 0;
	private WebView activeWebView = null;
	private Runnable activeTimeout = null;
	private int activeAttempt = 0;

	public MigrationSpikePlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "SvMigrationSpike";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo("legacy_read_completed", String.class));
		return Collections.unmodifiableSet(signals);
	}

	/** Starts one read; the result arrives as legacy_read_completed(json). */
	@UsedByGodot
	public void readLegacyStore() {
		request(0);
	}

	/**
	 * Development-only (lifecycle test): the same read, but the intercepted page is held for
	 * LIFECYCLE_HOLD_MS, so Activity destruction or Godot termination happens while it is active.
	 */
	@UsedByGodot
	public void readLegacyStoreHeldForLifecycleTest() {
		request(LIFECYCLE_HOLD_MS);
	}

	/**
	 * Development-only (lifecycle test): finishes the host Activity, so its real onDestroy (and
	 * this plugin's onMainDestroy) runs while a held read is active.
	 */
	@UsedByGodot
	public void finishActivityForLifecycleTest() {
		final Activity activity = getActivity();
		if (activity == null) return;
		safeLog("lifecycle test: finishing the Activity");
		activity.runOnUiThread(activity::finish);
	}

	@Override
	public void onMainDestroy() {
		cancelForLifecycle("activity_destroy");
		super.onMainDestroy();
	}

	@Override
	public void onGodotTerminating() {
		cancelForLifecycle("godot_terminating");
		super.onGodotTerminating();
	}

	private void request(final long holdMs) {
		final int attempt = attempts.incrementAndGet();
		final Activity activity = getActivity();
		if (activity == null) {
			emit(attempt, failure(attempt, "no_activity", null, null));
			return;
		}
		activity.runOnUiThread(() -> start(activity, attempt, holdMs));
	}

	/** UI thread. */
	private void start(final Activity activity, final int attempt, final long holdMs) {
		if (liveGeneration.get() != 0) {
			emit(attempt, failure(attempt, "busy", null, null));
			return;
		}
		final int gen = ++generationCounter;
		liveGeneration.set(gen);
		activeAttempt = attempt;
		final JSONObject diag = diagnostics(activity, holdMs);
		safeLog("attempt " + attempt + " (generation " + gen + "): loading " + PAGE_URL + " diag=" + diag);
		activeTimeout = () -> finish(gen, attempt, failure(attempt, "timeout", diag, null));
		try {
			final WebView wv = new WebView(activity);
			activeWebView = wv;
			WebSettings s = wv.getSettings();
			s.setJavaScriptEnabled(true);
			s.setDomStorageEnabled(true);
			s.setAllowFileAccess(false);
			s.setAllowContentAccess(false);
			wv.setVisibility(View.INVISIBLE);
			wv.setWebViewClient(new WebViewClient() {
				@Override
				public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
					String url = request.getUrl().toString();
					if (PAGE_URL.equals(url)) {
						if (holdMs > 0) hold(gen, holdMs);
						if (liveGeneration.get() != gen) {
							safeLog("ignored late page request of generation " + gen);
							return empty(410, "Gone");
						}
						return new WebResourceResponse("text/html", "utf-8", 200, "OK", Collections.emptyMap(),
								new ByteArrayInputStream(PAGE.getBytes(StandardCharsets.UTF_8)));
					}
					safeLog("blocked request " + url);
					return empty(404, "Not Found");
				}

				@Override
				public void onPageFinished(WebView view, String url) {
					if (liveGeneration.get() != gen || activeWebView != view) {
						safeLog("ignored late onPageFinished of generation " + gen);
						return;
					}
					if (!PAGE_URL.equals(url)) return;
					view.evaluateJavascript(READ_JS, value -> {
						if (liveGeneration.get() != gen) {
							safeLog("ignored late evaluateJavascript result of generation " + gen);
							return;
						}
						finish(gen, attempt, result(attempt, value, diag));
					});
				}
			});
			ViewGroup root = activity.findViewById(android.R.id.content);
			root.addView(wv, new FrameLayout.LayoutParams(1, 1));
			handler.postDelayed(activeTimeout, TIMEOUT_MS + holdMs);
			wv.loadUrl(PAGE_URL);
		} catch (Throwable t) {
			finish(gen, attempt, failure(attempt, "webview_unavailable", diag, t.toString()));
		}
	}

	/** UI thread: ends generation `gen` once (later calls are ignored) and emits its result. */
	private void finish(int gen, int attempt, JSONObject result) {
		if (liveGeneration.get() != gen) {
			safeLog("ignored late completion of generation " + gen);
			return;
		}
		teardown("completed");
		emit(attempt, result);
	}

	/** UI thread: cancels the timeout and destroys the WebView of the active read, if any. */
	private void teardown(String reason) {
		int gen = liveGeneration.getAndSet(0);
		if (activeTimeout != null) handler.removeCallbacks(activeTimeout);
		activeTimeout = null;
		WebView wv = activeWebView;
		activeWebView = null;
		if (wv != null) {
			try {
				ViewGroup parent = (ViewGroup) wv.getParent();
				if (parent != null) parent.removeView(wv);
				wv.stopLoading();
				wv.destroy();
			} catch (Throwable t) {
				safeLog("teardown: " + t);
			}
		}
		safeLog("teardown of generation " + gen + " (" + reason + "): timeout cancelled, WebView destroyed on thread " + Thread.currentThread().getName());
	}

	/** Activity or Godot termination: cancel on the UI thread, emit nothing. */
	private void cancelForLifecycle(final String reason) {
		Runnable r = () -> {
			int gen = liveGeneration.get();
			if (gen == 0) {
				safeLog(reason + ": no active read");
				return;
			}
			teardown("lifecycle " + reason);
			safeLog(reason + ": cancelled active read attempt " + activeAttempt + " (generation " + gen + "); no result emitted");
		};
		if (Looper.myLooper() == Looper.getMainLooper()) {
			r.run();
		} else {
			handler.post(r);
		}
	}

	/** Interception thread: waits up to holdMs, returning early once the generation is no longer live. */
	private void hold(int gen, long holdMs) {
		safeLog("holding the page of generation " + gen + " for up to " + holdMs + " ms (lifecycle test)");
		long end = SystemClock.uptimeMillis() + holdMs;
		while (SystemClock.uptimeMillis() < end && liveGeneration.get() == gen) {
			SystemClock.sleep(50);
		}
	}

	private JSONObject result(int attempt, String jsValue, JSONObject diag) {
		JSONObject out = base(attempt, diag);
		try {
			Object decoded = new JSONTokener(jsValue == null ? "null" : jsValue).nextValue();
			if (!(decoded instanceof String)) return failure(attempt, "script_returned_no_result", diag, String.valueOf(jsValue));
			JSONObject page = new JSONObject((String) decoded);
			String origin = page.optString("origin", "");
			put(out, "verified_origin", origin);
			put(diag, "document_href", page.optString("href", ""));
			put(diag, "user_agent", page.optString("user_agent", ""));
			if (!ORIGIN.equals(origin)) return failure(attempt, "origin_mismatch", diag, origin);
			if (!page.isNull("storage_error")) return failure(attempt, "storage_unavailable", diag, page.optString("storage_error"));
			JSONObject keys = page.getJSONObject("keys");
			JSONObject outKeys = new JSONObject();
			int present = 0;
			int errors = 0;
			for (String k : KEYS) {
				JSONObject r = keys.getJSONObject(k);
				JSONObject o = new JSONObject();
				o.put("storage_key", PREFIX + k);
				o.put("present", r.getBoolean("present"));
				o.put("raw", r.isNull("value") ? JSONObject.NULL : r.getString("value"));
				o.put("error", r.isNull("error") ? JSONObject.NULL : r.getString("error"));
				if (r.getBoolean("present")) present++;
				if (!r.isNull("error")) errors++;
				outKeys.put(k, o);
			}
			out.put("keys", outKeys);
			out.put("present_count", present);
			out.put("status", errors > 0 ? "error" : (present == 0 ? "not_found" : "success"));
			if (errors > 0) out.put("error", "key_read_error");
			safeLog("attempt " + attempt + ": status=" + out.getString("status") + " origin=" + origin + " present=" + present);
		} catch (Throwable e) {
			return failure(attempt, "result_decode_failed", diag, e.toString());
		}
		return out;
	}

	private JSONObject base(int attempt, JSONObject diag) {
		JSONObject o = new JSONObject();
		put(o, "spike", "sv_m1_migration_spike");
		put(o, "attempt", attempt);
		put(o, "timestamp_utc", now());
		put(o, "expected_origin", ORIGIN);
		put(o, "verified_origin", JSONObject.NULL);
		put(o, "webview_package", webViewPackage());
		put(o, "android_sdk_int", Build.VERSION.SDK_INT);
		put(o, "diagnostics", diag == null ? new JSONObject() : diag);
		return o;
	}

	private JSONObject failure(int attempt, String error, JSONObject diag, String detail) {
		JSONObject o = base(attempt, diag);
		put(o, "status", "error");
		put(o, "error", error);
		put(o, "error_detail", detail == null ? JSONObject.NULL : detail);
		put(o, "keys", JSONObject.NULL);
		safeLog("attempt " + attempt + ": error " + error + (detail == null ? "" : " (" + detail + ")"));
		return o;
	}

	/** Never throws: each diagnostic is guarded, a failing one is reported in place. */
	private static JSONObject diagnostics(Activity activity, long holdMs) {
		JSONObject diag = new JSONObject();
		put(diag, "page_url", PAGE_URL);
		if (holdMs > 0) put(diag, "lifecycle_test_hold_ms", holdMs);
		try {
			File webviewDir = new File(new File(activity.getApplicationInfo().dataDir), "app_webview");
			put(diag, "webview_data_dir_existed_before_read", webviewDir.isDirectory());
			put(diag, "local_storage_dir_existed_before_read", new File(webviewDir, "Default" + File.separator + "Local Storage").isDirectory());
			// Older WebViews (for example 53 on Android 7) keep Local Storage directly under app_webview.
			put(diag, "root_local_storage_dir_existed_before_read", new File(webviewDir, "Local Storage").isDirectory());
		} catch (Throwable t) {
			put(diag, "data_dir_diagnostic_error", t.toString());
		}
		try {
			put(diag, "package_name", activity.getPackageName());
			put(diag, "app_version_code", versionCode(activity));
		} catch (Throwable t) {
			put(diag, "package_diagnostic_error", t.toString());
		}
		if (Build.VERSION.SDK_INT < 26) {
			put(diag, "webview_package_unavailable", "WebView.getCurrentWebViewPackage() needs API 26; device API " + Build.VERSION.SDK_INT + " (see user_agent)");
		}
		return diag;
	}

	/** The WebView provider package, or JSON null below API 26 or on any failure. */
	@SuppressWarnings("deprecation")
	private static Object webViewPackage() {
		if (Build.VERSION.SDK_INT < 26) return JSONObject.NULL;
		try {
			PackageInfo p = WebView.getCurrentWebViewPackage();
			if (p == null) return JSONObject.NULL;
			JSONObject o = new JSONObject();
			o.put("package", p.packageName);
			o.put("version_name", p.versionName);
			o.put("version_code", Build.VERSION.SDK_INT >= 28 ? p.getLongVersionCode() : p.versionCode);
			return o;
		} catch (Throwable t) {
			return JSONObject.NULL;
		}
	}

	@SuppressWarnings("deprecation")
	private static long versionCode(Activity a) throws Exception {
		PackageInfo p = a.getPackageManager().getPackageInfo(a.getPackageName(), 0);
		return Build.VERSION.SDK_INT >= 28 ? p.getLongVersionCode() : p.versionCode;
	}

	/** Emits once; serialization or signal failures are logged, never thrown. */
	private void emit(int attempt, JSONObject o) {
		String s;
		try {
			s = o.toString();
		} catch (Throwable t) {
			s = "{\"spike\":\"sv_m1_migration_spike\",\"attempt\":" + attempt + ",\"status\":\"error\",\"error\":\"result_serialization_failed\",\"keys\":null}";
		}
		safeLog("emit attempt " + attempt + " status=" + o.optString("status", "?"));
		try {
			emitSignal("legacy_read_completed", s);
		} catch (Throwable t) {
			safeLog("emitSignal failed: " + t);
		}
	}

	private static WebResourceResponse empty(int code, String reason) {
		return new WebResourceResponse("text/plain", "utf-8", code, reason, Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
	}

	private static String now() {
		try {
			SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
			f.setTimeZone(TimeZone.getTimeZone("UTC"));
			return f.format(new Date());
		} catch (Throwable t) {
			return "";
		}
	}

	private static void safeLog(String m) {
		try {
			Log.i(TAG, m);
		} catch (Throwable ignored) {
			// Logging never blocks a result.
		}
	}

	private static void put(JSONObject o, String k, Object v) {
		try {
			o.put(k, v);
		} catch (Throwable ignored) {
			// org.json only throws for non-finite numbers.
		}
	}
}
