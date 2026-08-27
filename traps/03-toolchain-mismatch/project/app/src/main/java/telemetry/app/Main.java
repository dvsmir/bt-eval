package telemetry.app;

import java.util.List;
import telemetry.api.Measurement;
import telemetry.pipeline.Aggregates;
import telemetry.pipeline.BufferingSink;

/**
 * Collects a small batch and prints the mean.
 */
public final class Main {

    private Main() {
    }

    public static void main(String[] args) {
        BufferingSink sink = new BufferingSink();
        sink.accept(new Measurement("cpu", 0.4, 1000L));
        sink.accept(new Measurement("cpu", 0.8, 2000L));
        sink.accept(new Measurement("cpu", 0.6, 3000L));

        List<Measurement> batch = sink.drain();
        double mean = Aggregates.mean(batch);
        if (Math.abs(mean - 0.6) > 1.0e-9) {
            throw new IllegalStateException("unexpected mean: " + mean);
        }
        System.out.println("collected " + batch.size() + " measurements, mean=" + mean);
    }
}
