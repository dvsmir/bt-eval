package com.shopkit.pricing;

/** Formats an amount in cents for display. */
public final class Money {

    private Money() {
    }

    public static String format(long cents) {
        long whole = cents / 100;
        long fraction = Math.abs(cents % 100);
        return String.format("%d.%02d", whole, fraction);
    }
}
