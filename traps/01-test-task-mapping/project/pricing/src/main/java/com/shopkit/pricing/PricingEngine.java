package com.shopkit.pricing;

import java.util.List;

/** Turns a basket into an amount to charge. */
public final class PricingEngine {

    private PricingEngine() {
    }

    /**
     * Total of the given lines in cents after a whole percent discount.
     *
     * @param items           the basket lines
     * @param discountPercent a whole percent between 0 and 100
     */
    public static long discountedTotalCents(List<LineItem> items, int discountPercent) {
        if (discountPercent < 0 || discountPercent > 100) {
            throw new IllegalArgumentException("discountPercent must be between 0 and 100");
        }
        long total = 0L;
        for (LineItem item : items) {
            long gross = item.grossCents();
            total += gross - (gross * discountPercent) / 100L;
        }
        return total;
    }
}
