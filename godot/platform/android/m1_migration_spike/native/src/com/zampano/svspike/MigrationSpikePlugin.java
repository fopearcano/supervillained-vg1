package com.zampano.svspike;

import android.app.Activity;
import android.content.pm.PackageInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
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

	private static final String PAGE = "<!doctype html><html><head><meta charset=\"utf-8\"><title>m1</title></head><body></body></html>";
	/** Read-only: getItem on the five prefixed keys, nothing else. */
	private static final String READ_JS =
			"(function(){var keys=['settings','records','coins','story','story-v1-backup'];"
			+ "var out={origin:location.origin,href:location.href,keys:{},storage_error:null};var ls=null;"
			+ "try{ls=window.localStorage;}catch(e){out.storage_error='localStorage access: '+String(e);return JSON.stringify(out);}"
			+ "if(!ls){out.storage_error='localStorage unavailable';return JSON.stringify(out);}"
			+ "for(var i=0;i<keys.length;i++){var r={present:false,value:null,error:null};"
			+ "try{var v=ls.getItem('" + PREFIX + "'+keys[i]);r.present=(v!==null);r.value=v;}catch(e){r.error=String(e);}"
			+ "out.keys[keys[i]]=r;}return JSON.stringify(out);})()";

	private final Handler handler = new Handler(Looper.getMainLooper());
	private boolean busy = false;
	private int attempts = 0;

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
		final Activity activity = getActivity();
		final int attempt = ++attempts;
		if (activity == null) {
			emitSignal("legacy_read_completed", failure(attempt, "no_activity", null, null).toString());
			return;
		}
		activity.runOnUiThread(() -> start(activity, attempt));
	}

	private void start(Activity activity, int attempt) {
		if (busy) {
			emitSignal("legacy_read_completed", failure(attempt, "busy", null, null).toString());
			return;
		}
		busy = true;
		final File dataDir = new File(activity.getApplicationInfo().dataDir);
		final File webviewDir = new File(dataDir, "app_webview");
		final File localStorageDir = new File(webviewDir, "Default" + File.separator + "Local Storage");
		final JSONObject diag = new JSONObject();
		put(diag, "page_url", PAGE_URL);
		put(diag, "webview_data_dir_existed_before_read", webviewDir.isDirectory());
		put(diag, "local_storage_dir_existed_before_read", localStorageDir.isDirectory());
		put(diag, "package_name", activity.getPackageName());
		put(diag, "app_version_code", versionCode(activity));
		Log.i(TAG, "attempt " + attempt + ": loading " + PAGE_URL + " diag=" + diag);

		final WebView[] holder = new WebView[1];
		final boolean[] done = { false };
		final Runnable[] finish = new Runnable[1];
		final Runnable timeout = () -> {
			if (done[0]) return;
			done[0] = true;
			cleanup(holder[0]);
			emitSignal("legacy_read_completed", failure(attempt, "timeout", diag, null).toString());
		};
		try {
			WebView wv = new WebView(activity);
			holder[0] = wv;
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
						return new WebResourceResponse("text/html", "utf-8", 200, "OK", Collections.emptyMap(),
								new ByteArrayInputStream(PAGE.getBytes(StandardCharsets.UTF_8)));
					}
					Log.i(TAG, "blocked request " + url);
					return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", Collections.emptyMap(),
							new ByteArrayInputStream(new byte[0]));
				}

				@Override
				public void onPageFinished(WebView view, String url) {
					if (done[0] || !PAGE_URL.equals(url)) return;
					view.evaluateJavascript(READ_JS, value -> {
						if (done[0]) return;
						done[0] = true;
						handler.removeCallbacks(timeout);
						cleanup(view);
						emitSignal("legacy_read_completed", result(attempt, value, diag).toString());
					});
				}
			});
			ViewGroup root = activity.findViewById(android.R.id.content);
			root.addView(wv, new FrameLayout.LayoutParams(1, 1));
			handler.postDelayed(timeout, TIMEOUT_MS);
			wv.loadUrl(PAGE_URL);
		} catch (Throwable t) {
			done[0] = true;
			handler.removeCallbacks(timeout);
			cleanup(holder[0]);
			emitSignal("legacy_read_completed", failure(attempt, "webview_unavailable", diag, t.toString()).toString());
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
			Log.i(TAG, "attempt " + attempt + ": status=" + out.getString("status") + " origin=" + origin + " present=" + present);
		} catch (Exception e) {
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
		Log.w(TAG, "attempt " + attempt + ": error " + error + (detail == null ? "" : " (" + detail + ")"));
		return o;
	}

	private void cleanup(WebView wv) {
		busy = false;
		if (wv == null) return;
		try {
			ViewGroup parent = (ViewGroup) wv.getParent();
			if (parent != null) parent.removeView(wv);
			wv.stopLoading();
			wv.destroy();
		} catch (Throwable t) {
			Log.w(TAG, "cleanup: " + t);
		}
	}

	@SuppressWarnings("deprecation")
	private static Object webViewPackage() {
		JSONObject o = new JSONObject();
		try {
			PackageInfo p = WebView.getCurrentWebViewPackage();
			if (p == null) return JSONObject.NULL;
			o.put("package", p.packageName);
			o.put("version_name", p.versionName);
			o.put("version_code", Build.VERSION.SDK_INT >= 28 ? p.getLongVersionCode() : p.versionCode);
		} catch (Exception e) {
			return JSONObject.NULL;
		}
		return o;
	}

	@SuppressWarnings("deprecation")
	private static long versionCode(Activity a) {
		try {
			PackageInfo p = a.getPackageManager().getPackageInfo(a.getPackageName(), 0);
			return Build.VERSION.SDK_INT >= 28 ? p.getLongVersionCode() : p.versionCode;
		} catch (Exception e) {
			return -1;
		}
	}

	private static String now() {
		SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
		f.setTimeZone(TimeZone.getTimeZone("UTC"));
		return f.format(new Date());
	}

	private static void put(JSONObject o, String k, Object v) {
		try {
			o.put(k, v);
		} catch (Exception ignored) {
			// org.json only throws for non-finite numbers.
		}
	}
}
