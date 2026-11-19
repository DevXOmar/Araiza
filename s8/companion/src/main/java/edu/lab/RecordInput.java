package edu.lab;

final class RecordInput {
    private RecordInput() {}

    static boolean isValid(String reference, String bloodGroup) {
        return reference != null && reference.matches("[A-Za-z0-9][A-Za-z0-9 _-]{0,59}")
            && bloodGroup != null && bloodGroup.matches("(A|B|AB|O)[+-]");
    }
}
