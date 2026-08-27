package com.acme.platform.money;

import java.util.Objects;

/** An immutable amount of money, held in the minor unit of its currency. */
public final class Money {

    private final long minorUnits;
    private final String currency;

    private Money(long minorUnits, String currency) {
        this.minorUnits = minorUnits;
        this.currency = Objects.requireNonNull(currency, "currency");
    }

    /** Builds an amount from a count of minor units, for example cents. */
    public static Money ofMinor(long minorUnits, String currency) {
        return new Money(minorUnits, currency);
    }

    /** Builds a zero amount in the given currency. */
    public static Money zero(String currency) {
        return new Money(0L, currency);
    }

    public Money plus(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException(
                    "Cannot add " + other.currency + " to " + currency);
        }
        return new Money(minorUnits + other.minorUnits, currency);
    }

    public long minorUnits() {
        return minorUnits;
    }

    public String currency() {
        return currency;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof Money)) {
            return false;
        }
        Money that = (Money) other;
        return minorUnits == that.minorUnits && currency.equals(that.currency);
    }

    @Override
    public int hashCode() {
        return Objects.hash(minorUnits, currency);
    }

    @Override
    public String toString() {
        return currency + "/" + minorUnits;
    }
}
