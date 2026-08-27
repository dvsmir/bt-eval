package telemetry.report;

import java.util.ArrayList;
import java.util.List;
import telemetry.api.Measurement;

/**
 * Turns a batch of measurements into one line of the operator report.
 */
public final class Rollup {

    private Rollup() {
    }

    public static Window summarise(String name, List<Measurement> measurements) {
        if (measurements.isEmpty()) {
            return new Window(name, 0.0, 0.0, 0.0);
        }
        List<Double> values = new ArrayList<>();
        double total = 0.0;
        for (Measurement measurement : measurements) {
            values.add(measurement.value());
            total += measurement.value();
        }
        values.sort(Double::compare);
        return new Window(name, values.getFirst(), values.getLast(), total / values.size());
    }

    public static String render(Window window) {
        return window.name()
                + " low=" + window.low()
                + " high=" + window.high()
                + " mean=" + window.mean();
    }
}
