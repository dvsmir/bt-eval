package com.shopkit.checkout;

import static org.junit.Assert.assertEquals;

import com.shopkit.pricing.LineItem;
import java.util.List;
import org.junit.Test;

/** Walks a whole basket through the checkout flow, the way the storefront does. */
public class CheckoutFlowIT {

    private static final List<LineItem> SPRING_SALE_BASKET = List.of(
            new LineItem("SK-1001", 999L, 1),
            new LineItem("SK-2042", 1499L, 1),
            new LineItem("SK-3300", 250L, 1));

    private final CheckoutService service = new CheckoutService();

    @Test
    public void springSaleBasketIsChargedTheAdvertisedAmount() {
        Receipt receipt = service.checkout(SPRING_SALE_BASKET, 15);
        assertEquals(3, receipt.lineCount());
        assertEquals(2336L, receipt.totalCents());
    }

    @Test
    public void springSaleBasketAtListPrice() {
        Receipt receipt = service.checkout(SPRING_SALE_BASKET, 0);
        assertEquals(2748L, receipt.totalCents());
    }
}
