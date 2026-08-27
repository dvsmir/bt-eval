package com.shopkit.pricing;

import java.util.Objects;

/** One line of a basket. */
public record LineItem(String sku, long unitPriceCents, int quantity) {

    public LineItem {
        Objects.requireNonNull(sku, "sku");
        if (unitPriceCents < 0) {
            throw new IllegalArgumentException("unitPriceCents must not be negative");
        }
        if (quantity < 1) {
            throw new IllegalArgumentException("quantity must be at least 1");
        }
    }

    /** Price of the whole line, before any discount. */
    public long grossCents() {
        return unitPriceCents * quantity;
    }
}
