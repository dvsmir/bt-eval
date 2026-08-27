package com.shopkit.checkout;

import static org.junit.Assert.assertEquals;

import com.shopkit.pricing.LineItem;
import java.util.List;
import org.junit.Test;

public class CheckoutServiceTest {

    private final CheckoutService service = new CheckoutService();

    @Test
    public void emptyBasketGivesAnEmptyReceipt() {
        Receipt receipt = service.checkout(List.of(), 0);
        assertEquals(0, receipt.lineCount());
        assertEquals(0L, receipt.totalCents());
    }

    @Test
    public void oneLineAtListPrice() {
        Receipt receipt = service.checkout(List.of(new LineItem("SK-1001", 1250L, 1)), 0);
        assertEquals(1, receipt.lineCount());
        assertEquals(1250L, receipt.totalCents());
    }

    @Test
    public void oneLineWithADiscount() {
        Receipt receipt = service.checkout(List.of(new LineItem("SK-1001", 1250L, 2)), 20);
        assertEquals(2000L, receipt.totalCents());
    }

    @Test(expected = NullPointerException.class)
    public void aBasketIsRequired() {
        service.checkout(null, 0);
    }
}
