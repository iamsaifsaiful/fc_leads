<?php
/**
 * End-to-end checks for FC Leads Server against a running WordPress.
 * Usage: php e2e.php http://127.0.0.1:8089 /path/to/wp
 * Needs fake-google.php in mu-plugins and the admin user admin / adminpass123.
 */
$base = rtrim($argv[1] ?? 'http://127.0.0.1:8089', '/');
$wp = $argv[2] ?? '';
$fails = 0;
$checks = 0;

function req($method, $path, $body = null, $token = null, $header = 'bearer')
{
    global $base;
    $ch = curl_init($base . '/?rest_route=/fcleads/v1' . str_replace('?', '&', $path));
    $h = ['Content-Type: application/json'];
    if ($token) {
        $h[] = $header === 'bearer' ? 'Authorization: Bearer ' . $token : 'X-FCL-Token: ' . $token;
    }
    curl_setopt_array($ch, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => $h]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $out = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    return [$code, json_decode($out, true), $out];
}

function check($name, $ok, $extra = '')
{
    global $fails, $checks;
    $checks++;
    if ($ok) {
        echo "ok   $name\n";
    } else {
        $fails++;
        echo "FAIL $name $extra\n";
    }
}

function wpopt($php)
{
    global $wp;
    $code = '$_SERVER["HTTP_HOST"]="localhost:8089"; require "' . $wp . '/wp-load.php"; ' . $php;
    return shell_exec('php -r ' . escapeshellarg($code) . ' 2>&1');
}

// Clean slate for repeat runs.
wpopt('global $wpdb; foreach (["sessions","leads","activity"] as $t) $wpdb->query("DELETE FROM {$wpdb->prefix}fcl_$t"); foreach (get_users(["role__in"=>["fcl_worker","fcl_manager"]]) as $u) { require_once ABSPATH."wp-admin/includes/user.php"; wp_delete_user($u->ID); } update_option("fcl_settings", []); foreach (get_users(["search"=>"karim@example.com","search_columns"=>["user_email"]]) as $u) { require_once ABSPATH."wp-admin/includes/user.php"; wp_delete_user($u->ID); } foreach (["admin","nusrat@example.com","nobody","tania@example.com","karim@example.com"] as $l) delete_transient("fcl_fail_".md5(strtolower($l)."|127.0.0.1"));');

// --- Login ---
[$c] = req('POST', '/auth/login', ['login' => '', 'password' => '']);
check('empty login is refused (400)', $c === 400, $c);
[$c] = req('POST', '/auth/login', ['login' => 'admin', 'password' => 'wrong', 'role' => 'admin']);
check('wrong password is refused (401)', $c === 401, $c);
[$c, $j] = req('POST', '/auth/login', ['login' => 'admin', 'password' => 'adminpass123', 'role' => 'admin', 'device' => 'test']);
check('admin signs in as admin', $c === 200 && strlen($j['token'] ?? '') === 64 && $j['user']['role'] === 'admin', json_encode($j));
check('login sends app config without the key', isset($j['config']['dailyTarget']) && !isset($j['config']['placesKey']) && $j['config']['searchReady'] === false);
$admin = $j['token'];

// --- Team management ---
[$c, $j] = req('POST', '/admin/team', ['name' => 'Nusrat Rahman', 'email' => 'nusrat@example.com', 'password' => 'short'], $admin);
check('weak password is refused', $c === 400, $c);
[$c, $j] = req('POST', '/admin/team', ['name' => 'Nusrat Rahman', 'email' => 'nusrat@example.com', 'password' => 'teampass123'], $admin);
check('admin adds a team member', $c === 200 && $j['member']['name'] === 'Nusrat Rahman' && $j['member']['role'] === 'team', json_encode($j));
$wid = $j['member']['id'] ?? 0;
[$c] = req('POST', '/admin/team', ['name' => 'Again', 'email' => 'nusrat@example.com', 'password' => 'teampass123'], $admin);
check('same email twice is refused (409)', $c === 409, $c);

[$c] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'teampass123', 'role' => 'admin']);
check('team member cannot sign in as admin (403)', $c === 403, $c);
[$c, $j] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'teampass123', 'role' => 'team']);
check('team member signs in with email', $c === 200 && $j['user']['role'] === 'team', json_encode($j));
$team = $j['token'];

[$c, $j] = req('GET', '/me', null, $team);
check('Bearer header works', $c === 200 && $j['user']['email'] === 'nusrat@example.com');
[$c, $j] = req('GET', '/me', null, $team, 'x');
check('X-FCL-Token header works', $c === 200 && $j['user']['id'] === $wid);
[$c] = req('GET', '/me', null, str_repeat('a', 64));
check('unknown token is refused (401)', $c === 401, $c);

