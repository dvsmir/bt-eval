package com.example.audit.core;

import static org.junit.Assert.assertEquals;

import java.util.List;
import org.junit.Test;

public class AuditCatalogTest {

    @Test
    public void catalogHasThreeEntries() {
        List<AuditEntry> entries = AuditCatalog.defaults();
        assertEquals(3, entries.size());
    }

    @Test
    public void firstEntryIsTheRevenueReview() {
        AuditEntry first = AuditCatalog.defaults().get(0);
        assertEquals("Quarterly Revenue Review", first.title());
        assertEquals("OK", first.status());
    }
}
