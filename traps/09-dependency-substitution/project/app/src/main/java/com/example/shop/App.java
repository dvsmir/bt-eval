package com.example.shop;

import com.acme.widgets.WidgetFormatter;

/** Prints one formatted widget line for the receipt footer. */
public final class App {

    public static void main(String[] args) {
        System.out.println(WidgetFormatter.describe("mesh-router", 4999));
        System.out.println("rounding=" + WidgetFormatter.roundingMode());
        System.out.println("widgets=" + WidgetFormatter.release());
    }
}
