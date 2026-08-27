package com.acme.ledger;

import java.util.Objects;

/** One posting in the ledger. The amount is in minor units and can be negative. */
public final class LedgerEntry {

    private final String date;
    private final String description;
    private final long amountMinor;

    public LedgerEntry(String date, String description, long amountMinor) {
        this.date = Objects.requireNonNull(date, "date");
        this.description = Objects.requireNonNull(description, "description");
        this.amountMinor = amountMinor;
    }

    public String date() {
        return date;
    }

    public String description() {
        return description;
    }

    public long amountMinor() {
        return amountMinor;
    }
}
