package com.example.shop.pricing;

import com.acme.widgets.WidgetFormatter;
import com.example.shop.core.LineItem;
import java.util.List;

/** Renders a basket for the order confirmation mail. */
public final class BasketPrinter {

    public String render(List<LineItem> items) {
        StringBuilder out = new StringBuilder();
        for (LineItem item : items) {
            out.append(WidgetFormatter.describe(item.sku(), item.totalCents()));
            out.append('\n');
        }
        return out.toString();
    }
}
