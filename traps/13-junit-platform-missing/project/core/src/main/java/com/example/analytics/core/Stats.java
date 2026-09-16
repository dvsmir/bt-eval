package com.example.analytics.core;

import java.util.List;

/** Small numeric helpers shared across the analytics modules. */
public final class Stats {
    private Stats() {
    }

    public static long sum(List<Long> values) {
        long total = 0L;
        for (Long v : values) {
            total += v;
        }
        return total;
    }

    public static long mean(List<Long> values) {
        if (values.isEmpty()) {
            return 0L;
        }
        return sum(values) / values.size();
    }
}
