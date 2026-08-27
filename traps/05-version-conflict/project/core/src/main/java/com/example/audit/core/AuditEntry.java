package com.example.audit.core;

import java.util.Objects;

/** One line of the audit report. */
public final class AuditEntry {

    private final String title;
    private final String status;

    public AuditEntry(String title, String status) {
        this.title = Objects.requireNonNull(title, "title");
        this.status = Objects.requireNonNull(status, "status");
    }

    public String title() {
        return title;
    }

    public String status() {
        return status;
    }

    @Override
    public String toString() {
        return title + "/" + status;
    }
}
