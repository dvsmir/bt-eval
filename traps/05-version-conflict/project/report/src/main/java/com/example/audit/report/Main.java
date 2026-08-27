package com.example.audit.report;

import com.example.audit.core.AuditCatalog;
import com.example.audit.core.AuditEntry;
import java.util.List;

/** Prints the audit report to standard output. */
public final class Main {

    private Main() {
    }

    public static void main(String[] args) {
        ReportRenderer renderer = new ReportRenderer();
        List<AuditEntry> entries = AuditCatalog.defaults();
        System.out.println(renderer.header(entries.size()));
        for (AuditEntry entry : entries) {
            System.out.println(renderer.line(entry));
        }
    }
}
