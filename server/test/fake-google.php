<?php
/**
 * Test only: answers Google Places calls made with the key "TESTKEY"
 * without leaving the machine. Copied into mu-plugins by the e2e script.
 */
add_filter('pre_http_request', function ($pre, $args, $url) {
    if (strpos($url, 'places.googleapis.com') === false) {
        return $pre;
    }
    $key = isset($args['headers']['X-Goog-Api-Key']) ? $args['headers']['X-Goog-Api-Key'] : '';
    if ($key !== 'TESTKEY') {
        return ['response' => ['code' => 403, 'message' => 'Forbidden'], 'body' => wp_json_encode(['error' => ['code' => 403, 'message' => 'API key not valid', 'status' => 'PERMISSION_DENIED']]), 'headers' => [], 'cookies' => []];
    }
    if (strpos($url, 'searchText') !== false) {
        $body = json_decode($args['body'], true);
        $places = [
            ['id' => 'p1', 'displayName' => ['text' => 'Rahim Tea House'], 'nationalPhoneNumber' => '01711-234567', 'rating' => 4.4, 'userRatingCount' => 12],
            ['id' => 'p2', 'displayName' => ['text' => 'Green Leaf Dental'], 'websiteUri' => 'https://greenleaf.example', 'rating' => 4.7, 'userRatingCount' => 220],
        ];
        return ['response' => ['code' => 200, 'message' => 'OK'], 'body' => wp_json_encode(['places' => $places, 'nextPageToken' => 'next-' . md5($body['textQuery'])]), 'headers' => [], 'cookies' => []];
    }
    return ['response' => ['code' => 200, 'message' => 'OK'], 'body' => wp_json_encode(['id' => 'p2', 'displayName' => ['text' => 'Green Leaf Dental'], 'rating' => 4.8, 'userRatingCount' => 230]), 'headers' => [], 'cookies' => []];
}, 10, 3);
