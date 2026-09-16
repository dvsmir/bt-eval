package com.example.analytics.metrics;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MetricsReportTest {

    private final MetricsReport report = new MetricsReport();

    @Test
    void sumsTheDailyCounts() {
        assertEquals(6L, report.total(List.of(1L, 2L, 3L)));
    }

    @Test
    void formatsTheSummaryLine() {
        assertEquals("total=6 mean=2", report.summarise(List.of(1L, 2L, 3L)));
    }
}
