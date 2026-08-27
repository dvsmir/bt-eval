package telemetry.pipeline;

import java.util.ArrayList;
import java.util.List;
import telemetry.api.Measurement;
import telemetry.api.MeasurementSink;

/**
 * Keeps measurements in memory until something drains them.
 */
public final class BufferingSink implements MeasurementSink {

    private final List<Measurement> buffer = new ArrayList<>();

    @Override
    public void accept(Measurement measurement) {
        buffer.add(measurement);
    }

    public List<Measurement> drain() {
        List<Measurement> copy = List.copyOf(buffer);
        buffer.clear();
        return copy;
    }

    public int size() {
        return buffer.size();
    }
}
