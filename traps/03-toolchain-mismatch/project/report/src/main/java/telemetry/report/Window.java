package telemetry.report;

/**
 * The summary of one batch of measurements.
 */
public record Window(String name, double low, double high, double mean) {
}
