package com.acme.ledger;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** A list of postings in one currency, with the arithmetic that the report needs. */
public final class Ledger {

    private final String currency;
    private final List<LedgerEntry> entries;

    public Ledger(String currency, List<LedgerEntry> entries) {
        this.currency = currency;
        this.entries = List.copyOf(entries);
    }

    /** The fixed set of postings that the service reports on at start up. */
    public static Ledger sample() {
        List<LedgerEntry> entries = new ArrayList<>();
        entries.add(new LedgerEntry("2026-01-04", "Opening balance", 1_250_00L));
        entries.add(new LedgerEntry("2026-01-11", "Invoice 5512", 340_75L));
        entries.add(new LedgerEntry("2026-01-19", "Office rent", -820_00L));
        entries.add(new LedgerEntry("2026-02-02", "Invoice 5513", 1_980_40L));
        entries.add(new LedgerEntry("2026-02-14", "Card refund", -47_15L));
        return new Ledger("USD", entries);
    }

    public String currency() {
        return currency;
    }

    public List<LedgerEntry> entries() {
        return Collections.unmodifiableList(entries);
    }

    public int size() {
        return entries.size();
    }

    /** The sum of every posting, in minor units. */
    public long totalMinor() {
        long total = 0L;
        for (LedgerEntry entry : entries) {
            total += entry.amountMinor();
        }
        return total;
    }
}
