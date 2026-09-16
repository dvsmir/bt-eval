package com.example.releasetool;

/** Every startup banner and log header goes through here. */
public final class Banner {
    public static String line() {
        return "releasetool " + BuildInfo.VERSION + " (channel=" + BuildInfo.CHANNEL + ")";
    }

    private Banner() {
    }
}
