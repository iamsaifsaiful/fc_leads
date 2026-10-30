<?php
if (!defined('ABSPATH')) {
    exit;
}

const FCL_PLACES_FIELDS = 'places.id,places.displayName,places.formattedAddress,'
    . 'places.nationalPhoneNumber,places.internationalPhoneNumber,'
    . 'places.websiteUri,places.rating,places.userRatingCount,'
    . 'places.googleMapsUri,places.businessStatus,'
    . 'places.primaryTypeDisplayName,nextPageToken';

/** Searches today by this user (site time zone). */
function fcl_searches_today($user_id)
{
    global $wpdb;
    [$from, $to] = fcl_period_bounds('day', null);
    return (int) $wpdb->get_var($wpdb->prepare(
        'SELECT COUNT(*) FROM ' . fcl_table('activity') . " WHERE user_id = %d AND type = 'search' AND created_at >= %s AND created_at < %s",
        $user_id,
        $from,
        $to
    ));
}

/** Passes Google's reply through unchanged so the app parses it as before. */
function fcl_google_reply($res)
{
    if (is_wp_error($res)) {
        return fcl_error('fcl_google_unreachable', 'Could not reach Google from the server. Try again.', 502);
    }
    $code = (int) wp_remote_retrieve_response_code($res);
    $body = json_decode(wp_remote_retrieve_body($res), true);
    if (!is_array($body)) {
        $body = [];
    }
    if ($code !== 200) {
        $msg = isset($body['error']['message']) ? (string) $body['error']['message'] : 'Google search failed.';
        $status = $code === 403 ? 'The Google key on the server was refused. Ask your admin to check it.' : $msg;
        return fcl_error('fcl_google_error', $status, $code === 429 ? 429 : 502);
    }
    return $body;
}

/** POST /places/search {textQuery, pageToken?, regionCode?} */
function fcl_api_places_search(WP_REST_Request $req)
{
    $s = fcl_session($req);
    $key = fcl_places_key();
    if ($key === '') {
        return fcl_error('fcl_no_key', 'Search is not set up yet. Ask your admin to add the Google key on the website.', 503);
    }
    $query = trim(sanitize_text_field((string) $req->get_param('textQuery')));
    if ($query === '') {
        return fcl_error('fcl_missing', 'Type what to search for.', 400);
    }
    $limit = (int) fcl_settings()['search_limit'];
    if ($limit > 0 && fcl_searches_today($s['user']->ID) >= $limit) {
        return fcl_error('fcl_limit', 'Daily search limit reached. Try again tomorrow.', 429);
    }

    $payload = ['textQuery' => $query, 'pageSize' => 20];
    $page = (string) $req->get_param('pageToken');
    if ($page !== '') {
        $payload['pageToken'] = $page;
    }
    $region = strtolower(preg_replace('/[^a-zA-Z]/', '', (string) $req->get_param('regionCode')));
    if (strlen($region) === 2) {
        $payload['regionCode'] = $region;
    }

    $res = wp_remote_post('https://places.googleapis.com/v1/places:searchText', [
        'timeout' => 20,
        'headers' => [
            'Content-Type' => 'application/json',
            'X-Goog-Api-Key' => $key,
            'X-Goog-FieldMask' => FCL_PLACES_FIELDS,
        ],
        'body' => wp_json_encode($payload),
    ]);
    $body = fcl_google_reply($res);
    if (is_wp_error($body)) {
        return $body;
    }
    $count = isset($body['places']) && is_array($body['places']) ? count($body['places']) : 0;
    fcl_log($s['user']->ID, 'search', '', $query, ($page !== '' ? 'more:' : '') . $count);
    return $body;
}

/** GET /places/{id}: fresh details for one business. */
function fcl_api_place_details(WP_REST_Request $req)
{
    $key = fcl_places_key();
    if ($key === '') {
        return fcl_error('fcl_no_key', 'Search is not set up yet. Ask your admin to add the Google key on the website.', 503);
    }
    $id = preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $req->get_param('id'));
    if ($id === '') {
        return fcl_error('fcl_missing', 'Missing place.', 400);
    }
    $fields = implode(',', array_map(function ($f) {
        return substr($f, strlen('places.'));
    }, array_filter(explode(',', FCL_PLACES_FIELDS), function ($f) {
        return strpos($f, 'places.') === 0;
    })));
    $res = wp_remote_get('https://places.googleapis.com/v1/places/' . rawurlencode($id), [
        'timeout' => 20,
        'headers' => ['X-Goog-Api-Key' => $key, 'X-Goog-FieldMask' => $fields],
    ]);
    return fcl_google_reply($res);
}
