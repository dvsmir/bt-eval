package com.acme.platform.money;

/**
 * Writes an amount of money as text.
 *
 * <p>The output has two decimal digits, a thin space between the groups of three digits,
 * and the currency code in front. The result does not change with the locale.
 */
public final class MoneyFormatter {

    private static final int DEFAULT_WIDTH = 18;

    private final int width;

    public MoneyFormatter() {
        this(DEFAULT_WIDTH);
    }

    public MoneyFormatter(int width) {
        this.width = width;
    }

    /** Returns the amount as right aligned text, for example {@code USD 12,345.60}. */
    public String format(Money money) {
        long minor = money.minorUnits();
        String sign = minor < 0 ? "-" : "";
        long absolute = Math.abs(minor);
        String fraction = String.format("%02d", absolute % 100L);
        String text = money.currency() + " " + sign + group(absolute / 100L) + "." + fraction;
        return pad(text);
    }

    private static String group(long major) {
        String digits = Long.toString(major);
        StringBuilder out = new StringBuilder();
        int lead = digits.length() % 3 == 0 ? 3 : digits.length() % 3;
        out.append(digits, 0, lead);
        for (int at = lead; at < digits.length(); at += 3) {
            out.append(',').append(digits, at, at + 3);
        }
        return out.toString();
    }

    private String pad(String text) {
        if (text.length() >= width) {
            return text;
        }
        StringBuilder out = new StringBuilder();
        for (int i = text.length(); i < width; i++) {
            out.append(' ');
        }
        return out.append(text).toString();
    }
}
