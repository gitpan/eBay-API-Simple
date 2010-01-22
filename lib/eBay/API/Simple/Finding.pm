package eBay::API::Simple::Finding;

use strict;
use warnings;

use base 'eBay::API::SimpleBase';

use HTTP::Request;
use HTTP::Headers;
use XML::Simple;

our $DEBUG = 0;

=head1 NAME

eBay::API::Simple::Finding

=head1 SYNPOSIS

  my $call = eBay::API::Simple::Finding->new( 
    { appid => '<your app id here>' } 
  );
  $call->execute( 'findItemsByKeywords', { keywords => 'shoe' } );

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
  
=head1 new 

Constructor for the Shopping API call

  my $call = eBay::API::Simple::Finding->new( 
    { appid => '<your app id here>' } 
  );
 
  my $call = eBay::API::Simple::Finding->new( {
    siteid  => 'EBAY-US',       # custom site id 
    domain  => 'svcs.ebay.com', # custom domain
    uri     => '/services/search/FindingService/v1',  # custom uri 
    appid   => '<your appid>',    # custom appid
    version => '1.0.0',      # custom version
    https   => 0,            # 0 or 1
  } );
    
=head2 ebay.ini

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
    $self->api_config->{uri}     ||= '/services/search/FindingService/v1';
    $self->api_config->{version} ||= '1.0.0';
    $self->api_config->{https}   ||= 0;
    $self->api_config->{siteid}  ||= 'EBAY-US';
    $self->api_config->{response_encoding} ||= 'XML'; # JSON, NV, SOAP
    $self->api_config->{request_encoding}  ||= 'XML';

    $self->_load_credentials();
    
    return $self;    
}

=head1 _get_request_body

This method supplies the request body for the Shopping API call

=cut

sub _get_request_body {
    my $self = shift;

    my $xml = "<?xml version='1.0' encoding='utf-8'?>"
        . "<" . $self->{verb} . "Request xmlns=\"http://www.ebay.com/marketplace/search/v1/services\">"
        . XMLout( $self->{call_data}, NoAttr => 1, KeepRoot => 1, RootName => undef )
        . "</" . $self->{verb} . "Request>";

    return $xml; 
}

=head1 _get_request_headers 

This method supplies the headers for the Shopping API call

=cut

sub _get_request_headers {
    my $self = shift;
   
    my $obj = HTTP::Headers->new();

    $obj->push_header("X-EBAY-SOA-SERVICE-VERSION" => $self->api_config->{version});
    $obj->push_header("X-EBAY-SOA-SECURITY-APPNAME"  => $self->api_config->{appid});
    $obj->push_header("X-EBAY-SOA-GLOBAL-ID"  => $self->api_config->{siteid});
    $obj->push_header("X-EBAY-SOA-OPERATION-NAME" => $self->{verb});
    $obj->push_header("X-EBAY-SOA-REQUEST-DATA-FORMAT"  => $self->api_config->{request_encoding});
    $obj->push_header("X-EBAY-SOA-RESPONSE-DATA-FORMAT" => $self->api_config->{response_encoding});
    $obj->push_header("Content-Type" => "text/xml");
    
    return $obj;
}

=head1 execute( $verb, $call_data )
 
Calling this method will make build and execute the api request.
  
  $verb      = call verb, i.e. FindItems 
  $call_data = hashref of call_data that will be turned into xml.

  $call->execute( 'findItemsByKeywords', { keywords => 'shoe' } );

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

    # remove xmlns 
    $self->{response_content}  =~ s/xmlns=["'][^"']+["']//;

    if ( $DEBUG ) {
        require Data::Dumper;
        print STDERR $self->{response_content};
    }

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
