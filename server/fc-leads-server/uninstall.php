<?php
// Deleting the plugin keeps the data (leads and activity) unless
// FCL_DELETE_DATA is set to true in wp-config.php.
if (!defined('WP_UNINSTALL_PLUGIN')) {
    exit;
}
if (!defined('FCL_DELETE_DATA') || !FCL_DELETE_DATA) {
    return;
}
global $wpdb;
foreach (['sessions', 'leads', 'activity'] as $t) {
    $wpdb->query('DROP TABLE IF EXISTS ' . $wpdb->prefix . 'fcl_' . $t);
}
delete_option('fcl_settings');
delete_option('fcl_db_version');
remove_role('fcl_worker');
remove_role('fcl_manager');
