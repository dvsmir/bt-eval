package com.example.ingest;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/** Build-time settings, baked into the jar by the resource filter. */
public final class BuildInfo {

    private static final Properties VALUES = load();

    private BuildInfo() {
    }

    private static Properties load() {
        Properties props = new Properties();
        try (InputStream in = BuildInfo.class.getResourceAsStream("/build-info.properties")) {
            if (in != null) {
                props.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("cannot read build-info.properties", e);
        }
        return props;
    }

    public static String sinkFormat() {
        return VALUES.getProperty("sink.format", "unknown");
    }

    public static int batchSize() {
        return Integer.parseInt(VALUES.getProperty("sink.batch.size", "0"));
    }
}
