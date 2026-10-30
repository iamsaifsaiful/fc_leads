<?php
if (!defined('ABSPATH')) {
    exit;
}

/** Things the app may report. "search" is logged by the server itself. */
const FCL_EVENT_TYPES = ['audit', 'whatsapp', 'email', 'status', 'followup', 'client'];

function fcl_log($user_id, $type, $place_id, $name, $meta = '', $client_id = '', $at = null)
{
    global $wpdb;
    return $wpdb->insert(fcl_table('activity'), [
        'user_id' => (int) $user_id,
        'type' => substr($type, 0, 20),
        'place_id' => substr((string) $place_id, 0, 191),
        'name' => mb_substr((string) $name, 0, 255),
        'meta' => mb_substr((string) $meta, 0, 500),
        'client_id' => substr((string) $client_id, 0, 64),
        'created_at' => $at ?: fcl_now(),
    ]);
}

/**
 * Start and end of a day, week or month in the site's time zone, as UTC
 * datetimes for queries. Returns [fromUtc, toUtc, localStart, localEnd].
 */
function fcl_period_bounds($period, $date)
{
    $tz = wp_timezone();
    $base = null;
    if (is_string($date) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        $base = DateTimeImmutable::createFromFormat('!Y-m-d', $date, $tz);
    }
    if (!$base) {
        $base = (new DateTimeImmutable('now', $tz))->setTime(0, 0);
    }
    switch ($period) {
        case 'week':
            $startDay = (int) get_option('start_of_week', 6);
            $back = ((int) $base->format('w') - $startDay + 7) % 7;
            $start = $base->modify("-{$back} days");
            $end = $start->modify('+7 days');
            break;
        case 'month':
            $start = $base->modify('first day of this month');
            $end = $start->modify('+1 month');
            break;
        default:
            $start = $base;
            $end = $start->modify('+1 day');
    }
    $utc = new DateTimeZone('UTC');
    return [
        $start->setTimezone($utc)->format('Y-m-d H:i:s'),
        $end->setTimezone($utc)->format('Y-m-d H:i:s'),
        $start,
        $end,
    ];
}

/** The period just before (yesterday, last week, last month). */
function fcl_previous_bounds($period, $localStart)
{
    $prev = $period === 'month' ? $localStart->modify('-1 month') : ($period === 'week' ? $localStart->modify('-7 days') : $localStart->modify('-1 day'));
    return fcl_period_bounds($period, $prev->format('Y-m-d'));
}

