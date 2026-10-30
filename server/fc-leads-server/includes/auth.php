<?php
if (!defined('ABSPATH')) {
    exit;
}

const FCL_SESSION_DAYS = 30;
const FCL_MAX_FAILS = 5;
const FCL_LOCK_MINUTES = 15;

function fcl_error($code, $message, $status)
{
    return new WP_Error($code, $message, ['status' => $status]);
}

function fcl_client_ip()
{
    return isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : '';
}

function fcl_fail_key($login)
{
    return 'fcl_fail_' . md5(strtolower($login) . '|' . fcl_client_ip());
}

function fcl_is_disabled($user_id)
{
    return (bool) get_user_meta($user_id, 'fcl_disabled', true);
}

/** What the app shows for a signed-in user. */
function fcl_user_payload($user, $role)
{
    $name = trim($user->display_name) !== '' ? $user->display_name : $user->user_login;
    return [
        'id' => (int) $user->ID,
        'name' => $name,
        'email' => $user->user_email,
        'role' => $role,
        'canManage' => user_can($user, 'fcl_manage'),
    ];
}

/**
 * POST /auth/login {login, password, role: team|admin, device}
 * Team: any user with fcl_work (team, managers, site admins).
 * Admin: users with fcl_manage only.
 */
function fcl_api_login(WP_REST_Request $req)
{
    $login = trim((string) $req->get_param('login'));
    $password = (string) $req->get_param('password');
    $role = $req->get_param('role') === 'admin' ? 'admin' : 'team';
    $device = substr(sanitize_text_field((string) $req->get_param('device')), 0, 190);

    if ($login === '' || $password === '') {
        return fcl_error('fcl_missing', 'Enter your email or username and password.', 400);
    }

    $fails = (int) get_transient(fcl_fail_key($login));
    if ($fails >= FCL_MAX_FAILS) {
        return fcl_error('fcl_locked', 'Too many wrong tries. Try again in 15 minutes.', 429);
    }

    $user = wp_authenticate($login, $password);
    if (is_wp_error($user)) {
        set_transient(fcl_fail_key($login), $fails + 1, FCL_LOCK_MINUTES * MINUTE_IN_SECONDS);
        return fcl_error('fcl_bad_login', 'Wrong email, username or password.', 401);
    }
    delete_transient(fcl_fail_key($login));

    if (fcl_is_disabled($user->ID)) {
        return fcl_error('fcl_disabled', 'This account has been turned off. Ask your admin.', 403);
    }
    if ($role === 'admin' && !user_can($user, 'fcl_manage')) {
        return fcl_error('fcl_not_admin', 'This account is not an admin. Use the Team login.', 403);
    }
    if ($role === 'team' && !user_can($user, 'fcl_work')) {
        return fcl_error('fcl_not_team', 'This account is not part of the FC Leads team.', 403);
    }

    global $wpdb;
    $token = bin2hex(random_bytes(32));
    $now = fcl_now();
    $wpdb->insert(fcl_table('sessions'), [
        'user_id' => $user->ID,
        'token_hash' => hash('sha256', $token),
        'role' => $role,
        'device' => $device,
        'created_at' => $now,
        'last_seen' => $now,
        'expires_at' => gmdate('Y-m-d H:i:s', time() + FCL_SESSION_DAYS * DAY_IN_SECONDS),
    ]);
    update_user_meta($user->ID, 'fcl_last_active', $now);

    return [
        'token' => $token,
        'user' => fcl_user_payload($user, $role),
        'config' => fcl_app_config(),
    ];
}

/** Settings the app needs (never the Google key). */
function fcl_app_config()
{
    $s = fcl_settings();
    return [
        'dailyTarget' => (int) $s['daily_target'],
        'agencyName' => (string) $s['agency_name'],
        'agencyWebsite' => (string) $s['agency_website'],
        'agencyWhatsapp' => (string) $s['agency_whatsapp'],
        'agencyEmail' => (string) $s['agency_email'],
        'searchReady' => fcl_places_key() !== '',
        'serverVersion' => FCL_VERSION,
    ];
}

