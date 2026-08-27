package telemetry.api;

import java.util.Objects;

/**
 * One value that a collector reported.
 */
public final class Measurement {

    private final String name;
    private final double value;
    private final long timestampMillis;

    public Measurement(String name, double value, long timestampMillis) {
        this.name = Objects.requireNonNull(name, "name");
        this.value = value;
        this.timestampMillis = timestampMillis;
    }

    public String name() {
        return name;
    }

    public double value() {
        return value;
    }

    public long timestampMillis() {
        return timestampMillis;
    }

    @Override
    public String toString() {
        return name + "=" + value + "@" + timestampMillis;
    }
}
