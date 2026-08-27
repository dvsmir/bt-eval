package com.example.audit.core;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class AuditEntryTest {

    @Test
    public void keepsTitleAndStatus() {
        AuditEntry entry = new AuditEntry("Vendor Access Audit", "OK");
        assertEquals("Vendor Access Audit", entry.title());
        assertEquals("OK", entry.status());
    }

    @Test
    public void printsTitleAndStatus() {
        assertEquals("A/OK", new AuditEntry("A", "OK").toString());
    }
}
