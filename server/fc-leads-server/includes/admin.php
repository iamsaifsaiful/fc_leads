<?php
if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_menu', 'fcl_admin_menu');
add_action('admin_post_fcl_save_settings', 'fcl_handle_settings');
add_action('admin_post_fcl_add_member', 'fcl_handle_add_member');
add_action('admin_post_fcl_toggle_member', 'fcl_handle_toggle_member');

function fcl_admin_menu()
{
    add_menu_page('FC Leads', 'FC Leads', 'fcl_manage', 'fcl-report', 'fcl_page_report', 'dashicons-chart-bar', 58);
    add_submenu_page('fcl-report', 'Team report', 'Report', 'fcl_manage', 'fcl-report', 'fcl_page_report');
    add_submenu_page('fcl-report', 'Team', 'Team', 'fcl_manage', 'fcl-team', 'fcl_page_team');
    add_submenu_page('fcl-report', 'FC Leads settings', 'Settings', 'manage_options', 'fcl-settings', 'fcl_page_settings');
}

function fcl_admin_style()
{
    echo '<style>
    .fcl-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:16px 0}
    .fcl-card{background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:14px 16px}
    .fcl-card b{display:block;font-size:26px;line-height:1.2;color:#0F1B2D}
    .fcl-card span{color:#50575e}
    .fcl-card em{display:block;font-style:normal;font-size:12px;color:#1d6b3a;margin-top:4px}
    .fcl-tabs a{margin-right:6px}
    .fcl-notice{padding:10px 14px;border-radius:8px;background:#fff8e5;border:1px solid #f0c36d;margin:12px 0}
    .fcl-bars{display:flex;align-items:flex-end;gap:6px;height:140px;background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:14px}
    .fcl-bars div{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;font-size:11px;color:#50575e}
    .fcl-bars i{display:block;width:70%;max-width:28px;background:#0F1B2D;border-radius:4px 4px 2px 2px;margin:3px 0}
    </style>';
}

function fcl_change($now, $before)
{
    $d = $now - $before;
    if ($d === 0) {
        return 'same as before';
    }
    return ($d > 0 ? '+' : '') . $d . ' vs previous';
}

function fcl_page_report()
{
    if (!current_user_can('fcl_manage')) {
        return;
    }
    $period = isset($_GET['period']) ? sanitize_key($_GET['period']) : 'week';
    $member = isset($_GET['member']) ? (int) $_GET['member'] : 0;
    fcl_admin_style();
    $base = admin_url('admin.php?page=fcl-report');

    echo '<div class="wrap"><h1>FC Leads: team report</h1>';
    if (fcl_places_key() === '') {
        echo '<div class="fcl-notice">Search in the app will not work until you add the Google Places API key in <a href="' . esc_url(admin_url('admin.php?page=fcl-settings')) . '">Settings</a>.</div>';
    }
    echo '<p class="fcl-tabs">';
    foreach (['day' => 'Today', 'week' => 'This week', 'month' => 'This month'] as $p => $label) {
        $url = add_query_arg(array_filter(['period' => $p, 'member' => $member ?: null]), $base);
        echo '<a class="button' . ($p === $period ? ' button-primary' : '') . '" href="' . esc_url($url) . '">' . esc_html($label) . '</a>';
    }
    echo '</p>';

    if ($member) {
        $r = fcl_worker_report($member, $period, null);
        if (is_wp_error($r)) {
            echo '<p>' . esc_html($r->get_error_message()) . '</p></div>';
            return;
        }
        $m = $r['member'];
        echo '<h2>' . esc_html($m['name']) . ' <small>(' . esc_html($m['email']) . ')</small></h2>';
        echo '<p><a href="' . esc_url(add_query_arg('period', $period, $base)) . '">&larr; Whole team</a></p>';
        fcl_cards($m, null);
        fcl_bars_html($r['bars']);
        echo '<h3>Recent activity</h3><table class="widefat striped"><thead><tr><th>When</th><th>What</th><th>Business</th><th>Details</th></tr></thead><tbody>';
        foreach ($r['recent'] as $a) {
            echo '<tr><td>' . esc_html(wp_date('j M, g:i a', strtotime($a['at']))) . '</td><td>' . esc_html(fcl_event_label($a['type'], $a['meta'])) . '</td><td>' . esc_html($a['name']) . '</td><td>' . esc_html($a['type'] === 'status' ? '' : $a['meta']) . '</td></tr>';
        }
        if (!$r['recent']) {
            echo '<tr><td colspan="4">No activity yet.</td></tr>';
        }
        echo '</tbody></table></div>';
        return;
    }

    $r = fcl_report($period, null);
    fcl_cards($r['totals'], $r['previous']);
    fcl_bars_html($r['bars']);
    echo '<h2>Team</h2><table class="widefat striped"><thead><tr><th>Name</th><th>Leads checked</th><th>Messaged</th><th>Replies</th><th>Won</th><th>Searches</th><th>Last active</th></tr></thead><tbody>';
    foreach ($r['team'] as $m) {
        $url = add_query_arg(['period' => $period, 'member' => $m['id']], $base);
        echo '<tr><td><a href="' . esc_url($url) . '"><strong>' . esc_html($m['name']) . '</strong></a>' . ($m['disabled'] ? ' <em>(off)</em>' : '') . '</td>';
        foreach (['leads', 'sent', 'replies', 'won', 'searches'] as $k) {
            echo '<td>' . (int) $m[$k] . '</td>';
        }
        echo '<td>' . esc_html($m['lastActive'] ? human_time_diff(strtotime($m['lastActive'])) . ' ago' : 'never') . '</td></tr>';
    }
    if (!$r['team']) {
        echo '<tr><td colspan="7">No team members yet. Add them under FC Leads &rsaquo; Team.</td></tr>';
    }
    echo '</tbody></table></div>';
}

function fcl_event_label($type, $meta)
{
    switch ($type) {
        case 'search':
            return 'Searched';
        case 'audit':
            return 'Checked a business';
        case 'whatsapp':
            return 'Sent on WhatsApp';
        case 'email':
            return 'Sent an email';
        case 'status':
            return 'Status: ' . $meta;
        case 'followup':
            return 'Set a follow-up';
        case 'client':
            return 'Made a client';
    }
    return $type;
}

function fcl_cards($now, $before)
{
    $items = ['leads' => 'Leads checked', 'sent' => 'Messaged', 'replies' => 'Replies', 'won' => 'Won', 'searches' => 'Searches'];
    echo '<div class="fcl-cards">';
    foreach ($items as $k => $label) {
        echo '<div class="fcl-card"><b>' . (int) $now[$k] . '</b><span>' . esc_html($label) . '</span>';
        if ($before !== null) {
            echo '<em>' . esc_html(fcl_change((int) $now[$k], (int) $before[$k])) . '</em>';
        }
        echo '</div>';
    }
    echo '</div>';
}

function fcl_bars_html($bars)
{
    $max = 1;
    foreach ($bars as $b) {
        $max = max($max, $b['sent'], $b['leads']);
    }
    echo '<p><strong>Leads checked</strong> per period</p><div class="fcl-bars">';
    foreach ($bars as $b) {
        $h = (int) round($b['leads'] / $max * 100);
        echo '<div><span>' . (int) $b['leads'] . '</span><i style="height:' . $h . 'px"></i>' . esc_html($b['label']) . '</div>';
    }
    echo '</div>';
}

function fcl_page_team()
{
    if (!current_user_can('fcl_manage')) {
        return;
    }
    fcl_admin_style();
    $msg = isset($_GET['fcl_msg']) ? sanitize_text_field(wp_unslash($_GET['fcl_msg'])) : '';
    echo '<div class="wrap"><h1>FC Leads team</h1>';
    if ($msg !== '') {
        echo '<div class="notice notice-info"><p>' . esc_html($msg) . '</p></div>';
    }
    echo '<p>Team members sign in to the app with <strong>Team</strong> and their email and password. Admins and FC Leads managers can also sign in with <strong>Admin</strong> to see reports.</p>';

    echo '<h2>Add a team member</h2><form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
    wp_nonce_field('fcl_add_member');
    echo '<input type="hidden" name="action" value="fcl_add_member"><table class="form-table">
        <tr><th><label for="fcl_name">Name</label></th><td><input id="fcl_name" name="name" class="regular-text" required></td></tr>
        <tr><th><label for="fcl_email">Email</label></th><td><input id="fcl_email" name="email" type="email" class="regular-text" required></td></tr>
        <tr><th><label for="fcl_pass">Password</label></th><td><input id="fcl_pass" name="password" type="text" class="regular-text" minlength="8" required value="' . esc_attr(wp_generate_password(12, false)) . '"><p class="description">Give this to the team member. They can change it from their WordPress profile.</p></td></tr>
        </table>';
    submit_button('Add team member');
    echo '</form>';

    echo '<h2>Team</h2><table class="widefat striped"><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Last active</th><th></th></tr></thead><tbody>';
    foreach (fcl_team_users() as $u) {
        $row = fcl_member_row($u, []);
        echo '<tr><td><strong>' . esc_html($row['name']) . '</strong>' . ($row['disabled'] ? ' <em>(turned off)</em>' : '') . '</td><td>' . esc_html($row['email']) . '</td><td>' . esc_html($row['role'] === 'team' ? 'Team' : 'Manager') . '</td><td>' . esc_html($row['lastActive'] ? human_time_diff(strtotime($row['lastActive'])) . ' ago' : 'never') . '</td><td>';
        if ($u->ID !== get_current_user_id()) {
            echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '" style="display:inline">';
            wp_nonce_field('fcl_toggle_' . $u->ID);
            echo '<input type="hidden" name="action" value="fcl_toggle_member"><input type="hidden" name="user" value="' . (int) $u->ID . '">';
            echo '<button class="button">' . ($row['disabled'] ? 'Turn on' : 'Turn off') . '</button></form> ';
        }
        echo '<a class="button" href="' . esc_url(get_edit_user_link($u->ID)) . '">Edit / password</a></td></tr>';
    }
    echo '</tbody></table></div>';
}

function fcl_handle_add_member()
{
    if (!current_user_can('fcl_manage')) {
        wp_die('Not allowed');
    }
    check_admin_referer('fcl_add_member');
    $id = fcl_add_member(
        wp_unslash($_POST['name'] ?? ''),
        wp_unslash($_POST['email'] ?? ''),
        (string) wp_unslash($_POST['password'] ?? '')
    );
    $msg = is_wp_error($id) ? $id->get_error_message() : 'Team member added. They can now sign in to the app.';
    wp_safe_redirect(add_query_arg('fcl_msg', rawurlencode($msg), admin_url('admin.php?page=fcl-team')));
    exit;
}

function fcl_handle_toggle_member()
{
    if (!current_user_can('fcl_manage')) {
        wp_die('Not allowed');
    }
    $id = (int) ($_POST['user'] ?? 0);
    check_admin_referer('fcl_toggle_' . $id);
    if ($id && $id !== get_current_user_id()) {
        if (fcl_is_disabled($id)) {
            delete_user_meta($id, 'fcl_disabled');
            $msg = 'Account turned on.';
        } else {
            update_user_meta($id, 'fcl_disabled', 1);
            fcl_end_sessions($id);
            $msg = 'Account turned off and signed out of the app.';
        }
    } else {
        $msg = 'Nothing changed.';
    }
    wp_safe_redirect(add_query_arg('fcl_msg', rawurlencode($msg), admin_url('admin.php?page=fcl-team')));
    exit;
}

function fcl_page_settings()
{
    if (!current_user_can('manage_options')) {
        return;
    }
    $s = fcl_settings();
    $saved = isset($_GET['saved']);
    $fromConfig = defined('FCL_PLACES_KEY') && FCL_PLACES_KEY;
    echo '<div class="wrap"><h1>FC Leads settings</h1>';
    if ($saved) {
        echo '<div class="notice notice-success"><p>Settings saved.</p></div>';
    }
    echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
    wp_nonce_field('fcl_save_settings');
    echo '<input type="hidden" name="action" value="fcl_save_settings"><table class="form-table">';
    echo '<tr><th><label for="places_key">Google Places API key</label></th><td>';
    if ($fromConfig) {
        echo '<p>Set in wp-config.php (FCL_PLACES_KEY).</p>';
    } else {
        echo '<input id="places_key" name="places_key" type="password" class="regular-text" autocomplete="off" placeholder="' . esc_attr($s['places_key'] !== '' ? 'Saved. Type a new key to replace it.' : 'AIza…') . '">';
    }
    echo '<p class="description">Google Cloud &rsaquo; enable "Places API (New)" &rsaquo; Credentials &rsaquo; API key. Restrict it to Places API (New). It stays on this website and is never sent to phones.</p></td></tr>';
    $fields = [
        'daily_target' => ['Daily target (leads checked per person)', 'number'],
        'search_limit' => ['Searches per person per day (0 = no limit)', 'number'],
        'agency_name' => ['Agency name (on graphics and messages)', 'text'],
        'agency_website' => ['Agency website', 'text'],
        'agency_whatsapp' => ['Agency WhatsApp number', 'text'],
        'agency_email' => ['Agency email', 'email'],
    ];
    foreach ($fields as $k => [$label, $type]) {
        echo '<tr><th><label for="' . esc_attr($k) . '">' . esc_html($label) . '</label></th><td><input id="' . esc_attr($k) . '" name="' . esc_attr($k) . '" type="' . esc_attr($type) . '" class="regular-text" value="' . esc_attr($s[$k]) . '"></td></tr>';
    }
    echo '</table>';
    submit_button('Save settings');
    echo '</form></div>';
}

function fcl_handle_settings()
{
    if (!current_user_can('manage_options')) {
        wp_die('Not allowed');
    }
    check_admin_referer('fcl_save_settings');
    $s = fcl_settings();
    $key = isset($_POST['places_key']) ? trim(sanitize_text_field(wp_unslash($_POST['places_key']))) : '';
    if ($key !== '') {
        $s['places_key'] = $key;
    }
    $s['daily_target'] = max(1, (int) ($_POST['daily_target'] ?? 20));
    $s['search_limit'] = max(0, (int) ($_POST['search_limit'] ?? 300));
    foreach (['agency_name', 'agency_website', 'agency_whatsapp'] as $k) {
        $s[$k] = sanitize_text_field(wp_unslash($_POST[$k] ?? ''));
    }
    $s['agency_email'] = sanitize_email(wp_unslash($_POST['agency_email'] ?? ''));
    update_option('fcl_settings', $s, false);
    wp_safe_redirect(admin_url('admin.php?page=fcl-settings&saved=1'));
    exit;
}
