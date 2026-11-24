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
 * result from being emitted.
 *
 * Lifecycle: one read at a time. Its generation is reserved on the caller's thread before start()
 * is posted to the UI thread (pending), and stays reserved while its WebView runs (active).
 * Activity destruction or Godot termination marks the plugin terminated, bumps the lifecycle
 * epoch and clears the reservation, which invalidates a pending start and an active read alike;
 * the timeout and WebView of an active read are then destroyed on the UI thread. start() creates
 * no WebView for a stale epoch, an invalidated generation, a terminated plugin or a finishing or
 * destroyed Activity, and every late page, interception or evaluateJavascript callback of a
 * finished or cancelled generation is ignored: nothing is emitted for a cancelled read. The spike
 * treats termination as final for the plugin instance (its single Activity does not come back).
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
	/** Development-only lifecycle test: start() is posted this much later, so termination lands while it is still queued. */
	static final long LIFECYCLE_QUEUE_DELAY_MS = 5000;

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
	private final AtomicInteger generationCounter = new AtomicInteger(0);
	/**
	 * The reserved read's generation, 0 when idle: set on the caller's thread before start() is
	 * posted (pending), kept while its WebView runs (active), cleared by completion or by lifecycle
	 * termination. Read by the UI, interception and caller threads.
	 */
	private final AtomicInteger liveGeneration = new AtomicInteger(0);
	/** Bumped by every lifecycle termination: a start() queued in an older epoch is stale. */
	private final AtomicInteger lifecycleEpoch = new AtomicInteger(0);
	/** Set (before the epoch is bumped) by Activity destruction or Godot termination: no read starts afterwards. */
	private volatile boolean terminated = false;
	// Active-read state: UI thread only.
	private WebView activeWebView = null;
	private Runnable activeTimeout = null;
	private int activeAttempt = 0;
	private int activeGeneration = 0;
	/** The last generation whose start() passed its guard (a WebView was created for it); UI thread only. */
	private int startedGeneration = 0;

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
		request(0, 0);
	}

	/**
	 * Development-only (lifecycle test): the same read, but the intercepted page is held for
	 * LIFECYCLE_HOLD_MS, so Activity destruction or Godot termination happens while it is active.
	 */
	@UsedByGodot
	public void readLegacyStoreHeldForLifecycleTest() {
		request(LIFECYCLE_HOLD_MS, 0);
	}

	/**
	 * Development-only (lifecycle test): the same read (the generation is reserved exactly as by
	 * readLegacyStore), but start() is posted LIFECYCLE_QUEUE_DELAY_MS later, so a termination
	 * requested right after it lands while the start is still queued.
	 */
	@UsedByGodot
	public void readLegacyStoreQueuedForLifecycleTest() {
		request(0, LIFECYCLE_QUEUE_DELAY_MS);
	}

	/**
	 * Development-only (lifecycle test): finishes the host Activity, so its real onDestroy (and
	 * this plugin's onMainDestroy) runs while a read is pending or active.
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

	/** Caller's thread: reserves a generation (or reports busy), then posts start() to the UI thread. */
	private void request(final long holdMs, final long queueDelayMs) {
		final int attempt = attempts.incrementAndGet();
		// The epoch is read before `terminated`: a termination after this read changes the epoch,
		// one before it is seen as `terminated` (it is set before the epoch is bumped).
		final int epoch = lifecycleEpoch.get();
		if (terminated) {
			safeLog("attempt " + attempt + ": refused after termination (epoch " + epoch + "); no WebView created, nothing emitted");
			return;
		}
		final Activity activity = getActivity();
		if (activity == null) {
			emit(attempt, failure(attempt, "no_activity", null, null));
			return;
		}
		final int gen = generationCounter.incrementAndGet();
		if (!liveGeneration.compareAndSet(0, gen)) {
			emit(attempt, failure(attempt, "busy", null, null));
			return;
		}
		safeLog("attempt " + attempt + ": reserved generation " + gen + " (epoch " + epoch + ") on thread " + threadName()
				+ "; start queued on the UI thread" + (queueDelayMs > 0 ? " in " + queueDelayMs + " ms (lifecycle test)" : ""));
		final Runnable start = () -> start(activity, attempt, gen, epoch, holdMs);
		if (queueDelayMs > 0) {
			handler.postDelayed(start, queueDelayMs);
		} else {
			handler.post(start);
		}
	}

	/** UI thread. Creates no WebView (and emits nothing) for a stale or invalidated request. */
	private void start(final Activity activity, final int attempt, final int gen, final int epoch, final long holdMs) {
		final String stale = staleReason(activity, gen, epoch);
		if (stale != null) {
			liveGeneration.compareAndSet(gen, 0);
			safeLog("discarded queued start of attempt " + attempt + " (generation " + gen + "): " + stale + "; no WebView created, nothing emitted");
			return;
		}
		startedGeneration = gen;
		activeGeneration = gen;
		activeAttempt = attempt;
		final JSONObject diag = diagnostics(activity, holdMs);
		safeLog("attempt " + attempt + " (generation " + gen + "): creating the WebView, loading " + PAGE_URL + " diag=" + diag);
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

	/** UI thread: why a queued start must not create a WebView, or null when it may. */
	private String staleReason(Activity activity, int gen, int epoch) {
		StringBuilder b = new StringBuilder();
		if (terminated) b.append("plugin terminated");
		int now = lifecycleEpoch.get();
		if (now != epoch) b.append(b.length() == 0 ? "" : ", ").append("stale epoch ").append(epoch).append(" (now ").append(now).append(')');
		int live = liveGeneration.get();
		if (live != gen) b.append(b.length() == 0 ? "" : ", ").append("generation invalidated (reserved: ").append(live).append(')');
		try {
			if (activity.isFinishing()) b.append(b.length() == 0 ? "" : ", ").append("Activity finishing");
			if (activity.isDestroyed()) b.append(b.length() == 0 ? "" : ", ").append("Activity destroyed");
		} catch (Throwable t) {
			b.append(b.length() == 0 ? "" : ", ").append("Activity state unavailable: ").append(t);
		}
		return b.length() == 0 ? null : b.toString();
	}

	/** UI thread: ends generation `gen` once (later calls are ignored) and emits its result. */
	private void finish(int gen, int attempt, JSONObject result) {
		if (!liveGeneration.compareAndSet(gen, 0)) {
			safeLog("ignored late completion of generation " + gen);
			return;
		}
		teardown("completed");
		emit(attempt, result);
	}

	/** UI thread: cancels the timeout and destroys the WebView of the active read, if any. */
	private void teardown(String reason) {
		int gen = activeGeneration;
		activeGeneration = 0;
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
		safeLog("teardown of generation " + gen + " (" + reason + "): timeout cancelled, WebView destroyed on thread " + threadName());
	}

	/**
	 * Activity or Godot termination, on whichever thread delivers it: marks the plugin terminated,
	 * bumps the epoch and clears the reserved generation at once (a queued start is now stale), then
	 * destroys an active read's timeout and WebView on the UI thread. Emits nothing.
	 */
	private void cancelForLifecycle(final String reason) {
		terminated = true;
		final int epoch = lifecycleEpoch.incrementAndGet();
		final int gen = liveGeneration.getAndSet(0);
		safeLog(reason + " on thread " + threadName() + ": epoch " + epoch
				+ (gen == 0 ? ", no reserved generation" : ", invalidated reserved generation " + gen));
		// UI thread: whatever is still active is torn down here, whichever termination invalidated it.
		Runnable ui = () -> {
			if (activeWebView != null || activeTimeout != null) {
				int g = activeGeneration;
				int a = activeAttempt;
				teardown("lifecycle " + reason);
				safeLog(reason + ": cancelled active read attempt " + a + " (generation " + g + "); no result emitted");
			} else if (gen != 0 && gen > startedGeneration) {
				safeLog(reason + ": generation " + gen + " was still queued (no WebView); its start is discarded, nothing emitted");
			} else if (gen != 0) {
				safeLog(reason + ": generation " + gen + " was already torn down; nothing emitted");
			}
		};
		if (Looper.myLooper() == Looper.getMainLooper()) {
			ui.run();
		} else {
			handler.post(ui);
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
			// A per-key error makes the whole read an error: success and not_found carry only null key errors.
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

	private static String threadName() {
		try {
			return Thread.currentThread().getName();
		} catch (Throwable t) {
			return "?";
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
