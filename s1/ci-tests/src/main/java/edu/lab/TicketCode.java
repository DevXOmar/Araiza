package edu.lab;

import java.util.Locale;
import java.util.UUID;

final class TicketCode {
    private TicketCode() {}

    static String issue(String seat) {
        String normalized = seat == null ? "" : seat.trim().toUpperCase(Locale.ROOT);
        if (!normalized.matches("[A-Z]([1-9]|[1-9][0-9])")) {
            throw new IllegalArgumentException("Invalid seat");
        }
        return normalized + "-" + UUID.randomUUID();
    }
}
