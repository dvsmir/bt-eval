package com.example.report;

/** Command line entry point of the report service. */
public final class ReportApp {

    public static void main(String[] args) {
        if (args.length > 0 && args[0].equals("--help")) {
            System.out.println("usage: report [--help]");
            return;
        }
        System.out.println("report service " + BuildInfo.chunkRows() + " rows per chunk");
    }
}
