package com.acme.fleet.report;

import com.acme.fleet.core.Alert;
import com.acme.json.JsonLine;

import java.util.ArrayList;
import java.util.List;

/** Renders the alerts of one day as JSON lines. */
public final class DailyReport {

    private final String day;

    public DailyReport(String day) {
        this.day = day;
    }

    public List<String> render(List<Alert> alerts) {
        List<String> lines = new ArrayList<>(alerts.size() + 1);
        lines.add(new JsonLine()
                .add("kind", "summary")
                .add("day", day)
                .add("alerts", alerts.size())
                .render());
        for (Alert alert : alerts) {
            lines.add(new JsonLine()
                    .add("kind", "alert")
                    .add("severity", alert.severity().name())
                    .add("source", alert.source())
                    .add("message", alert.message())
                    .render());
        }
        return lines;
    }
}
