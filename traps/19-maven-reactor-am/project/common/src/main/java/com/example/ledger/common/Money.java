package com.example.ledger.common;
public final class Money {
    private Money() {}
    public static long cents(double dollars) { return Math.round(dollars * 100.0); }
}
