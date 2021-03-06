package MT::Log::Log4perl::Appender::MT::Mail;

use Moo;
use 5.008_008;
use Try::Tiny;
use Carp qw( cluck confess );
use Sub::Quote qw( quote_sub );
use MT::Util;

use Log::Log4perl;
Log::Log4perl->wrapper_register(__PACKAGE__);

# Must be on one line so MakeMaker can parse it.
use Log4MT::Version;  our $VERSION = $Log4MT::Version::VERSION;

has 'app' => (
    is      => 'ro',
    isa     => quote_sub(q{
                      die 'Not an MT::App subclass'
                        unless Scalar::Util::blessed($_[0])
                            && $_[0]->isa('MT')
               }),
    lazy    => 1,
    builder => 1,
);

has 'from' => (
    is      => 'ro',
    isa     =>  quote_sub(q{
                    die "Invalid email"
                        unless $_[0] && MT::Util::is_valid_email($_[0]);
                }),
    lazy    => 1,
    builder => 1,
);

has 'content_type' => (
    is      => 'ro',
    isa     =>  quote_sub(q{
                    die 'Malformed content_type'
                        unless length($_[0]) and $_[0] =~ m/\w/
                }),
    lazy    => 1,
    builder => 1,
);

has 'default_recipient' => (
    is      => 'ro',
    isa     =>  quote_sub(q{
                    die "Invalid email"
                        unless $_[0] && MT::Util::is_valid_email($_[0]);
                }),
    lazy    => 1,
    builder => 1,
);

has 'default_sender' => (
    is      => 'ro',
    isa     =>  quote_sub(q{
                    die "Invalid email"
                        unless $_[0] && MT::Util::is_valid_email($_[0]);
                }),
    lazy    => 1,
    builder => 1,
);

sub _build_app {
    my $app = MT->instance if try { no warnings 'once'; ref $MT::mt_inst };
    unless ( $app ) {
        confess 'Log4MT attempted to send email via MT::Mail before '
              . 'MT was initialized ';
    }
    $app;
}

sub _build_from {
    my $self = shift;
    my $app  = $self->app;
    my $from = $self->default_sender || $app->config->EmailAddressMain;
    unless ( $from ) {
        my $msg = __PACKAGE__ . " failure: "
                . MT->translate('System Email Address is not configured.');
        $app->log({
            message  =>  $msg,
            level    => MT::Log::ERROR(),
            class    => 'system',
            category => 'email'
        });
        cluck $msg;
        return;
    }
    return $from;
}

sub _build_default_sender {
    try { Log::Log4perl->appender_by_name('MTMail')->{default_sender} }
}

sub _build_default_recipient {
    my $self = shift;
    try {
           Log::Log4perl->appender_by_name('MTMail')->{default_recipient}
        || $self->default_sender
    };
}

sub _build_content_type {
    my $self = shift;
    my $app  = $self->app;
    my $charset = $app->config->MailEncoding || $app->config->PublishCharset;
    return qq(text/plain; charset="$charset");
}

sub log {
    my ( $self, %params ) = @_;
    my $app     = $self->app;
    my $log     = { @{ $params{message} } };
    my $from    = $log->{from} || $self->from;
    my $to      = $log->{to} || $log->{To} || $self->default_recipient;
    my $body    = $log->{message};
    my $subject = defined($log->{subject})      ? $log->{subject}
                : defined($log->{Subject})      ? $log->{Subject}
                : defined($params{log4p_level}) ? $params{log4p_level} .': '.$params{log4p_category}
                                                : "Undefined...";
    warn "Sending from $from to $to";
    return unless $from && $to && $body && $subject;

    my $head = {
        'Content-Type' => $self->content_type,
        From           => $from,
        To             => $to,
        Subject        => $subject,
    };

    require MT::Mail;
    MT::Mail->send( $head, $body )
        or die MT::Mail->errstr();
    1;
}

1;
