package com.example.audit.core;

import java.util.List;

/** The audit entries that every report contains. */
public final class AuditCatalog {

    private AuditCatalog() {
    }

    public static List<AuditEntry> defaults() {
        return List.of(
                new AuditEntry("Quarterly Revenue Review", "OK"),
                new AuditEntry("Vendor Access Audit", "OK"),
                new AuditEntry("Data Retention Check", "WARN"));
    }
}
