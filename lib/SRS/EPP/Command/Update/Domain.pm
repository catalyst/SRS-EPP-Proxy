package SRS::EPP::Command::Update::Domain;

use Moose;
extends 'SRS::EPP::Command::Update';
with 'SRS::EPP::Common::Domain::NameServers';

use MooseX::Method::Signatures;
use Crypt::Password;

use XML::SRS::Server;
use XML::SRS::Server::List;

# List of statuses the user is allowed to add or remove
my @ALLOWED_STATUSES = qw(clientHold);

my $allowed = {
	action => {
		add => 1,
		remove => 1,
	},
};

# for plugin system to connect
sub xmlns {
	return XML::EPP::Domain::Node::xmlns();
}

has 'state' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'EPP-DomainUpdate'
	);

has 'status_changes' => (
	'is' => 'rw',
	'isa' => 'HashRef',
	);

has 'contact_changes' => (
	'is' => 'rw',
	'isa' => 'HashRef',
	);

method error_response( Int :$code, Str :$message, Str :$value?, Str :$reason?) {
	my $exception;
	if ( defined $value or defined $reason ) {
		$exception = XML::EPP::Error->new(
			value => $value//"",
			reason => $reason,
		       );
	}

	return $self->make_response(
		Error => (
			code => $code,
			($exception ? (exception => $exception) : ()),
			($message ? (extra => $message) : ()),
		       ),
	       );
}

# we only ever enter here once, so we know what state we're in
method process( SRS::EPP::Session $session ) {
	$self->session($session);

	my $epp = $self->message;
	my $message = $epp->message;
	my $payload = $message->argument->payload;

	# firstly check that we have at least one of add, rem and chg
	unless ( $payload->add or $payload->remove or $payload->change ) {
		return $self->make_response(
			code => 2002,
		       );
	}

	# Validate that statuses supplied (if any)
	my %statuses = (
		($payload->add ? (add => $payload->add->status) : ()),
		($payload->remove ? (remove => $payload->remove->status) : ()),
	       );

	my %allowed_statuses = map { $_ => 1 } @ALLOWED_STATUSES;

	my %used;
	foreach my $key (keys %statuses) {
		foreach my $status (@{$statuses{$key}}) {
			unless ($allowed_statuses{$status->status}) {
				# They supplied a status that's not allowed
				return $self->error_response(
					code => 2307,
					value => $status->status,
					reason =>
			'Adding or removing this status is not allowed',
				       );
			}

			if ($used{$status->status}) {
				# They've added and removed the same
				# status. Throw an error
				return $self->error_response(
					code => 2002,
					value => $status->status,
					reason =>
				'Cannot add and remove the same status',
				       );
			}

			$used{$status->status} = 1;
		}
	}

	$self->status_changes(\%statuses);

	# In some cases, we need to do a DomainDetailsQry before the update
	my %ddq_fields;

	# if they want to add/remove a nameserver, then we need to hit the SRS
	# first to find out what they are currently set to
	if ( ( $payload->add and $payload->add->ns )
		     or ( $payload->remove and $payload->remove->ns ) ) {

		$ddq_fields{name_servers} = 1;
	}

	# If they've added or removed contacts, we also need to do a ddq
	#  to make sure they've added or removed the correct contacts
	if ($payload->add && $payload->add->contact
		    || $payload->remove && $payload->remove->contact) {

		my %contact_changes = ();

		for my $contact_type (qw/admin tech/) {
			for my $action (qw/add remove/) {
				my @contacts;
				@contacts = grep {
					$_->type eq $contact_type
				} @{$payload->$action->contact}
					if $payload->$action;

				$contact_changes{$contact_type}{$action}
					= \@contacts;
			}
		}

		$self->contact_changes(\%contact_changes);

		for my $contact_type (keys %contact_changes) {
			my %changes = %{$contact_changes{$contact_type}};

			next unless %changes;

			# Check they're not adding or removing more than
			# one contact of the same type
			for my $action (keys %changes) {
				if (scalar @{$changes{$action}} > 1) {
					return $self->error_response(
						code => 2306,
						value => '',
						reason =>
		"Only one $contact_type contact per domain supported",
					       );
				}
			}

			# The only valid actions are to remove, or add
			#  & remove.  An add on its own is invalid
			#  (because there's always a default) so
			#  reject it
			if (@{$changes{add}} && ! @{$changes{remove}}) {
				return $self->error_response(
					code => 2306,
					value => '',
					reason =>
		"Only one $contact_type contact per domain supported",
				       );
			}

			# We have some changes to this contact type,
			# so we need to request it in the ddq

			my $long_type = $contact_type eq 'tech'
				? 'technical' : $contact_type;

			$ddq_fields{$long_type . '_contact'} = 1;
		}
	}

	if (%ddq_fields) {

		# remember the fact that we're doing a domain details
		# query first
		$self->state('SRS-DomainDetailsQry');

		# need to do a DomainDetailsQry
		return XML::SRS::Domain::Query->new(
			domain_name_filter => $payload->name,
			field_list => XML::SRS::FieldList->new(
				\%ddq_fields,
			       ),
		       );
	}

	# ok, we have all the info we need, so create the request
	my $request = $self->make_request($message, $payload);
	$self->state('SRS-DomainUpdate');
	return $request;
}