/** Reads the token from "Authorization: Bearer …" or "X-FCL-Token" (some hosts drop Authorization). */
function fcl_request_token(WP_REST_Request $req)
{
    $h = (string) $req->get_header('x_fcl_token');
    if ($h !== '') {
        return $h;
    }
    $auth = (string) $req->get_header('authorization');
    if (stripos($auth, 'bearer ') === 0) {
        return trim(substr($auth, 7));
    }
    return '';
}

/**
 * Finds the session for a request. Returns ['user' => WP_User, 'role' => …,
 * 'session_id' => …] or a WP_Error.
 */
function fcl_session(WP_REST_Request $req)
{
    static $cache = [];
    $token = fcl_request_token($req);
    if ($token === '' || !ctype_xdigit($token) || strlen($token) !== 64) {
        return fcl_error('fcl_no_session', 'Please sign in.', 401);
    }
    if (isset($cache[$token])) {
        return $cache[$token];
    }
    global $wpdb;
    $row = $wpdb->get_row($wpdb->prepare(
        'SELECT * FROM ' . fcl_table('sessions') . ' WHERE token_hash = %s',
        hash('sha256', $token)
    ));
    if (!$row || strtotime($row->expires_at . ' UTC') < time()) {
        return $cache[$token] = fcl_error('fcl_expired', 'Your session has ended. Please sign in again.', 401);
    }
    $user = get_user_by('id', (int) $row->user_id);
    if (!$user || fcl_is_disabled($user->ID)) {
        $wpdb->delete(fcl_table('sessions'), ['id' => $row->id]);
        return $cache[$token] = fcl_error('fcl_disabled', 'This account has been turned off. Ask your admin.', 401);
    }
    if ($row->role === 'admin' && !user_can($user, 'fcl_manage')) {
        return $cache[$token] = fcl_error('fcl_not_admin', 'This account is no longer an admin.', 401);
    }
    if (!user_can($user, 'fcl_work')) {
        return $cache[$token] = fcl_error('fcl_not_team', 'This account is no longer part of the team.', 401);
    }
    // Mark activity at most every 5 minutes.
    if (strtotime($row->last_seen . ' UTC') < time() - 300) {
        $now = fcl_now();
        $wpdb->update(fcl_table('sessions'), ['last_seen' => $now], ['id' => $row->id]);
        update_user_meta($user->ID, 'fcl_last_active', $now);
    }
    return $cache[$token] = ['user' => $user, 'role' => $row->role, 'session_id' => (int) $row->id];
}

function fcl_can_work(WP_REST_Request $req)
{
    $s = fcl_session($req);
    return is_wp_error($s) ? $s : true;
}

function fcl_can_manage(WP_REST_Request $req)
{
    $s = fcl_session($req);
    if (is_wp_error($s)) {
        return $s;
    }
    if ($s['role'] !== 'admin') {
        return fcl_error('fcl_forbidden', 'Only admins can see this.', 403);
    }
    return true;
}

function fcl_api_logout(WP_REST_Request $req)
{
    $s = fcl_session($req);
    if (!is_wp_error($s)) {
        global $wpdb;
        $wpdb->delete(fcl_table('sessions'), ['id' => $s['session_id']]);
    }
    return ['ok' => true];
}

function fcl_api_me(WP_REST_Request $req)
{
    $s = fcl_session($req);
    return ['user' => fcl_user_payload($s['user'], $s['role']), 'config' => fcl_app_config()];
}

/** Signs a user out everywhere (used when an account is turned off). */
function fcl_end_sessions($user_id)
{
    global $wpdb;
    $wpdb->delete(fcl_table('sessions'), ['user_id' => (int) $user_id]);
}

function fcl_cleanup_sessions()
{
    global $wpdb;
    $wpdb->query($wpdb->prepare('DELETE FROM ' . fcl_table('sessions') . ' WHERE expires_at < %s', fcl_now()));
}
