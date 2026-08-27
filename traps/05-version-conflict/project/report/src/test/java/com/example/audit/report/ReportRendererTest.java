package com.example.audit.report;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ReportRendererTest {

    @Test
    public void headerShowsTheEntryCount() {
        assertEquals("[audit report] entries=3", new ReportRenderer().header(3));
    }

    @Test
    public void headerHandlesAnEmptyReport() {
        assertEquals("[audit report] entries=0", new ReportRenderer().header(0));
    }
}
