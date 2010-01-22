package eBay::API::Simple::Trading;

use strict;
use warnings;

use base 'eBay::API::SimpleBase';

use HTTP::Request;
use HTTP::Headers;
use XML::Simple;

our $DEBUG = 0;

=head1 NAME

eBay::API::Simple::Trading

=head1 SYNPOSIS

  my $call = eBay::API::Simple::Trading->new();
  $call->execute( 'GetSearchResults', { Query => 'shoe' } );

  if ( $call->has_error() ) {
     die "Call Failed:" . $call->errors_as_string();
  }

  # getters for the response DOM or Hash
  my $dom  = $call->response_dom();
  my $hash = $call->response_hash();

  print $call->nodeContent( 'Timestamp' );

  my @nodes = $dom->findnodes(
    '//Item'
  );

  foreach my $n ( @nodes ) {
    print $n->findvalue('Title/text()') . "\n";
  }

=head1 new

Constructor for the Trading API call

  my $call = ebay::API::Simple::Trading->new();
  $call->execute( 'GetSearchResults', { Query => 'shoe' } );

  my $call = ebay::API::Simple::Trading->new( {
    siteid  => 0,              # custom site id
    uri     => '/ws/api.dll',  # custom uri
    appid   => 'myappid',
    devid   => 'mydevid',
    certid  => 'mycertid',
    version => '518',     # custom version
    https   => 1,         # 0 or 1
    domain  => 'open.api.ebay.com' # custom domain
  } );

Defaults:

  siteid  = 0
  uri     = /ws/api.dll
  domain  = open.api.ebay.com
  version = 543
  https   = 1

  devid   = undef
  appid   = undef
  certid  = undef
  token   = undef

=head2 ebay.ini

The constructor will fallback to the ebay.ini file to get any missing
credentials. The following files will be checked, ./ebay.ini, ~/ebay.ini,
/etc/ebay.ini which are in the order of precedence.

 # your developer key
 DeveloperKey=KLJHAKLJHLKJHLKJH

 # your application key
 ApplicationKey=LJKGHKLJGKJHG

 # your certificate key
 CertificateKey=SUYTYWTKWTYIUYTWIUTY

 # your token (a very BIG string)
 Token=JKHGHJGJHGKJHGKJHGkluhsdihdsriuhfwe87yr8wehIEWH9O78YWERF90HF9UHJESIPHJFV94Y4089734Y

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    return $self;
}

=head1 execute( $verb, $call_data )

Calling this method will make build and execute the api request.

  $verb      = call verb, i.e. GetSearchResults
  $call_data = hashref of call_data that will be turned into xml.

  $call->execute( 'GetSearchResults', { Query => 'shoe' } );

=cut

