<?php
if (!defined('ABSPATH')) {
    exit;
}

function fcl_register_routes()
{
    $work = 'fcl_can_work';
    $manage = 'fcl_can_manage';
    $place = '(?P<place>[A-Za-z0-9_\-]{1,191})';

    register_rest_route(FCL_NS, '/auth/login', ['methods' => 'POST', 'callback' => 'fcl_api_login', 'permission_callback' => '__return_true']);
    register_rest_route(FCL_NS, '/auth/logout', ['methods' => 'POST', 'callback' => 'fcl_api_logout', 'permission_callback' => '__return_true']);
    register_rest_route(FCL_NS, '/me', ['methods' => 'GET', 'callback' => 'fcl_api_me', 'permission_callback' => $work]);

    register_rest_route(FCL_NS, '/places/search', ['methods' => 'POST', 'callback' => 'fcl_api_places_search', 'permission_callback' => $work]);
    register_rest_route(FCL_NS, '/places/(?P<id>[A-Za-z0-9_\-]{1,300})', ['methods' => 'GET', 'callback' => 'fcl_api_place_details', 'permission_callback' => $work]);

    register_rest_route(FCL_NS, '/activity', ['methods' => 'POST', 'callback' => 'fcl_api_activity', 'permission_callback' => $work]);

    register_rest_route(FCL_NS, '/leads', ['methods' => 'GET', 'callback' => 'fcl_api_leads', 'permission_callback' => $work]);
    register_rest_route(FCL_NS, '/leads/' . $place, [
        ['methods' => 'PUT, POST', 'callback' => 'fcl_api_lead_save', 'permission_callback' => $work],
        ['methods' => 'DELETE', 'callback' => 'fcl_api_lead_delete', 'permission_callback' => $work],
    ]);

    register_rest_route(FCL_NS, '/admin/report', ['methods' => 'GET', 'callback' => 'fcl_api_report', 'permission_callback' => $manage]);
    register_rest_route(FCL_NS, '/admin/team', [
        ['methods' => 'GET', 'callback' => 'fcl_api_team', 'permission_callback' => $manage],
        ['methods' => 'POST', 'callback' => 'fcl_api_team_add', 'permission_callback' => $manage],
    ]);
    register_rest_route(FCL_NS, '/admin/team/(?P<id>\d+)', ['methods' => 'POST', 'callback' => 'fcl_api_team_update', 'permission_callback' => $manage]);
    register_rest_route(FCL_NS, '/admin/workers/(?P<id>\d+)', ['methods' => 'GET', 'callback' => 'fcl_api_worker', 'permission_callback' => $manage]);
}

/** Turns a time the phone sent into a UTC datetime, or now when it looks wrong. */
function fcl_event_time($at)
{
    $ts = is_string($at) && $at !== '' ? strtotime($at) : false;
    if ($ts === false || $ts > time() + 300 || $ts < time() - 30 * DAY_IN_SECONDS) {
        return fcl_now();
    }
    return gmdate('Y-m-d H:i:s', $ts);
}

/**
 * POST /activity {events: [{id, type, placeId, name, meta, at}]}
 * The phone keeps events while offline and sends them in batches; an
 * event id already stored is skipped, so retries never double count.
 */
function fcl_api_activity(WP_REST_Request $req)
{
    global $wpdb;
    $s = fcl_session($req);
    $uid = $s['user']->ID;
    $events = $req->get_param('events');
    if (!is_array($events)) {
        return fcl_error('fcl_missing', 'No events.', 400);
    }
    $saved = 0;
    $skipped = 0;
    foreach (array_slice($events, 0, 200) as $e) {
        if (!is_array($e)) {
            continue;
        }
        $type = isset($e['type']) ? (string) $e['type'] : '';
        if (!in_array($type, FCL_EVENT_TYPES, true)) {
            $skipped++;
            continue;
        }
        $cid = isset($e['id']) ? substr(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $e['id']), 0, 64) : '';
        if ($cid !== '') {
            $exists = $wpdb->get_var($wpdb->prepare(
                'SELECT id FROM ' . fcl_table('activity') . ' WHERE user_id = %d AND client_id = %s',
                $uid,
                $cid
            ));
            if ($exists) {
                $skipped++;
                continue;
            }
        }
        fcl_log(
            $uid,
            $type,
            isset($e['placeId']) ? sanitize_text_field((string) $e['placeId']) : '',
            isset($e['name']) ? sanitize_text_field((string) $e['name']) : '',
            isset($e['meta']) ? sanitize_text_field((string) $e['meta']) : '',
            $cid,
            fcl_event_time(isset($e['at']) ? $e['at'] : '')
        );
        $saved++;
    }
    update_user_meta($uid, 'fcl_last_active', fcl_now());
    return ['saved' => $saved, 'skipped' => $skipped];
}

