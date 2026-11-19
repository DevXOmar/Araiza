<?php
/**
 * Plugin Name: E-Ticketing Lab
 * Description: Demonstrates a durable, unique seat reservation for signed-in WordPress users.
 */

add_shortcode('lab_ticket_booking', function () {
    if (!is_user_logged_in()) {
        return '<p>Sign in to reserve a test seat.</p>';
    }

    global $wpdb;
    $table = $wpdb->prefix . 'lab_ticket_bookings';
    $charset = $wpdb->get_charset_collate();
    if (false === $wpdb->query("CREATE TABLE IF NOT EXISTS `$table` (
        event_code VARCHAR(20) NOT NULL,
        seat VARCHAR(4) NOT NULL,
        booking_code CHAR(36) NOT NULL,
        user_id BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (event_code, seat)
    ) ENGINE=InnoDB $charset")) {
        return '<p>Booking database unavailable.</p>';
    }

    $message = '';
    if (isset($_POST['lab_book_seat']) && is_string($_POST['lab_book_seat'])) {
        $nonce = isset($_POST['lab_ticket_nonce']) && is_string($_POST['lab_ticket_nonce'])
            ? sanitize_text_field(wp_unslash($_POST['lab_ticket_nonce'])) : '';
        $seat = strtoupper(trim(wp_unslash($_POST['lab_book_seat'])));
        if (!wp_verify_nonce($nonce, 'lab_ticket_booking')) {
            $message = 'Refresh the page and try again.';
        } elseif (!preg_match('/\A[A-Z](?:[1-9]|[1-9][0-9])\z/', $seat)) {
            $message = 'Enter a seat such as A7.';
        } else {
            $booking = wp_generate_uuid4();
            $result = $wpdb->query($wpdb->prepare(
                "INSERT INTO `$table` (event_code, seat, booking_code, user_id)
                 VALUES (%s, %s, %s, %d) ON DUPLICATE KEY UPDATE seat = seat",
                'LAB-CONCERT', $seat, $booking, get_current_user_id()
            ));
            $message = $result === 1 ? "Reserved $seat ($booking)."
                : ($result === 0 ? 'Seat already reserved.' : 'Booking database unavailable.');
        }
    }

    $seats = $wpdb->get_col($wpdb->prepare(
        "SELECT seat FROM `$table` WHERE event_code = %s AND user_id = %d ORDER BY seat",
        'LAB-CONCERT', get_current_user_id()
    ));
    $nonce_field = wp_nonce_field('lab_ticket_booking', 'lab_ticket_nonce', true, false);
    return '<p>' . esc_html($message) . '</p>'
        . '<form method="post">' . $nonce_field
        . '<label>Concert seat <input name="lab_book_seat" maxlength="3" required></label>'
        . '<button>Reserve</button></form>'
        . '<p>Saved seats: ' . esc_html(implode(', ', $seats)) . '</p>';
});
