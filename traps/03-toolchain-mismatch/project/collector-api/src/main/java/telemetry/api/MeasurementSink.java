package telemetry.api;

/**
 * Destination for the values that a collector produces.
 */
public interface MeasurementSink {

    void accept(Measurement measurement);
}