sub execute {
    my $self = shift;

    $self->{verb}      = shift;
    $self->{call_data} = shift;

    if ( ! defined $self->{verb} || ! defined $self->{call_data} ) {
        die "missing verb and call_data";
    }

    # make sure we have appid, devid, certid, token
    $self->_load_credentials();

    $self->{response_content} = $self->_execute_http_request();

    # remove xmlns
    $self->{response_content}  =~ s/xmlns=["'][^"']+"//;

    if ( $DEBUG ) {
        print STDERR $self->request_object->as_string();
        print STDERR $self->response_object->as_string();
    }

}

=head1 _validate_response

This is called from the base class. The method is suppose to provide the
custom validation code and push to the error stack if the response isn't
valid

=cut

sub _validate_response {
    my $self = shift;

    if ( $self->nodeContent('Ack') eq 'Failure' ) {
        $self->errors_append( {
            'Call Failure' => $self->nodeContent('LongMessage')
        } );
    }
}

=head1 _get_request_body

This method supplies the request body for the Shopping API call

=cut

sub _get_request_body {
    my $self = shift;

    # if auth_method is set to 'token' use AuthToken
    # else use username/password
    if ( $self->{auth_method} eq 'token' ) {
         my $xml = "<?xml version='1.0' encoding='utf-8'?>"
             . "<" . $self->{verb} . "Request xmlns=\"urn:ebay:apis:eBLBaseComponents\">"
             . "<RequesterCredentials><eBayAuthToken>"
             . $self->api_config->{token} . "</eBayAuthToken></RequesterCredentials>"
             . XMLout( $self->{call_data}, NoAttr => 1, KeepRoot => 1, RootName => undef )
             . "</" . $self->{verb} . "Request>";

          return $xml;
    }
    else {
         my $xml = "<?xml version='1.0' encoding='utf-8'?>"
             . "<" . $self->{verb} . "Request xmlns=\"urn:ebay:apis:eBLBaseComponents\">"
             . "<RequesterCredentials><Username>"
             . $self->api_config->{username} . "</Username><Password>"
             . $self->api_config->{password} . "</Password></RequesterCredentials>"
             . XMLout( $self->{call_data}, NoAttr => 1, KeepRoot => 1, RootName => undef )
             . "</" . $self->{verb} . "Request>";

         return $xml;
    }
}

=head1 _get_request_headers

This method supplies the headers for the Shopping API call

=cut

sub _get_request_headers {
    my $self = shift;

    my $obj = HTTP::Headers->new();

    $obj->push_header("X-EBAY-API-COMPATIBILITY-LEVEL" =>
        $self->api_config->{version});
    $obj->push_header("X-EBAY-API-DEV-NAME"  => $self->api_config->{devid});
    $obj->push_header("X-EBAY-API-APP-NAME"  => $self->api_config->{appid});
    $obj->push_header("X-EBAY-API-CERT-NAME"  => $self->api_config->{certid});
    $obj->push_header("X-EBAY-API-SITEID"  => $self->api_config->{siteid});
    $obj->push_header("X-EBAY-API-CALL-NAME" => $self->{verb});
    $obj->push_header("Content-Type" => "text/xml");

    return $obj;
}

=head1 _get_request_object

This method creates the request object and returns to the parent class

=cut

sub _get_request_object {
    my $self = shift;

    my $url = sprintf( 'http%s://%s%s',
        ( $self->api_config->{https} ? 's' : '' ),
        $self->api_config->{domain},
        $self->api_config->{uri}
    );
    my $request_obj = HTTP::Request->new(
        "POST",
        $url,
        $self->_get_request_headers,
        $self->_get_request_body
    );

    return $request_obj;
}

sub _load_credentials {
    my $self = shift;

    # we only need to load credentials once
    return if $self->{_credentials_loaded};

    my @missing;

    # required by the API
    for my $reqd ( qw/devid appid certid/ ) {
        next if defined $self->api_config->{$reqd};

        if ( defined (my $val = $self->_fish_ebay_ini( $reqd )) ) {
            $self->api_config->{$reqd} = $val;
        }
        else {
            push( @missing, $reqd );
        }
    }

    if ( scalar @missing > 0 ) {
        die "missing Authentication: " . join( ", ", @missing );
    }

    # Collect Token, username, password, domain, https, uri and version from
    # the ebay.ini file
    # if token found, set auth_method to 'token'
    # if username/password found set auth_method to 'user'

    for my $optional ( qw/token username password domain https uri version/ ) {

       next if defined $self->api_config->{$optional};

       if ( defined ( my $val = $self->_fish_ebay_ini( $optional )) ) {
           $self->api_config->{$optional} = $val;
       }
       else {
           print "Not defined : " . $optional . "\n" if $DEBUG;
       }
    }

    if ( exists ( $self->api_config->{token} ) ) {
        $self->{auth_method} = 'token';

        delete($self->api_config->{username});
        delete($self->api_config->{password});

    }
    elsif ((exists( $self->api_config->{username} ))
        && (exists( $self->api_config->{password} ))) {

        $self->{auth_method} = 'user';

    }
    else {
        die "missing Authentication : token or username/password \n";
    }

    # setting defaults
    unless ( defined $self->api_config->{domain} ) {
        $self->api_config->{domain} = 'open.api.ebay.com'; # api.sandbox.ebay.com
    }

    unless ( defined $self->api_config->{uri} ) {
        $self->api_config->{uri} = '/ws/api.dll';
    }

    unless ( defined $self->api_config->{https} ) {
        $self->api_config->{https} = 1;
        print "since undefined https value is now: "
            . $self->api_config->{https} . "\n" if $DEBUG;
    }

    unless ( defined $self->api_config->{siteid} ) {
        $self->api_config->{siteid} = 0;
    }

    unless (defined $self->api_config->{version} ) {
         $self->api_config->{version} = '543';
    }

    $self->{_credentials_loaded} = 1;
    return;
}

sub _fish_ebay_ini {
    my $self = shift;
    my $arg  = shift;
    my @files;

    # initialize our hashref
    $self->{_ebay_ini} ||= {};

    # revert eBay::API::Simple keys to standard keys
    $arg = 'DeveloperKey'    if $arg eq 'devid';
    $arg = 'ApplicationKey' if $arg eq 'appid';
    $arg = 'CertificateKey' if $arg eq 'certid';
    $arg = 'Token'          if $arg eq 'token';
    $arg = 'UserName'       if $arg eq 'username';
    $arg = 'Password'       if $arg eq 'password';
    $arg = 'Domain'         if $arg eq 'domain';
    $arg = 'Https'          if $arg eq 'https';
    $arg = 'Uri'            if $arg eq 'uri';
    $arg = 'Version'        if $arg eq 'version';

    # return it if we've already found it
    return $self->{_ebay_ini}{$arg} if defined $self->{_ebay_ini}{$arg};

    # ini files in order of importance

    # Make exception for windows
    if ( $^O eq 'MSWin32' ) {
        @files = ( './ebay.ini', );
    }
    else {
          @files = (
             './ebay.ini',
             "$ENV{HOME}/ebay.ini",
             '/etc/ebay.ini',
         );
    }

    foreach my $file ( reverse @files ) {
        if ( open( FILE, "<", $file ) ) {
            while ( my $line = <FILE> ) {
                chomp( $line );

                next if $line =~ m!^\s*\#!;

                my( $k, $v ) = split( /=/, $line );

                if ( defined $k && defined $v) {
                    $v =~ s/^\s+//;
                    $v =~ s/\s+$//;

                    $self->{_ebay_ini}{$k} = $v;
           
                }
            }
            close FILE;
        }
    }
    return $self->{_ebay_ini}{$arg} if defined $self->{_ebay_ini}{$arg};
    return undef;

}

1;

=head1 AUTHOR

Tim Keefer <tim@timkeefer.com>

=head2 CONTRIBUTOR

Jyothi Krishnan

=cut
