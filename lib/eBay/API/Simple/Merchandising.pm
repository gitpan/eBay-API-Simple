package eBay::API::Simple::Merchandising;

use strict;
use warnings;

use base 'eBay::API::SimpleBase';

use HTTP::Request;
use HTTP::Headers;
use XML::Simple;

our $DEBUG = 0;

=head1 NAME

eBay::API::Simple::Merchandising - Support for eBay's Merchandising web service

=head1 DESCRIPTION

This class provides support for eBay's Merchandising web services.

See http://developer.ebay.com/products/merchandising/

=head1 USAGE

  my $call = eBay::API::Simple::Merchandising->new( 
    { appid => '<your app id here>' } 
  );
  
  $call->execute( 'getMostWatchedItems', { maxResults => 3, categoryId => 267 }  );

  if ( $call->has_error() ) {
     die "Call Failed:" . $call->errors_as_string();
  }

  # getters for the response DOM or Hash
  my $dom  = $call->response_dom();
  my $hash = $call->response_hash();

  print $call->nodeContent( 'timestamp' );
  print $call->nodeContent( 'totalEntries' );

  my @nodes = $dom->findnodes(
    '//item'
  );

  foreach my $n ( @nodes ) {
    print $n->findvalue('title/text()') . "\n";
  }

=head1 SANDBOX USAGE

  my $call = eBay::API::Simple::Merchandising->new( { 
     appid => '<your app id here>' 
     domain => '',
  } );
  
  $call->execute( 'getMostWatchedItems', { maxResults => 3, categoryId => 267 }  );

  if ( $call->has_error() ) {
     die "Call Failed:" . $call->errors_as_string();
  }

  # getters for the response DOM or Hash
  my $dom  = $call->response_dom();
  my $hash = $call->response_hash();
  
=head1 PUBLIC METHODS

=head2 new( { %options } } 

Constructor for the Finding API call

  my $call = eBay::API::Simple::Merchandising->new( { 
    appid => '<your app id here>' 
    ... 
  } );

=head3 Options

=over 4

=item appid (required)

This appid is required by the web service. App ids can be obtained at 
http://developer.ebay.com

=item siteid

eBay site id to be supplied to the web service endpoint

defaults to EBAY-US

=item domain

domain for the web service endpoint

defaults to svcs.ebay.com

=item uri

endpoint URI

defaults to /MerchandisingService

=item version

Version to be supplied to the web service endpoint

defaults to 1.0.0

=item https

Specifies is the API calls should be made over https.

defaults to 0

=back

=head3 ALTERNATE CONFIG VIA ebay.ini

The constructor will fallback to the ebay.ini file to get any missing 
credentials. The following files will be checked, ./ebay.ini, ~/ebay.ini, 
/etc/ebay.ini which are in the order of precedence.

  # your application key
  ApplicationKey=LJKGHKLJGKJHG

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->api_config->{domain}  ||= 'svcs.ebay.com';
    $self->api_config->{uri}     ||= '/MerchandisingService';
    #$self->api_config->{version} ||= '1.1.0';
    $self->api_config->{https}   ||= 0;
    $self->api_config->{siteid}  ||= 'EBAY-US';
    $self->api_config->{response_encoding} ||= 'XML'; # JSON, NV, SOAP
    $self->api_config->{request_encoding}  ||= 'XML';

    $self->_load_credentials();
    
    return $self;    
}

=head2 execute( $verb, $call_data )

  $self->execute( 'getMostWatchedItems', { maxResults => 3, categoryId => 267 } );
 
This method will construct the API request based on the $verb and
the $call_data and then post the request to the web service endpoint. 

=item $verb (required)

call verb, i.e. getMostWatchedItems

=item $call_data (required)

hashref of call_data that will be turned into xml.

=cut

