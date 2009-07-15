#!/usr/bin/perl -w
#
# test script for the server base class - SSL connections and
# handshake logic

use strict;
use Test::More;

# - test a basic RFC4934 session flow:
#   - connect
#   - receive and validate greeting
#   - send <login> message
#   - server sends response
#   - (optional) send a dummy command and check response (mocked)
#   - send <logout> message
#   - check logout response, wait for remote disconnect

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