/** Per-user counts for a period: leads, sent, replies, won, searches. */
function fcl_counts($from, $to, $user_id = 0)
{
    global $wpdb;
    $sql = 'SELECT user_id,
        COUNT(DISTINCT CASE WHEN type = \'audit\' THEN place_id END) AS leads,
        COUNT(DISTINCT CASE WHEN type IN (\'whatsapp\', \'email\') THEN place_id END) AS sent,
        COUNT(DISTINCT CASE WHEN type = \'status\' AND meta = \'replied\' THEN place_id END) AS replies,
        COUNT(DISTINCT CASE WHEN type = \'status\' AND meta = \'won\' THEN place_id END) AS won,
        SUM(CASE WHEN type = \'search\' THEN 1 ELSE 0 END) AS searches
        FROM ' . fcl_table('activity') . ' WHERE created_at >= %s AND created_at < %s';
    $args = [$from, $to];
    if ($user_id) {
        $sql .= ' AND user_id = %d';
        $args[] = (int) $user_id;
    }
    $sql .= ' GROUP BY user_id';
    $rows = $wpdb->get_results($wpdb->prepare($sql, $args));
    $out = [];
    foreach ($rows as $r) {
        $out[(int) $r->user_id] = [
            'leads' => (int) $r->leads,
            'sent' => (int) $r->sent,
            'replies' => (int) $r->replies,
            'won' => (int) $r->won,
            'searches' => (int) $r->searches,
        ];
    }
    return $out;
}

function fcl_sum_counts($per_user)
{
    $t = ['leads' => 0, 'sent' => 0, 'replies' => 0, 'won' => 0, 'searches' => 0];
    foreach ($per_user as $c) {
        foreach ($t as $k => $_) {
            $t[$k] += $c[$k];
        }
    }
    return $t;
}

/** Bars for a chart: leads checked and leads messaged per hour, day or week. */
function fcl_bars($period, $from, $to, $localStart, $user_id = 0)
{
    global $wpdb;
    $tz = wp_timezone();
    $sql = 'SELECT type, place_id, created_at FROM ' . fcl_table('activity')
        . " WHERE created_at >= %s AND created_at < %s AND type IN ('audit', 'whatsapp', 'email')";
    $args = [$from, $to];
    if ($user_id) {
        $sql .= ' AND user_id = %d';
        $args[] = (int) $user_id;
    }
    $rows = $wpdb->get_results($wpdb->prepare($sql, $args));

    $labels = [];
    if ($period === 'day') {
        for ($h = 0; $h < 24; $h++) {
            $labels[] = (string) ($h % 12 === 0 ? 12 : $h % 12);
        }
    } elseif ($period === 'week') {
        for ($d = 0; $d < 7; $d++) {
            $labels[] = $localStart->modify("+{$d} days")->format('D');
        }
    } else {
        $days = (int) $localStart->format('t');
        for ($w = 1; $w <= (int) ceil($days / 7); $w++) {
            $labels[] = 'Wk ' . $w;
        }
    }
    $leads = array_fill(0, count($labels), []);
    $sent = array_fill(0, count($labels), []);
    foreach ($rows as $r) {
        $local = (new DateTimeImmutable($r->created_at, new DateTimeZone('UTC')))->setTimezone($tz);
        if ($period === 'day') {
            $i = (int) $local->format('G');
        } elseif ($period === 'week') {
            $i = (int) floor(($local->getTimestamp() - $localStart->getTimestamp()) / DAY_IN_SECONDS);
        } else {
            $i = (int) floor(((int) $local->format('j') - 1) / 7);
        }
        if ($i < 0 || $i >= count($labels)) {
            continue;
        }
        $key = $r->place_id !== '' ? $r->place_id : $r->created_at;
        if ($r->type === 'audit') {
            $leads[$i][$key] = true;
        } else {
            $sent[$i][$key] = true;
        }
    }
    $out = [];
    foreach ($labels as $i => $label) {
        $out[] = ['label' => $label, 'leads' => count($leads[$i]), 'sent' => count($sent[$i])];
    }
    return $out;
}

function fcl_initials($name)
{
    $parts = preg_split('/\s+/', trim($name));
    $a = isset($parts[0]) ? mb_substr($parts[0], 0, 1) : '';
    $b = count($parts) > 1 ? mb_substr(end($parts), 0, 1) : '';
    return mb_strtoupper($a . $b);
}

function fcl_iso($mysql_utc)
{
    if (!$mysql_utc) {
        return null;
    }
    return (new DateTimeImmutable($mysql_utc, new DateTimeZone('UTC')))->setTimezone(wp_timezone())->format(DATE_ATOM);
}

/** Everyone on the team: team role, managers, and anyone with activity. */
function fcl_team_users($extra_ids = [])
{
    $users = get_users(['role__in' => ['fcl_worker', 'fcl_manager'], 'orderby' => 'display_name']);
    $seen = [];
    foreach ($users as $u) {
        $seen[$u->ID] = true;
    }
    foreach ($extra_ids as $id) {
        if (!isset($seen[$id])) {
            $u = get_user_by('id', $id);
            if ($u) {
                $users[] = $u;
                $seen[$id] = true;
            }
        }
    }
    return $users;
}

function fcl_member_row($u, $counts)
{
    $c = isset($counts[$u->ID]) ? $counts[$u->ID] : ['leads' => 0, 'sent' => 0, 'replies' => 0, 'won' => 0, 'searches' => 0];
    $name = trim($u->display_name) !== '' ? $u->display_name : $u->user_login;
    return array_merge([
        'id' => (int) $u->ID,
        'name' => $name,
        'initials' => fcl_initials($name),
        'email' => $u->user_email,
        'role' => in_array('fcl_worker', (array) $u->roles, true) ? 'team' : 'manager',
        'disabled' => fcl_is_disabled($u->ID),
        'lastActive' => fcl_iso(get_user_meta($u->ID, 'fcl_last_active', true)),
    ], $c);
}

/** GET /admin/report?period=day|week|month&date=YYYY-MM-DD */
function fcl_report($period, $date)
{
    $period = in_array($period, ['day', 'week', 'month'], true) ? $period : 'week';
    [$from, $to, $start, $end] = fcl_period_bounds($period, $date);
    [$pFrom, $pTo] = fcl_previous_bounds($period, $start);

    $counts = fcl_counts($from, $to);
    $team = [];
    foreach (fcl_team_users(array_keys($counts)) as $u) {
        $team[] = fcl_member_row($u, $counts);
    }
    usort($team, function ($a, $b) {
        return [$b['leads'], $b['sent']] <=> [$a['leads'], $a['sent']];
    });

    return [
        'period' => $period,
        'from' => $start->format(DATE_ATOM),
        'to' => $end->format(DATE_ATOM),
        'totals' => fcl_sum_counts($counts),
        'previous' => fcl_sum_counts(fcl_counts($pFrom, $pTo)),
        'bars' => fcl_bars($period, $from, $to, $start),
        'team' => $team,
        'dailyTarget' => (int) fcl_settings()['daily_target'],
    ];
}

/** GET /admin/workers/{id}?period=… */
function fcl_worker_report($user_id, $period, $date)
{
    global $wpdb;
    $u = get_user_by('id', $user_id);
    if (!$u) {
        return fcl_error('fcl_not_found', 'Team member not found.', 404);
    }
    $period = in_array($period, ['day', 'week', 'month'], true) ? $period : 'week';
    [$from, $to, $start, $end] = fcl_period_bounds($period, $date);
    $counts = fcl_counts($from, $to, $user_id);
    $rows = $wpdb->get_results($wpdb->prepare(
        'SELECT type, place_id, name, meta, created_at FROM ' . fcl_table('activity')
            . ' WHERE user_id = %d ORDER BY created_at DESC, id DESC LIMIT 40',
        $user_id
    ));
    $recent = [];
    foreach ($rows as $r) {
        $recent[] = ['type' => $r->type, 'placeId' => $r->place_id, 'name' => $r->name, 'meta' => $r->meta, 'at' => fcl_iso($r->created_at)];
    }
    $first = $wpdb->get_var($wpdb->prepare('SELECT MIN(created_at) FROM ' . fcl_table('activity') . ' WHERE user_id = %d', $user_id));
    return [
        'member' => fcl_member_row($u, $counts),
        'since' => fcl_iso($first ?: $u->user_registered),
        'period' => $period,
        'from' => $start->format(DATE_ATOM),
        'to' => $end->format(DATE_ATOM),
        'bars' => fcl_bars($period, $from, $to, $start, $user_id),
        'recent' => $recent,
    ];
}
