package edu.lab;

import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class RecordInputTest {
    @Test public void acceptsSyntheticRecord() {
        assertTrue(RecordInput.isValid("Sample-01", "O+"));
    }

    @Test public void rejectsInvalidFieldAndReference() {
        assertFalse(RecordInput.isValid("Sample-01", "invalid"));
        assertFalse(RecordInput.isValid("", "O+"));
        assertFalse(RecordInput.isValid(null, "O+"));
    }
}
