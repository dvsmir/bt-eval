package com.shopkit.pricing;

import static org.junit.Assert.assertEquals;

import java.util.List;
import org.junit.Test;

/** Prices a basket that is taken from the seed catalogue of the staging shop. */
public class CatalogPricingIT {

    private static final List<LineItem> SEED_BASKET = List.of(
            new LineItem("SK-1001", 500L, 2),
            new LineItem("SK-2042", 2500L, 1));

    @Test
    public void seedBasketAtListPrice() {
        assertEquals(3500L, PricingEngine.discountedTotalCents(SEED_BASKET, 0));
    }

    @Test
    public void seedBasketWithTheStaffDiscount() {
        assertEquals(2800L, PricingEngine.discountedTotalCents(SEED_BASKET, 20));
    }

    @Test
    public void seedBasketTotalIsPrintable() {
        assertEquals("28.00", Money.format(PricingEngine.discountedTotalCents(SEED_BASKET, 20)));
    }
}
