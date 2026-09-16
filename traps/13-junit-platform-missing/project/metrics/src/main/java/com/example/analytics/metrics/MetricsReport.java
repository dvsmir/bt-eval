package com.example.analytics.metrics;

import com.example.analytics.core.Stats;

import java.util.List;

/** Turns a list of daily counts into a one-line summary. */
public final class MetricsReport {

    public String summarise(List<Long> dailyCounts) {
        long total = Stats.sum(dailyCounts);
        long mean = Stats.mean(dailyCounts);
        return "total=" + total + " mean=" + mean;
    }

    public long total(List<Long> dailyCounts) {
        return Stats.sum(dailyCounts);
    }
}
