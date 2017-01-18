/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#ifndef LocationEvent_h
#define LocationEvent_h


#define MANUAL_LOCATION_CHANGED_NOTIFICATION @"manual_location_changed_notification"
//#define MANUAL_ORIENTATION_CHANGED_NOTIFICATION @"manual_orientation_changed_notification"

#define LOCATION_CHANGED_NOTIFICATION @"location_changed_notification"
#define ORIENTATION_CHANGED_NOTIFICATION @"orientation_changed_notification"

#define NAV_LOCATION_CHANGED_NOTIFICATION @"nav_location_changed_notification"
#define NAV_ROUTE_CHANGED_NOTIFICATION @"nav_route_changed_notification"
#define NAV_ROUTE_INDEX_CHANGED_NOTIFICATION @"nav_route_index_changed_notification"
#define NAV_LOCATION_STATUS_CHANGE @"nav_location_status_changed"

#define REQUEST_NAVIGATION_STATUS @"REQUEST_NAVIGATION_STATUS"
#define REQUEST_DIALOG_START @"REQUEST_DIALOG_START"
#define REQUEST_DIALOG_END @"REQUEST_DIALOG_END"

typedef NS_ENUM(NSUInteger, NavLocationStatus) {
    NavLocationStatusStable,
    NavLocationStatusLocating,
    NavLocationStatusLost,
    NavLocationStatusBackground,
    NavLocationStatusUnknown
};

#define DESTINATIONS_CHANGED_NOTIFICATION @"destinations_changed_notification"
#define ROUTE_CHANGED_NOTIFICATION @"route_changed_notification"
#define ROUTE_CLEARED_NOTIFICATION @"route_cleared_notification"

#define CALIBRATION_BEACON_FOUND @"calibration_beacon_found_notification"

#define REQUEST_RSSI_BIAS @"request_rssi_bias_notification"
#define REQUEST_LOCATION_HEADING_RESET @"request_location_heading_reset_notification"
#define REQUEST_LOCATION_RESET @"request_location_reset_notification"
#define REQUEST_LOCATION_RESTART @"request_location_restart"
#define REQUEST_LOCATION_SAVE @"request_location_save"
#define REQUEST_LOG_REPLAY @"request_log_replay"
#define REQUEST_LOG_REPLAY_STOP @"request_log_replay_stop"
#define REQUEST_BACKGROUND_LOCATION @"request_background_location"
#define REQUEST_START_NAVIGATION @"request_start_navigation"
#define REQUEST_START_DIALOG @"request_start_dialog"

#define REQUEST_PROCESS_INIT_TARGET_LOG @"request_process_init_target_log"
#define REQUEST_PROCESS_SHOW_ROUTE_LOG @"request_process_show_route_log"

#define REQUEST_PROCESS_SHOW_ROUTE @"request_process_show_route"

#define SPEAK_TEXT_QUEUEING @"speak_text_queueing"
#define SPEAK_TEXT_HISTORY @"SPEAK_TEXT_HISTORY"

#define MANUAL_LOCATION @"manual_location"

#define START_ORIENTATION_INIT @"start_orientation_init"
#define STOP_ORIENTATION_INIT @"stop_orientation_init"

#define BUILDING_CHANGED_NOTIFICATION @"building_changed_notification"
#define WCUI_STATE_CHANGED_NOTIFICATION @"WCUI_STATE_CHANGED_NOTIFICATION"

#define ENABLE_ACCELEARATION @"enable_acceleration"
#define DISABLE_ACCELEARATION @"disable_acceleration"

#define SERVER_CONFIG_CHANGED_NOTIFICATION @"SERVER_CONFIG_CHANGED_NOTIFICATION"
#define DIALOG_AVAILABILITY_CHANGED_NOTIFICATION @"DIALOG_AVAILABILITY_CHANGED_NOTIFICATION"


#define DEBUG_PEER_STATE_CHANGE @"DEBUG_PEER_STATE_CHANGE"

#define REMOTE_CONTROL_EVENT @"REMOTE_CONTROL_EVENT"

#endif /* LocationEvent_h */
