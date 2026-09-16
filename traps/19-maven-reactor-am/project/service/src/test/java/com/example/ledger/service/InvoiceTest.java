package com.example.ledger.service;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
class InvoiceTest {
    @Test void totalsDollarsToCents() {
        assertEquals(4999L, new Invoice().totalCents(49.99));
    }
}
