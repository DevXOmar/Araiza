package edu.lab;

import org.junit.Test;
import static org.junit.Assert.assertFalse;

public class ControlledFailureTest {
    @Test public void failsOnlyWhenRequested() {
        assertFalse("Intentional lab CI failure", Boolean.getBoolean("lab.forceFailure"));
    }
}
