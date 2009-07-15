#!/usr/bin/perl -w
#
# test script for XML schema handling
#

use strict;
use Test::More;

# - test XML validation infrastructure requirements:

#   - for each test schema;
#     - load the schema file (probably in relax-format)
#     - validate a series of test documents against it; including pass
#       and fail cases

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
