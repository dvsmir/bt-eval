package telemetry.pipeline;

import java.util.List;
import telemetry.api.Measurement;

/**
 * Simple statistics over a batch of measurements.
 */
public final class Aggregates {

    private Aggregates() {
    }

    public static double mean(List<Measurement> measurements) {
        if (measurements.isEmpty()) {
            return 0.0;
        }
        double total = 0.0;
        for (Measurement measurement : measurements) {
            total += measurement.value();
        }
        return total / measurements.size();
    }
}
