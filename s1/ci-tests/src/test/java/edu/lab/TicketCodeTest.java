package edu.lab;

import java.util.UUID;
import org.junit.Test;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;

public class TicketCodeTest {
    @Test public void normalizesSeatAndIssuesUniqueCode() {
        String first = TicketCode.issue(" a7 ");
        assertEquals("A7-", first.substring(0, 3));
        UUID.fromString(first.substring(3));
        assertNotEquals(first, TicketCode.issue("A7"));
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsInvalidSeat() {
        TicketCode.issue("A0");
    }
}
