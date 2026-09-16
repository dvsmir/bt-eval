package com.example.ledger.service;
import com.example.ledger.common.Money;
public final class Invoice {
    public long totalCents(double dollars) { return Money.cents(dollars); }
}
