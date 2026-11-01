<?php
/**
 * Plugin Name: FC Leads Server
 * Description: Server for the FC Leads app: team and admin login, Google Places search through the site, lead sync, and daily, weekly and monthly work reports.
 * Version: 1.1.0
 * Requires at least: 6.0
 * Requires PHP: 7.4
 * Author: FansConnector
 * Text Domain: fc-leads-server
 */

if (!defined('ABSPATH')) {
    exit;
}

define('FCL_VERSION', '1.1.0');
define('FCL_DIR', plugin_dir_path(__FILE__));
define('FCL_NS', 'fcleads/v1');

require_once FCL_DIR . 'includes/db.php';
require_once FCL_DIR . 'includes/auth.php';
require_once FCL_DIR . 'includes/reports.php';
require_once FCL_DIR . 'includes/places.php';
require_once FCL_DIR . 'includes/api.php';
require_once FCL_DIR . 'includes/admin.php';

register_activation_hook(__FILE__, 'fcl_activate');
add_action('plugins_loaded', 'fcl_maybe_upgrade');
add_action('rest_api_init', 'fcl_register_routes');
add_action('fcl_daily_cleanup', 'fcl_cleanup_sessions');

/** Creates tables and roles. Safe to run more than once. */
function fcl_activate()
{
    fcl_install_tables();
    fcl_install_roles();
    update_option('fcl_db_version', FCL_VERSION);
    if (!wp_next_scheduled('fcl_daily_cleanup')) {
        wp_schedule_event(time() + HOUR_IN_SECONDS, 'daily', 'fcl_daily_cleanup');
    }
}

function fcl_maybe_upgrade()
{
    if (get_option('fcl_db_version') !== FCL_VERSION) {
        fcl_activate();
    }
}

register_deactivation_hook(__FILE__, function () {
    wp_clear_scheduled_hook('fcl_daily_cleanup');
});

/**
 * Team members get the "FC Leads team" role (can use the app).
 * Site administrators and "FC Leads manager" users can open reports.
 */
function fcl_install_roles()
{
    if (!get_role('fcl_worker')) {
        add_role('fcl_worker', 'FC Leads team', ['read' => true, 'fcl_work' => true]);
    }
    if (!get_role('fcl_manager')) {
        add_role('fcl_manager', 'FC Leads manager', ['read' => true, 'fcl_work' => true, 'fcl_manage' => true]);
    }
    $admin = get_role('administrator');
    if ($admin) {
        $admin->add_cap('fcl_work');
        $admin->add_cap('fcl_manage');
    }
}

/** Plugin settings with defaults. */
function fcl_settings()
{
    $defaults = [
        'places_key' => '',
        'daily_target' => 20,
        'search_limit' => 300,
        'agency_name' => 'FansConnector',
        'agency_website' => 'fansconnector.com',
        'agency_whatsapp' => '',
        'agency_email' => '',
    ];
    $saved = get_option('fcl_settings', []);
    return array_merge($defaults, is_array($saved) ? $saved : []);
}

/** The Google key: wp-config constant wins over the settings page. */
function fcl_places_key()
{
    if (defined('FCL_PLACES_KEY') && FCL_PLACES_KEY) {
        return FCL_PLACES_KEY;
    }
    return trim((string) fcl_settings()['places_key']);
}