[$c] = req('GET', '/admin/report?period=day', null, $team);
check('team member cannot open reports (403)', $c === 403, $c);
[$c] = req('POST', '/admin/team', ['name' => 'X', 'email' => 'x@example.com', 'password' => 'xxxxxxxx1'], $team);
check('team member cannot add people (403)', $c === 403, $c);

// --- Google search through the server ---
[$c, $j] = req('POST', '/places/search', ['textQuery' => 'cafes in Dhaka'], $team);
check('search without a key explains (503)', $c === 503 && strpos($j['message'], 'admin') !== false, $c);
wpopt('$s = get_option("fcl_settings", []); $s["places_key"] = "BADKEY"; update_option("fcl_settings", $s);');
[$c, $j] = req('POST', '/places/search', ['textQuery' => 'cafes in Dhaka'], $team);
check('a refused Google key is reported (502)', $c === 502 && strpos($j['message'], 'refused') !== false, $c . ' ' . json_encode($j));
wpopt('$s = get_option("fcl_settings", []); $s["places_key"] = "TESTKEY"; $s["search_limit"] = 3; update_option("fcl_settings", $s);');
[$c, $j] = req('POST', '/places/search', ['textQuery' => 'cafes in Dhaka', 'regionCode' => 'BD'], $team);
check('search returns Google results unchanged', $c === 200 && count($j['places']) === 2 && $j['places'][0]['displayName']['text'] === 'Rahim Tea House' && isset($j['nextPageToken']), json_encode($j));
[$c, $j] = req('POST', '/places/search', ['textQuery' => 'cafes in Dhaka', 'pageToken' => 'x'], $team);
check('next page works', $c === 200);
[$c, $j] = req('GET', '/places/p2', null, $team);
check('place details come back', $c === 200 && $j['rating'] === 4.8, json_encode($j));
[$c] = req('POST', '/places/search', ['textQuery' => 'one more'], $team);
[$c] = req('POST', '/places/search', ['textQuery' => 'too many'], $team);
check('daily search limit (429)', $c === 429, $c);
[$c, $j] = req('POST', '/auth/login', ['login' => 'admin', 'password' => 'adminpass123', 'role' => 'admin']);
check('config shows search is ready', $j['config']['searchReady'] === true);

// --- Activity ---
$now = gmdate('c');
$events = [
    ['id' => 'e1', 'type' => 'audit', 'placeId' => 'p1', 'name' => 'Rahim Tea House', 'at' => $now],
    ['id' => 'e2', 'type' => 'audit', 'placeId' => 'p2', 'name' => 'Green Leaf Dental', 'at' => $now],
    ['id' => 'e3', 'type' => 'whatsapp', 'placeId' => 'p1', 'name' => 'Rahim Tea House', 'meta' => 'chat', 'at' => $now],
    ['id' => 'e4', 'type' => 'whatsapp', 'placeId' => 'p1', 'name' => 'Rahim Tea House', 'meta' => 'graphic', 'at' => $now],
    ['id' => 'e5', 'type' => 'email', 'placeId' => 'p2', 'name' => 'Green Leaf Dental', 'at' => $now],
    ['id' => 'e6', 'type' => 'status', 'placeId' => 'p1', 'name' => 'Rahim Tea House', 'meta' => 'replied', 'at' => $now],
    ['id' => 'e7', 'type' => 'status', 'placeId' => 'p2', 'name' => 'Green Leaf Dental', 'meta' => 'won', 'at' => $now],
    ['id' => 'e8', 'type' => 'search', 'placeId' => '', 'name' => 'fake'],
    ['id' => 'e9', 'type' => 'followup', 'placeId' => 'p1', 'name' => 'Rahim Tea House', 'at' => '2020-01-01T00:00:00Z'],
];
[$c, $j] = req('POST', '/activity', ['events' => $events], $team);
check('activity saved; app cannot fake searches', $c === 200 && $j['saved'] === 8 && $j['skipped'] === 1, json_encode($j));
[$c, $j] = req('POST', '/activity', ['events' => array_slice($events, 0, 3)], $team);
check('resent events are not counted twice', $c === 200 && $j['saved'] === 0 && $j['skipped'] === 3, json_encode($j));

