
package SRS::EPP::Packets;

# encapsulate the packetization part of RFC3734
use Moose;
use MooseX::Method::Signatures;

has input_state =>
	is => "rw",
	default => "expect_length",
	;

has input_buffer =>
	is => "ro",
	default => sub { [] },
	;

use bytes;

method input_buffer_size() {
	my $size = 0;
	for ( @{ $self->input_buffer } ) {
		$size += length $_;
	}
	$size;
}

method input_buffer_read( Int $size where { $_ > 0 }  ) {
	my $buffer = $self->input_buffer;
	my @rv;
	while ( $size and @$buffer ) {
		my $chunk = shift @$buffer;
		if ( length $chunk > $size ) {
			push @rv, substr $chunk, 0, $size;
			unshift @$buffer, substr $chunk, $size;
			last;
		}
		else {
			push @rv, $chunk;
			$size -= length $chunk;
		}
	}
	join "", @rv;
}

has 'input_expect' =>
	is => "rw",
	isa => "Int",
	default => 4,
	;

has 'session' =>
	handles => [qw(input_packet read_input)],
	;

method input_event( Str $data? ) {
	if ( defined $data and $data ne "") {
		push @{ $self->input_buffer }, $data;
	}

	my $ready = $self->input_buffer_size;
	my $expected = $self->input_expect;

	if ( !defined $data ) {
		$data = $self->read_input($expected - $ready);
		push @{ $self->input_buffer }, $data;
	}

	my $got_chunk;

	while ( $self->input_buffer_size >= $expected ) {
		my $data = $expected
			? $self->input_buffer_read($expected)
			: "";
		if ( $self->input_state eq "expect_length" ) {
			$self->input_state("expect_data");
			$self->input_expect(unpack("N", $data)-4);
		}
		else {
			$self->input_state("expect_length");
			$self->input_packet($data);
			$self->input_expect(4);
		}
		$expected = $self->input_expect;
		$got_chunk = 1;
	}

	return $got_chunk;
}

1;

__END__
