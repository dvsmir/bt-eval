package com.shopkit.checkout;

import com.shopkit.pricing.Money;

/** What the storefront shows after a basket is paid for. */
public record Receipt(int lineCount, long totalCents) {

    public String summary() {
        return lineCount + " line(s), total " + Money.format(totalCents);
    }
}
