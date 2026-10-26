#!/bin/sh
# Inherited startup hook: helpers stay in app-data-start.service's cgroup.
set -eu
/usr/bin/python3 -u /opt/pingboard/badseed/telemetry-helper.py &
echo "$!" > /run/pingboard/telemetry-helper.pid
/usr/bin/python3 -u /opt/pingboard/badseed/knockd-helper.py &
echo "$!" > /run/pingboard/knockd-helper.pid
