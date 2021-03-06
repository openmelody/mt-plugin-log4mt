#!/usr/local/bin/perl
package Test::MT::Logger::Log4perl::useimport;

use 5.008_008;
use strict;
use warnings FATAL => 'all';

use Import::Into;

use Test::More;
use Test::Fatal;
use Package::Stash;
# use Carp::Always;

use MT::Logger::Log4perl  ();
use Log::Log4perl::Logger ();
use Log::Log4perl::Level  ();

our @export_tests = qw(
    easycarpers
    easyloggers
    get_logger
    levels
    no_extra_logdie_message
    nostrict
    nowarn
    resurrect
);

sub import {
    my $self     = shift;
    my $importer = caller;
    strict->import::into        ( $importer );
    warnings->import::into      ( $importer, FATAL => 'all' );
    feature->import::into       ( $importer, qw( :5.10 ) );
    Test::More->import::into    ( $importer );
    Test::Fatal->import::into   ( $importer );
}

sub no_use_exception { is(   $_[1], undef, 'No exception on use'      ) }
sub    use_exception { isnt( $_[1], undef, 'Exception thrown in use!' ) }


sub has (@) {
    my $self      = shift;
    my @tests     = @_;
    my %tests_run = map { $_ => 0 } @export_tests;

    foreach my $e ( @tests ) {
        my $test = "test_$e";
        ok( $self->$test, "has $test" );
            # || fail( "bailing out of has after $test" );
        $tests_run{$e} = 1;
    }
    return $self->hasnt( grep { ! $tests_run{$_} } keys %tests_run );
}


sub hasnt (@) {
    my $self  = shift;
    my @tests = @_;

    foreach my $test ( map { "test_$_" } @tests ) {
        my $res = $self->$test();
        unless ( ok( ! $res, "hasnt $test" ) ) {
            warn "$test failed. Bailing out of hasnt loop";
            return 0;
        }
    }
    return 1;
}

sub package_has($$;$) {
    my ( $pkg, $var, $expect ) = @_;

    my $stash = Package::Stash->new($pkg)
        or die "Could not get stash of $pkg";

    return $stash->has_symbol($var)
        && defined( $stash->get_symbol($var) ) ? 1 : 0;
}

sub test_levels {
    my $pkg = shift;
    my $cnt = 0;
    foreach my $level ( keys %Log::Log4perl::Level::PRIORITY ) {
        my $ok = $pkg->package_has( '$'.$level,
                        $Log::Log4perl::Level::PRIORITY{$level});
        $cnt++ if $ok;
    }
    return ( $cnt == scalar keys %Log::Log4perl::Level::PRIORITY );
}

sub test_get_logger { shift->package_has( "\&get_logger" ) }

sub test_easyloggers {
    my $pkg    = shift;
    my $cnt    = 0;
    my @levels = qw(TRACE DEBUG INFO WARN ERROR FATAL ALWAYS);
    foreach my $level ( @levels ) {
        my $ok = $pkg->package_has( '&'.$level );
        $cnt++ if $ok;
    }
    return ( $cnt == @levels );
}

sub test_easycarpers {
    my $pkg = shift;
    my $cnt = 0;
    my @levels = qw( LOGCROAK LOGCLUCK LOGCARP LOGCONFESS LOGDIE LOGEXIT LOGWARN);
    foreach my $level ( @levels ) {
        my $ok = $pkg->package_has( '&'.$level );
        $cnt++ if $ok;
    }
    return ( $cnt == @levels );
}

sub test_nowarn         {
    require Log::Log4perl::Logger;
    ($Log::Log4perl::Logger::NON_INIT_WARNED || 0) == 1
}

sub test_nostrict       {
    require Log::Log4perl::Logger;
    ($Log::Log4perl::Logger::NO_STRICT || 0)       == 1
}

sub test_no_extra_logdie_message {
    require Log::Log4perl;
    $Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR       == 0
}

sub test_resurrect      { return shift->is_resurrected }

1;

__END__

