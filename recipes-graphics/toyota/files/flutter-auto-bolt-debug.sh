#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
exec /usr/bin/flutter-auto -c -b "$@" --vm-service-host=0.0.0.0 --vm-service-port=22342 --disable-service-auth-codes
