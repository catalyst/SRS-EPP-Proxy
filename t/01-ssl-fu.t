#!/usr/bin/perl -w
#
# test script for SSL 'fu' - that we can work with all required SSL
# functionality

use strict;
use Test::More;

# - forge a series of connections, and using mocking demonstrate;
#   - ability to return information on client certificate presented,
#     such as the common name and/or fingerprint of the certificate
#   - ability to return facts about the SSL connection, such as the
#     SSL/TLS version, ciphers and length, etc.
#   - ability to verify and recognise certificates as valid and
#     invalid, using a single CA in the source tree
#   - ability to return the IP address from which the connection was
#     received.  Test IPv4 and IPv6

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
