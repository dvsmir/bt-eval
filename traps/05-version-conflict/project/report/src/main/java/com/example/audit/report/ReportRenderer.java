package com.example.audit.report;

import com.example.acme.audit.AuditStamp;
import com.example.audit.core.AuditEntry;
import com.example.fakelib.TextKit;

/** Turns audit entries into report text. */
public final class ReportRenderer {

    /** The first line of the report. */
    public String header(int entryCount) {
        return AuditStamp.stamp("audit report") + " entries=" + entryCount;
    }

    /** One report line per entry. */
    public String line(AuditEntry entry) {
        return "- " + TextKit.normalize(entry.title()) + " : " + entry.status();
    }
}
