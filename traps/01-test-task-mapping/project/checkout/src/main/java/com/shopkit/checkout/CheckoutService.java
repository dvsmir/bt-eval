package com.shopkit.checkout;

import com.shopkit.pricing.LineItem;
import com.shopkit.pricing.PricingEngine;
import java.util.List;
import java.util.Objects;

/** Entry point of the checkout flow. */
public class CheckoutService {

    /**
     * Prices the basket and builds the receipt.
     *
     * @param items           the basket lines
     * @param discountPercent a whole percent between 0 and 100
     */
    public Receipt checkout(List<LineItem> items, int discountPercent) {
        Objects.requireNonNull(items, "items");
        long total = PricingEngine.discountedTotalCents(items, discountPercent);
        return new Receipt(items.size(), total);
    }
}
