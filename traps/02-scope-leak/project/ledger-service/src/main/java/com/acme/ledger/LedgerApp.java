package com.acme.ledger;

import com.acme.platform.money.Money;
import com.acme.platform.money.MoneyFormatter;

/** Prints the statement of the sample ledger. */
public final class LedgerApp {

    private LedgerApp() {
    }

    public static void main(String[] args) {
        Ledger ledger = Ledger.sample();
        MoneyFormatter formatter = new MoneyFormatter();

        System.out.println("Ledger statement (" + ledger.currency() + ")");
        System.out.println("--------------------------------------------------");
        for (LedgerEntry entry : ledger.entries()) {
            Money amount = Money.ofMinor(entry.amountMinor(), ledger.currency());
            System.out.println(
                    entry.date() + "  " + pad(entry.description()) + formatter.format(amount));
        }
        System.out.println("--------------------------------------------------");
        Money total = Money.ofMinor(ledger.totalMinor(), ledger.currency());
        System.out.println("            " + pad("Total") + formatter.format(total));
    }

    private static String pad(String text) {
        StringBuilder out = new StringBuilder(text);
        while (out.length() < 20) {
            out.append(' ');
        }
        return out.toString();
    }
}