method notify( SRS::EPP::SRSResponse @rs ) {

	# original payload
	my $epp = $self->message;
	my $message = $epp->message;
	my $payload = $message->argument->payload;

	# response from SRS (either a DomainDetailsQry or a DomainUpdate)
	my $res = $rs[0]->message->response;

	if ( $self->state eq 'SRS-DomainDetailsQry' ) {

		# Check if the contacts added or removed are correct
		if (my $cc = $self->contact_changes) {
			foreach my $contact_type (qw/admin tech/) {
				my $long_type = $contact_type eq 'tech'
					? 'technical' : $contact_type;
				my $method = 'contact_' . $long_type;
				my $existing_contact = $res->$method;

				my $contact_removed =
					$cc->{$contact_type}{remove}[0];

				# Throw an error if they're removing a
				# contact that doesn't exist
				if ($contact_removed &&
					(! $existing_contact ||
					   $existing_contact->handle_id
						   ne $contact_removed->value))
				{
					return $self->error_response(
						code => 2002,
						value =>
							$contact_removed->value,
						reason =>
"Attempting to remove $contact_type contact which does not exist on the domain",
					       );
				}

				# If they're adding a contact, but one
				# already exists (which hasn't been
				# removed), throw an error
				my $contact_added =
					$cc->{$contact_type}{add}[0];

				if ($contact_added && $existing_contact
					    && ! $contact_removed) {
					return $self->error_response(
						code => 2306,
						value  => '',
						reason =>
			"Only one $contact_type contact per domain supported",
					       );
				}
			}
		}

		my %ns;
		if ($res->nameservers) {
			foreach my $ns (@{$res->nameservers->nameservers} ) {
				$ns{$ns->fqdn} =
					$self->translate_ns_srs_to_epp($ns);
			}

			# check what the user wants to do (it's either
			# an add, rem or both) do the add first

			if ( $payload->add and $payload->add->ns ) {
				my $add_ns = $payload->add->ns->ns;

				# loop through and add them
				foreach my $ns ( @$add_ns ) {
					$ns{$ns->name} = $ns;
				}
			}

			# now do the remove
			if ( $payload->remove and $payload->remove->ns ) {
				my $rem_ns = $payload->remove->ns->ns;

				# loop through and remove them
				foreach my $ns ( @$rem_ns ) {
					delete $ns{$ns->name};
				}
			}
		}

		my @ns_list = values %ns;

		# so far all is good, now send the DomainUpdate
		# request to the SRS
		my $request = $self->make_request(
			$message, $payload, \@ns_list,
		       );
		$self->state('SRS-DomainUpdate');
		return $request;
	}
	elsif ( $self->state eq 'SRS-DomainUpdate' ) {

		# if we get no response, then it's likely the domain
		# name doesn't exist ie. the DomainNameFilter didn't
		# match anything

		unless ( defined $res ) {
			# Object does not exist
			return $self->make_response(
				code => 2303,
			       );
		}

		# everything looks ok, so let's return a successful message
		return $self->make_response(
			code => 1000,
		       );
	}
}

method make_request( $message, $payload, ArrayRef $new_nameservers? ) {

	# the first thing we're going to check for is a change to the
	# registrant
	my %contacts;
	if ( $payload->change ) {
		if ( my $registrant = $payload->change->registrant ) {
			# changing the registrant, so let's remember that
			$contacts{contact_registrant} =
				_make_contact($registrant);
		}
	}

	# Get the contacts (if any)
	for my $contact (qw/admin technical/) {
		my $contact_new = _extract_contact(
			$payload, 'add', $contact,
		       );
		my $contact_old = _extract_contact(
			$payload, 'remove', $contact,
		       );

		my $new_contact = _make_contact(
			$contact_new, $contact_old,
		       );

		$contacts{'contact_' . $contact} = $new_contact
			if defined $new_contact;
	}

	# now set the nameserver list
	my $ns_list;
	if ( defined $new_nameservers and @$new_nameservers ) {
		my @ns_objs = eval {
			$self->translate_ns_epp_to_srs(@$new_nameservers);
		};
		my $error = $@;
		if ($error) {
			return $error
				if $error->isa('SRS::EPP::Response::Error');
			die $error; # rethrow
		}
		$ns_list = XML::SRS::Server::List->new(
			nameservers => \@ns_objs,
		       );
	}

	my $request = XML::SRS::Domain::Update->new(
		filter => [ $payload->name() ],
		%contacts,
		( $ns_list ? ( nameservers => $ns_list ) : () ),
		action_id => $self->client_id || $self->server_id,
	       );

	# Do we need to set or clear Delegate flag?
	my $status_changes = $self->status_changes;
	if ($status_changes) {
		if ($status_changes->{add} &&
			    grep { $_->status eq 'clientHold' }
				    @{$status_changes->{add}}
			) {
			$request->delegate(0);
		}
		elsif ($status_changes->{remove} &&
			       grep { $_->status eq 'clientHold' }
				       @{$status_changes->{remove}} ) {
			$request->delegate(1);
		}
	}

	return $request;
}

sub _make_contact {
	my ($new, $old) = @_;

	# if we have a new contact, replace it (independent of $old)
	return XML::SRS::Contact->new( handle_id => $new )
		if $new;

	# return an empty contact element so that the handle gets deleted
	return XML::SRS::Contact->new()
		if $old;

	# if neither of the above, there is nothing to do
	return;
}

sub _extract_contact {
	my ($payload, $action, $type ) = @_;

	# check the input
	die q{Program error: '$action' should be 'add' or 'remove'}
		unless $allowed->{action}{$action};

	$type = 'tech' if $type eq 'technical';

	# check that action is there
	return unless $payload->$action;

	my $contacts = $payload->$action->contact;
	foreach my $c ( @$contacts ) {
		return $c->value if $c->type eq $type;
	}
	return;
}

1;
