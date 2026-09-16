package com.example.toolkit;

/** Small CLI that prints the release coordinates. */
public final class Main {
    private Main() {
    }

    public static void main(String[] args) {
        System.out.println("release-toolkit " + describe());
    }

    static String describe() {
        return "ready";
    }
}
