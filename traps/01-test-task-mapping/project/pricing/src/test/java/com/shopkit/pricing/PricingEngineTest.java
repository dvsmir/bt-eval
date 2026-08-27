package com.shopkit.pricing;

import static org.junit.Assert.assertEquals;

import java.util.List;
import org.junit.Test;

public class PricingEngineTest {

    @Test
    public void emptyBasketCostsNothing() {
        assertEquals(0L, PricingEngine.discountedTotalCents(List.of(), 25));
    }

    @Test
    public void singleLineWithoutDiscount() {
        List<LineItem> basket = List.of(new LineItem("SK-1001", 1000L, 1));
        assertEquals(1000L, PricingEngine.discountedTotalCents(basket, 0));
    }

    @Test
    public void singleLineWithDiscount() {
        List<LineItem> basket = List.of(new LineItem("SK-1001", 1000L, 1));
        assertEquals(900L, PricingEngine.discountedTotalCents(basket, 10));
    }

    @Test
    public void quantityMultipliesTheLine() {
        List<LineItem> basket = List.of(new LineItem("SK-1001", 1000L, 3));
        assertEquals(1500L, PricingEngine.discountedTotalCents(basket, 50));
    }

    @Test
    public void twoLinesWithHalfOff() {
        List<LineItem> basket = List.of(
                new LineItem("SK-1001", 1000L, 1),
                new LineItem("SK-2042", 2000L, 1));
        assertEquals(1500L, PricingEngine.discountedTotalCents(basket, 50));
    }

    @Test(expected = IllegalArgumentException.class)
    public void discountAboveOneHundredIsRejected() {
        PricingEngine.discountedTotalCents(List.of(), 101);
    }
}
