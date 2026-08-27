package com.shopkit.pricing;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class MoneyTest {

    @Test
    public void formatsWholeAmounts() {
        assertEquals("12.00", Money.format(1200L));
    }

    @Test
    public void formatsCents() {
        assertEquals("23.36", Money.format(2336L));
    }

    @Test
    public void padsASingleCent() {
        assertEquals("0.05", Money.format(5L));
    }
}
