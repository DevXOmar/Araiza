package edu.lab;

final class RecordInput {
    private RecordInput() {}

    static boolean isValid(String reference, String unit) {
        return reference != null && reference.matches("[A-Za-z0-9][A-Za-z0-9 _-]{0,59}")
            && unit != null && unit.matches("[A-Z]-[1-9][0-9]{0,2}");
    }
}
