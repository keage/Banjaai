package Banjaai;
use strict;
use warnings;
use utf8;
our $VERSION='0.01';
use 5.008001;
use Banjaai::DB::Schema;
use Banjaai::DB;

use parent qw/Amon2/;
# Enable project local mode.
__PACKAGE__->make_local_context();

my $schema = Banjaai::DB::Schema->instance;

sub db {
    my $c = shift;
    if (!exists $c->{db}) {
        my $conf = $c->config->{DBI}
            or die "Missing configuration about DBI";
        $c->{db} = Banjaai::DB->new(
            schema       => $schema,
            connect_info => [@$conf],
            # I suggest to enable following lines if you are using mysql.
            # on_connect_do => [
            #     'SET SESSION sql_mode=STRICT_TRANS_TABLES;',
            # ],
        );
    }
    $c->{db};
}

1;
__END__

=head1 NAME

Banjaai - Banjaai

=head1 DESCRIPTION

This is a main context class for Banjaai

=head1 AUTHOR

Banjaai authors.

