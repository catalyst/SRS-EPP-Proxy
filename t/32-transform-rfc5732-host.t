#!/usr/bin/perl -w
#
# test script for transformation of RFC5730 requests to SRS requests,
# and SRS responses to RFC5730 responses.

use strict;
use Test::More;

# Includes:
#
#  - RFC5730 session management commands:
#    - Hello / Greeting
#    - login
#    - login with newpassword
#    - logout
#
#  - RFC5730 Query commands
#    - <check>
#      - host <=> ???
#    - <info>
#      - host <=> ???
#    - <transfer>
#      - host <=> ???
#
#  - RFC5730 Transform commands
#    - <create>
#      - host <=> (error)
#    - <renew>
#      - host <=> (error)
#    - <transfer>
#      - host <=> (error)
#    - <update>
#      - host <=> (error)
#    - <delete>
#      - host <=> (error)

plan skip_all => "TODO";

# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Artistic License 2.0 for more details.
#
# You should have received a copy of the Artistic License the file
# COPYING.txt.  If not, see
# <http://www.perlfoundation.org/artistic_license_2_0>
1
