package com.acme.fleet.core;

import java.util.Objects;

/** One telemetry alert that a fleet device raised. */
public final class Alert {

    private final Severity severity;
    private final String source;
    private final String message;

    public Alert(Severity severity, String source, String message) {
        this.severity = Objects.requireNonNull(severity, "severity");
        this.source = Objects.requireNonNull(source, "source");
        this.message = Objects.requireNonNull(message, "message");
    }

    public Severity severity() {
        return severity;
    }

    public String source() {
        return source;
    }

    public String message() {
        return message;
    }

    @Override
    public String toString() {
        return severity + " " + source + " " + message;
    }
}
