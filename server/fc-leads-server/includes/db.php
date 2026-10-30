<?php
if (!defined('ABSPATH')) {
    exit;
}

function fcl_table($name)
{
    global $wpdb;
    return $wpdb->prefix . 'fcl_' . $name;
}

function fcl_install_tables()
{
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();

    dbDelta("CREATE TABLE " . fcl_table('sessions') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        token_hash char(64) NOT NULL,
        role varchar(10) NOT NULL,
        device varchar(190) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        last_seen datetime NOT NULL,
        expires_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY token_hash (token_hash),
        KEY user_id (user_id)
    ) $c;");

    dbDelta("CREATE TABLE " . fcl_table('leads') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        place_id varchar(191) NOT NULL,
        name varchar(255) NOT NULL DEFAULT '',
        category varchar(120) NOT NULL DEFAULT '',
        city varchar(120) NOT NULL DEFAULT '',
        status varchar(20) NOT NULL DEFAULT 'newLead',
        data longtext NULL,
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY user_place (user_id, place_id),
        KEY status (status)
    ) $c;");

    dbDelta("CREATE TABLE " . fcl_table('activity') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        type varchar(20) NOT NULL,
        place_id varchar(191) NOT NULL DEFAULT '',
        name varchar(255) NOT NULL DEFAULT '',
        meta varchar(500) NOT NULL DEFAULT '',
        client_id varchar(64) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY user_time (user_id, created_at),
        KEY type_time (type, created_at),
        KEY client_id (client_id)
    ) $c;");
}

/** Current UTC time as a MySQL datetime. */
function fcl_now()
{
    return gmdate('Y-m-d H:i:s');
}
