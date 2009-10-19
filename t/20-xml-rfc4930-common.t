#!/usr/bin/perl -w
#
# test script for validation and load/dump between Perl/Moose and XML
# for complete messages and fragments described in RFC4930 (EPP and
# EPP common)

use strict;
use Test::More;

# of particular note: these stateful EPP messages are never converted
# to the stateless SRS protocol; so they will not be covered by later
# tests and tests must be particularly thorough.

#    - Hello / Greeting
#    - logout

plan "no_plan";

# for now, we test stub modules


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
