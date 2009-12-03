#!/usr/bin/perl -w
#
# test script for the server base class - SSL connections and
# handshake logic

use strict;
use Test::More;

# - test a basic RFC5734 session flow:
#   - connect;
#   - receive and validate greeting
#   - message queuing/exchange using mocked messages:
#      - send <login> message
#      - server sends response
#      - (optional) send a dummy command and check response
#      - (optional) test request/response pipelining
#      - send <logout> message (mocked)
#      - check logout response, wait for remote disconnect
#   - hang up

# The server module must defer work to another module to actually
# prepare the XML messages - the actual content (or even being valid
# XML) is unimportant for this test.

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
