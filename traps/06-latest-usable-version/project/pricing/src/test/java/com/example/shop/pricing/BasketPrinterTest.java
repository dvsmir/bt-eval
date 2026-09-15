package com.example.shop.pricing;

import static org.junit.Assert.assertEquals;

import com.example.shop.core.LineItem;
import java.util.List;
import org.junit.Test;

public class BasketPrinterTest {

    @Test
    public void rendersOneLinePerItem() {
        String out = new BasketPrinter().render(List.of(
                new LineItem("HAMMER-01", 2, 1250),
                new LineItem("NAILS-100", 1, 399)));
        assertEquals(2, out.strip().split("\n").length);
    }

    @Test
    public void includesTheSku() {
        String out = new BasketPrinter().render(List.of(new LineItem("HAMMER-01", 1, 1250)));
        assertEquals(true, out.contains("HAMMER-01"));
    }
}
