package com.example.ingest;

/** Command line entry point of the ingest service. */
public final class IngestApp {

    public static void main(String[] args) {
        if (args.length > 0 && args[0].equals("--help")) {
            System.out.println("usage: ingest [--help]");
            return;
        }
        System.out.println("ingest service " + BuildInfo.batchSize() + " rows per batch");
    }
}