// --- Reports ---
[$c, $j] = req('GET', '/admin/report?period=day', null, $admin);
$t = $j['totals'] ?? [];
check('day totals: 2 leads, 2 messaged, 1 reply, 1 won, 3 searches', $c === 200 && $t['leads'] === 2 && $t['sent'] === 2 && $t['replies'] === 1 && $t['won'] === 1 && $t['searches'] === 3, json_encode($t));
$row = null;
foreach ($j['team'] ?? [] as $m) {
    if ($m['id'] === $wid) {
        $row = $m;
    }
}
check('team row for the member', $row && $row['leads'] === 2 && $row['sent'] === 2 && $row['initials'] === 'NR' && $row['lastActive'] !== null, json_encode($row));
check('day chart has 24 hours with 2 leads', count($j['bars']) === 24 && array_sum(array_column($j['bars'], 'leads')) === 2);
check('previous day is empty', $j['previous']['leads'] === 0);
[$c, $j] = req('GET', '/admin/report?period=week', null, $admin);
check('week report: 7 days, same totals', $c === 200 && count($j['bars']) === 7 && $j['totals']['leads'] === 2, json_encode($j['totals'] ?? null));
[$c, $j] = req('GET', '/admin/report?period=month', null, $admin);
check('month report: weeks, same totals', $c === 200 && count($j['bars']) >= 4 && $j['totals']['sent'] === 2);
[$c, $j] = req('GET', '/admin/report?period=day&date=2020-01-01', null, $admin);
check('an old day is empty', $c === 200 && $j['totals']['leads'] === 0);

[$c, $j] = req('GET', '/admin/workers/' . $wid . '?period=week', null, $admin);
check('one member report with recent activity', $c === 200 && $j['member']['won'] === 1 && count($j['recent']) === 11 && $j['recent'][0]['at'] !== null, json_encode(['n' => count($j['recent'] ?? [])]));
[$c, $j] = req('GET', '/admin/team', null, $admin);
check('team list with today numbers', $c === 200 && count($j['today']) >= 1);

// --- Leads sync ---
[$c] = req('PUT', '/leads/p1', ['name' => 'Rahim Tea House', 'category' => 'Cafes', 'city' => 'Dhaka', 'status' => 'replied', 'data' => ['notes' => 'Owner: Karim', 'items' => [1, 2]]], $team);
check('lead saved', $c === 200, $c);
[$c] = req('PUT', '/leads/p1', ['name' => 'Rahim Tea House', 'status' => 'interested', 'data' => ['notes' => 'Owner: Karim (updated)']], $team);
[$c, $j] = req('GET', '/leads', null, $team);
check('lead updated, not duplicated', $c === 200 && $j['total'] === 1 && $j['items'][0]['status'] === 'interested' && $j['items'][0]['data']['notes'] === 'Owner: Karim (updated)', json_encode($j));
[$c, $j] = req('GET', '/leads', null, $admin);
check('admin sees everyone\'s leads with owner', $c === 200 && $j['total'] === 1 && $j['items'][0]['owner']['name'] === 'Nusrat Rahman');
[$c, $j] = req('GET', '/leads?user=' . $wid . '&status=interested', null, $admin);
check('admin filters by member and status', $j['total'] === 1);
[$c] = req('DELETE', '/leads/p1', null, $team);
[$c, $j] = req('GET', '/leads', null, $team);
check('lead deleted', $j['total'] === 0);

// --- Turning accounts off, passwords, logout ---
[$c, $j] = req('POST', '/admin/team/' . $wid, ['disabled' => true], $admin);
check('admin turns a member off', $c === 200 && $j['member']['disabled'] === true);
[$c] = req('GET', '/me', null, $team);
check('turned-off member is signed out (401)', $c === 401, $c);
[$c] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'teampass123']);
check('turned-off member cannot sign in (403)', $c === 403, $c);
req('POST', '/admin/team/' . $wid, ['disabled' => false], $admin);
[$c, $j] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'teampass123']);
check('turned back on: can sign in', $c === 200);
$team = $j['token'];
[$c] = req('POST', '/admin/team/' . $wid, ['password' => 'newpass12345'], $admin);
[$c2] = req('GET', '/me', null, $team);
check('new password signs the member out', $c === 200 && $c2 === 401, "$c $c2");
[$c, $j] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'newpass12345']);
check('new password works', $c === 200);
$team = $j['token'];
[$c] = req('POST', '/admin/team/1', ['disabled' => true], $admin);
check('admin cannot turn off their own account', $c === 400, $c);
req('POST', '/auth/logout', null, $team);
[$c] = req('GET', '/me', null, $team);
check('logout ends the session', $c === 401);