function fcl_lead_out($row)
{
    $u = get_user_by('id', (int) $row->user_id);
    return [
        'placeId' => $row->place_id,
        'name' => $row->name,
        'category' => $row->category,
        'city' => $row->city,
        'status' => $row->status,
        'data' => $row->data ? json_decode($row->data, true) : null,
        'updatedAt' => fcl_iso($row->updated_at),
        'owner' => ['id' => (int) $row->user_id, 'name' => $u ? $u->display_name : ''],
    ];
}

/**
 * GET /leads?page=1&status=&user=
 * Team members get their own leads. Admins get everyone's, or one
 * member's with ?user=ID.
 */
function fcl_api_leads(WP_REST_Request $req)
{
    global $wpdb;
    $s = fcl_session($req);
    $where = ['1=1'];
    $args = [];
    if ($s['role'] === 'admin') {
        $user = (int) $req->get_param('user');
        if ($user) {
            $where[] = 'user_id = %d';
            $args[] = $user;
        }
    } else {
        $where[] = 'user_id = %d';
        $args[] = $s['user']->ID;
    }
    $status = sanitize_key((string) $req->get_param('status'));
    if ($status !== '') {
        $where[] = 'status = %s';
        $args[] = $status;
    }
    $per = 200;
    $page = max(1, (int) $req->get_param('page'));
    $table = fcl_table('leads');
    $w = implode(' AND ', $where);
    $countSql = "SELECT COUNT(*) FROM $table WHERE $w";
    $total = (int) ($args ? $wpdb->get_var($wpdb->prepare($countSql, $args)) : $wpdb->get_var($countSql));
    $listArgs = array_merge($args, [$per, ($page - 1) * $per]);
    $rows = $wpdb->get_results($wpdb->prepare("SELECT * FROM $table WHERE $w ORDER BY updated_at DESC LIMIT %d OFFSET %d", $listArgs));
    return ['total' => $total, 'page' => $page, 'items' => array_map('fcl_lead_out', $rows)];
}

/** PUT /leads/{place} {name, category, city, status, data}: saves this member's copy. */
function fcl_api_lead_save(WP_REST_Request $req)
{
    global $wpdb;
    $s = fcl_session($req);
    $uid = $s['user']->ID;
    $place = (string) $req->get_param('place');
    $data = $req->get_param('data');
    $json = $data === null ? null : wp_json_encode($data);
    if ($json !== null && strlen($json) > 300000) {
        return fcl_error('fcl_too_big', 'Lead data is too large.', 413);
    }
    $row = [
        'name' => mb_substr(sanitize_text_field((string) $req->get_param('name')), 0, 255),
        'category' => mb_substr(sanitize_text_field((string) $req->get_param('category')), 0, 120),
        'city' => mb_substr(sanitize_text_field((string) $req->get_param('city')), 0, 120),
        'status' => substr(preg_replace('/[^A-Za-z]/', '', (string) $req->get_param('status')), 0, 20) ?: 'newLead',
        'data' => $json,
        'updated_at' => fcl_now(),
    ];
    $table = fcl_table('leads');
    $id = $wpdb->get_var($wpdb->prepare("SELECT id FROM $table WHERE user_id = %d AND place_id = %s", $uid, $place));
    if ($id) {
        $wpdb->update($table, $row, ['id' => $id]);
    } else {
        $wpdb->insert($table, array_merge($row, ['user_id' => $uid, 'place_id' => $place, 'created_at' => fcl_now()]));
    }
    return ['ok' => true];
}

function fcl_api_lead_delete(WP_REST_Request $req)
{
    global $wpdb;
    $s = fcl_session($req);
    $wpdb->delete(fcl_table('leads'), ['user_id' => $s['user']->ID, 'place_id' => (string) $req->get_param('place')]);
    return ['ok' => true];
}

function fcl_api_report(WP_REST_Request $req)
{
    return fcl_report((string) $req->get_param('period'), (string) $req->get_param('date'));
}

function fcl_api_worker(WP_REST_Request $req)
{
    return fcl_worker_report((int) $req->get_param('id'), (string) $req->get_param('period'), (string) $req->get_param('date'));
}

function fcl_api_team(WP_REST_Request $req)
{
    [$from, $to] = fcl_period_bounds('day', null);
    $counts = fcl_counts($from, $to);
    $out = [];
    foreach (fcl_team_users() as $u) {
        $out[] = fcl_member_row($u, $counts);
    }
    return ['today' => $out];
}

/**
 * Adds someone to the team. $access is 'team' (app only) or 'admin'
 * (app + reports + team management). An email that already has a
 * WordPress account (e.g. a co-founder) just gets FC Leads access and
 * keeps their own password; $existing tells the caller.
 */
