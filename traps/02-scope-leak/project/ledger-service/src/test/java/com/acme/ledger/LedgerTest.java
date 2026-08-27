package com.acme.ledger;

import static org.junit.Assert.assertEquals;

import java.util.List;

import org.junit.Test;

public class LedgerTest {

    @Test
    public void sampleLedgerHasFiveEntries() {
        assertEquals(5, Ledger.sample().size());
    }

    @Test
    public void totalIsTheSumOfEveryEntry() {
        assertEquals(2_704_00L, Ledger.sample().totalMinor());
    }

    @Test
    public void totalOfAnEmptyLedgerIsZero() {
        assertEquals(0L, new Ledger("USD", List.of()).totalMinor());
    }

    @Test
    public void negativeEntriesReduceTheTotal() {
        Ledger ledger = new Ledger("USD", List.of(
                new LedgerEntry("2026-03-01", "Fee", -500L),
                new LedgerEntry("2026-03-02", "Sale", 1_500L)));
        assertEquals(1_000L, ledger.totalMinor());
    }
}