// --- More than one admin ---
[$c, $j] = req('POST', '/admin/team', ['name' => 'Tania Haque', 'email' => 'tania@example.com', 'password' => 'adminpass456', 'access' => 'admin'], $admin);
check('admin adds a second admin', $c === 200 && $j['member']['role'] === 'admin', json_encode($j));
$tid = $j['member']['id'] ?? 0;
[$c, $j] = req('POST', '/auth/login', ['login' => 'tania@example.com', 'password' => 'adminpass456', 'role' => 'admin']);
check('second admin signs in with Admin', $c === 200 && $j['user']['role'] === 'admin', json_encode($j));
$admin2 = $j['token'] ?? '';
[$c, $j] = req('GET', '/admin/report?period=day', null, $admin2);
check('second admin sees reports', $c === 200 && isset($j['totals']));
[$c, $j] = req('POST', '/auth/login', ['login' => 'tania@example.com', 'password' => 'adminpass456', 'role' => 'team']);
check('an admin can also use the Team login', $c === 200 && $j['user']['role'] === 'team');
[$c, $j] = req('POST', '/admin/team/' . $wid, ['access' => 'admin'], $admin2);
check('second admin makes a team member an admin', $c === 200 && $j['member']['role'] === 'admin', json_encode($j));
[$c] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'newpass12345', 'role' => 'admin']);
check('promoted member can sign in as admin', $c === 200, $c);
[$c, $j] = req('POST', '/admin/team/' . $wid, ['access' => 'team'], $admin);
check('admin makes them a team member again', $c === 200 && $j['member']['role'] === 'team');
[$c] = req('POST', '/auth/login', ['login' => 'nusrat@example.com', 'password' => 'newpass12345', 'role' => 'admin']);
check('demoted member cannot use Admin login (403)', $c === 403, $c);
[$c] = req('POST', '/admin/team/' . $tid, ['access' => 'team'], $admin2);
check('nobody changes their own access', $c === 400, $c);
[$c, $j] = req('POST', '/admin/team/1', ['access' => 'team'], $admin2);
check('site administrator stays admin', $c === 400, $c);
wpopt('wp_insert_user(["user_login"=>"karim","user_email"=>"karim@example.com","user_pass"=>"ownpass789","role"=>"editor"]);');
[$c, $j] = req('POST', '/admin/team', ['name' => '', 'email' => 'karim@example.com', 'password' => '', 'access' => 'admin'], $admin);
check('existing site user gets admin access, keeps password', $c === 200 && $j['existing'] === true && $j['member']['role'] === 'admin', json_encode($j));
[$c] = req('POST', '/auth/login', ['login' => 'karim', 'password' => 'ownpass789', 'role' => 'admin']);
check('existing user signs in as admin with own password', $c === 200, $c);
[$c, $j] = req('GET', '/admin/team', null, $admin);
$roles = [];
foreach ($j['today'] ?? [] as $m) { $roles[$m['email']] = $m['role'] . (!empty($m['siteAdmin']) ? '*' : ''); }
check('team list shows every admin', ($roles['tania@example.com'] ?? '') === 'admin' && ($roles['karim@example.com'] ?? '') === 'admin' && in_array('admin*', $roles, true), json_encode($roles));

// --- Lockout after 5 wrong tries ---
for ($i = 0; $i < 5; $i++) {
    req('POST', '/auth/login', ['login' => 'nobody', 'password' => 'x']);
}
[$c] = req('POST', '/auth/login', ['login' => 'nobody', 'password' => 'x']);
check('locked after 5 wrong tries (429)', $c === 429, $c);

// --- wp-admin pages render without errors ---
$html = wpopt('require_once ABSPATH . "wp-admin/includes/admin.php"; wp_set_current_user(1); ob_start(); fcl_page_report(); $_GET["member"] = ' . (int) $wid . '; fcl_page_report(); unset($_GET["member"]); fcl_page_team(); fcl_page_settings(); echo ob_get_clean();');
check('admin pages render', strpos($html, 'team report') !== false && strpos($html, 'Add a person') !== false && strpos($html, 'Make admin') !== false && strpos($html, 'Google Places API key') !== false && strpos($html, 'Fatal') === false && strpos($html, 'Warning') === false, substr($html, 0, 400));
check('admin page lists the member', strpos($html, 'Nusrat Rahman') !== false);

echo "\n$checks checks, $fails failed\n";
echo $fails === 0 ? "ALL OK\n" : "SOME FAILED\n";
exit($fails === 0 ? 0 : 1);
