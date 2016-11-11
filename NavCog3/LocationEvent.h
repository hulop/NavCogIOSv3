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
#define START_LOCATING @"start_locating"
#define FINISH_LOCATING @"finish_locating"

#define NAV_LOCATION_CHANGED_NOTIFICATION @"nav_location_changed_notification"
#define NAV_ROUTE_CHANGED_NOTIFICATION @"nav_route_changed_notification"
#define NAV_ROUTE_INDEX_CHANGED_NOTIFICATION @"nav_route_index_changed_notification"

#define DESTINATIONS_CHANGED_NOTIFICATION @"destinations_changed_notification"
#define ROUTE_CHANGED_NOTIFICATION @"route_changed_notification"
#define ROUTE_CLEARED_NOTIFICATION @"route_cleared_notification"

#define CALIBRATION_BEACON_FOUND @"calibration_beacon_found_notification"

#define REQUEST_RSSI_BIAS @"request_rssi_bias_notification"
#define REQUEST_LOCATION_RESET @"request_location_reset_notification"
#define REQUEST_LOCATION_RESTART @"request_location_restart"
#define REQUEST_LOG_REPLAY @"request_log_replay"
#define REQUEST_LOG_REPLAY_STOP @"request_log_replay_stop"

#define REQUEST_PROCESS_INIT_TARGET_LOG @"request_process_init_target_log"
#define REQUEST_PROCESS_SHOW_ROUTE_LOG @"request_process_show_route_log"

#define SPEAK_TEXT_QUEUEING @"speak_text_queueing"

#define MANUAL_LOCATION @"manual_location"

#endif /* LocationEvent_h */
