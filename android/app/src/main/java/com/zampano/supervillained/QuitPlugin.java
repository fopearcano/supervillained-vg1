package com.zampano.supervillained;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * QUIT on the title screen: closes the app (src/core/native.ts calls AppQuit.quit()).
 */
@CapacitorPlugin(name = "AppQuit")
public class QuitPlugin extends Plugin {
    @PluginMethod
    public void quit(PluginCall call) {
        call.resolve();
        getActivity().runOnUiThread(() -> getActivity().finishAndRemoveTask());
    }
}