sub execute {
    my $self = shift;
    
    $self->{verb}      = shift;
    $self->{call_data} = shift;

    if ( ! defined $self->{verb} || ! defined $self->{call_data} ) {
        die "missing verb and call_data";
    }
    
    # make sure we have appid
    $self->_load_credentials();
    
    $self->{response_content} = $self->_execute_http_request();

    if ( $DEBUG ) {
        require Data::Dumper;
        print STDERR $self->{response_content};
    }

}

=head1 BASECLASS METHODS

=head2 request_agent

Accessor for the LWP::UserAgent request agent

=head2 request_object

Accessor for the HTTP::Request request object

=head2 request_content

Accessor for the complete request body from the HTTP::Request object

=head2 response_content

Accessor for the HTTP response body content

=head2 response_object

Accessor for the HTTP::Request response object

=head2 response_dom

Accessor for the LibXML response DOM

=head2 response_hash

Accessor for the hashified response content

=head2 nodeContent( $tag, [ $dom ] ) 

Helper for LibXML that retrieves node content

=head2 errors 

Accessor to the hashref of errors

=head2 has_error

Returns true if the call contains errors

=head2 errors_as_string

Returns a string of API errors if there are any.

=head1 PRIVATE METHODS

=head2 _get_request_body

This method supplies the XML body for the web service request

=cut

sub _get_request_body {
    my $self = shift;

    my $xml = "<?xml version='1.0' encoding='utf-8'?>"
        . "<" . $self->{verb} . "Request xmlns=\"http://www.ebay.com/marketplace/services\">"
        . XMLout( $self->{call_data}, NoAttr => 1, KeepRoot => 1, RootName => undef )
        . "</" . $self->{verb} . "Request>";

    return $xml; 
}

=head2 _get_request_headers 

This method supplies the HTTP::Headers obj for the web service request

=cut

sub _get_request_headers {
    my $self = shift;
   
    my $obj = HTTP::Headers->new();

    if ( defined $self->api_config->{version} ) {
        $obj->push_header("X-EBAY-SOA-SERVICE-VERSION" 
            => $self->api_config->{version});
    }
    $obj->push_header("X-EBAY-SOA-SERVICE-NAME" => "MerchandisingService" );
    $obj->push_header("EBAY-SOA-CONSUMER-ID"  => $self->api_config->{appid});
    $obj->push_header("X-EBAY-SOA-GLOBAL-ID"  => $self->api_config->{siteid});
    $obj->push_header("X-EBAY-SOA-OPERATION-NAME" => $self->{verb});
    $obj->push_header("X-EBAY-SOA-REQUEST-DATA-FORMAT"  
        => $self->api_config->{request_encoding});
    $obj->push_header("X-EBAY-SOA-RESPONSE-DATA-FORMAT" 
        => $self->api_config->{response_encoding});
    $obj->push_header("Content-Type" => "text/xml");
    
    return $obj;
}

=head2 _get_request_object 

This method creates and returns the HTTP::Request object for the
web service call.

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
    for my $p ( qw/appid/ ) {
        next if defined $self->api_config->{$p};
        
        if ( my $val = $self->_fish_ebay_ini( $p ) ) {
            $self->api_config->{$p} = $val;
        }
        else {
            push( @missing, $p );
        }
    }

    # die if we didn't get everything
    if ( scalar @missing > 0 ) {
        die "missing API credential: " . join( ", ", @missing );
    }
    
    $self->{_credentials_loaded} = 1;
    return;
}

sub _fish_ebay_ini {
    my $self = shift;
    my $arg  = shift;

    # initialize our hashref
    $self->{_ebay_ini} ||= {};
    
    # revert eBay::API::Simple keys to standard keys
    $arg = 'ApplicationKey' if $arg eq 'appid';

    # return it if we've already found it
    return $self->{_ebay_ini}{$arg} if defined $self->{_ebay_ini}{$arg};
    
    # ini files in order of importance
    my @files = (
        './ebay.ini',           
        "$ENV{HOME}/ebay.ini",
        '/etc/ebay.ini',
    );
    
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

=head1 AUTHOR

Tim Keefer <tim@timkeefer.com>

=cut

1;
