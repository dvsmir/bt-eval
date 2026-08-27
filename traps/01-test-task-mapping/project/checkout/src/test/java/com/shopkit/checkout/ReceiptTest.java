package com.shopkit.checkout;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ReceiptTest {

    @Test
    public void summaryShowsTheLineCountAndTheTotal() {
        assertEquals("2 line(s), total 23.36", new Receipt(2, 2336L).summary());
    }

    @Test
    public void summaryOfAnEmptyReceipt() {
        assertEquals("0 line(s), total 0.00", new Receipt(0, 0L).summary());
    }
}
