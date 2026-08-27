package com.acme.fleet.ingest;

import com.acme.fleet.core.Alert;
import com.acme.fleet.core.Severity;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Reads the raw alert lines that the collectors write. */
public final class AlertParser {

    private static final String DELIMITER = "[|]";
    private static final int FIELDS = 3;

    public Alert parse(String line) {
        if (line == null || line.isBlank()) {
            throw new IllegalArgumentException("empty alert line");
        }
        String[] parts = line.split(DELIMITER, FIELDS);
        if (parts.length != FIELDS) {
            throw new IllegalArgumentException("expected three fields in: " + line);
        }
        Severity severity = Severity.valueOf(parts[0].trim().toUpperCase(Locale.ROOT));
        return new Alert(severity, parts[1].trim(), parts[2].trim());
    }

    public List<Alert> parseAll(List<String> lines) {
        List<Alert> alerts = new ArrayList<>(lines.size());
        for (String line : lines) {
            alerts.add(parse(line));
        }
        return alerts;
    }
}