function fcl_add_member($name, $email, $password, $access = 'team', &$existing = false)
{
    $existing = false;
    $name = sanitize_text_field($name);
    $email = sanitize_email($email);
    $access = $access === 'admin' ? 'admin' : 'team';
    if (!is_email($email)) {
        return fcl_error('fcl_invalid', 'Add a valid email.', 400);
    }
    $uid = email_exists($email);
    if ($uid) {
        $u = get_user_by('id', $uid);
        if (user_can($u, 'fcl_work')) {
            return fcl_error('fcl_exists', 'This person is already on the team. Change their access in the list.', 409);
        }
        $u->add_role($access === 'admin' ? 'fcl_manager' : 'fcl_worker');
        $existing = true;
        return (int) $uid;
    }
    if ($name === '') {
        return fcl_error('fcl_invalid', 'Add a name and a valid email.', 400);
    }
    if (strlen($password) < 8) {
        return fcl_error('fcl_weak', 'The password needs at least 8 characters.', 400);
    }
    $login = sanitize_user(strstr($email, '@', true), true);
    if ($login === '' || username_exists($login)) {
        $login = 'fcl_' . wp_generate_password(8, false, false);
    }
    $id = wp_insert_user([
        'user_login' => $login,
        'user_email' => $email,
        'user_pass' => $password,
        'display_name' => $name,
        'first_name' => $name,
        'role' => $access === 'admin' ? 'fcl_manager' : 'fcl_worker',
    ]);
    if (is_wp_error($id)) {
        return fcl_error('fcl_create_failed', $id->get_error_message(), 400);
    }
    return (int) $id;
}

/**
 * Makes a member a team member or an admin. Site administrators are always
 * admins; nobody can change their own access.
 */
function fcl_set_access($id, $access, $by)
{
    $u = get_user_by('id', (int) $id);
    if (!$u || !user_can($u, 'fcl_work')) {
        return fcl_error('fcl_not_found', 'Team member not found.', 404);
    }
    if ((int) $id === (int) $by) {
        return fcl_error('fcl_self', 'You cannot change your own access.', 400);
    }
    if (user_can($u, 'manage_options')) {
        return fcl_error('fcl_site_admin', 'Site administrators are always FC Leads admins.', 400);
    }
    $access = $access === 'admin' ? 'admin' : 'team';
    $u->remove_role('fcl_worker');
    $u->remove_role('fcl_manager');
    $u->add_role($access === 'admin' ? 'fcl_manager' : 'fcl_worker');
    if ($access === 'team') {
        fcl_end_sessions($u->ID); // An admin session must not outlive the access.
    }
    return true;
}

function fcl_api_team_add(WP_REST_Request $req)
{
    $existing = false;
    $id = fcl_add_member(
        (string) $req->get_param('name'),
        (string) $req->get_param('email'),
        (string) $req->get_param('password'),
        (string) $req->get_param('access'),
        $existing
    );
    if (is_wp_error($id)) {
        return $id;
    }
    clean_user_cache($id);
    return ['member' => fcl_member_row(get_user_by('id', $id), []), 'existing' => $existing];
}

/** POST /admin/team/{id} {name?, password?, disabled?, access?: team|admin} */
function fcl_api_team_update(WP_REST_Request $req)
{
    $id = (int) $req->get_param('id');
    $u = get_user_by('id', $id);
    if (!$u || !user_can($u, 'fcl_work')) {
        return fcl_error('fcl_not_found', 'Team member not found.', 404);
    }
    $s = fcl_session($req);
    $update = ['ID' => $id];
    $name = $req->get_param('name');
    if (is_string($name) && trim($name) !== '') {
        $update['display_name'] = sanitize_text_field($name);
    }
    $pass = $req->get_param('password');
    if (is_string($pass) && $pass !== '') {
        if (strlen($pass) < 8) {
            return fcl_error('fcl_weak', 'The password needs at least 8 characters.', 400);
        }
        if (user_can($u, 'manage_options') && $id !== $s['user']->ID) {
            return fcl_error('fcl_forbidden', 'Change a site administrator\'s password in WordPress.', 403);
        }
        $update['user_pass'] = $pass;
    }
    if (count($update) > 1) {
        wp_update_user($update);
    }
    $disabled = $req->get_param('disabled');
    if ($disabled !== null) {
        if ($id === $s['user']->ID) {
            return fcl_error('fcl_self', 'You cannot turn off your own account.', 400);
        }
        if (rest_sanitize_boolean($disabled)) {
            update_user_meta($id, 'fcl_disabled', 1);
            fcl_end_sessions($id);
        } else {
            delete_user_meta($id, 'fcl_disabled');
        }
    }
    if (isset($update['user_pass'])) {
        fcl_end_sessions($id);
    }
    $access = $req->get_param('access');
    if (is_string($access) && $access !== '') {
        $r = fcl_set_access($id, $access, $s['user']->ID);
        if (is_wp_error($r)) {
            return $r;
        }
    }
    clean_user_cache($id);
    return ['member' => fcl_member_row(get_user_by('id', $id), [])];
}
