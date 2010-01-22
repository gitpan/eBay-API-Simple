package eBay::API::SimpleBase;

use strict;
use warnings;

use XML::LibXML;
use XML::Simple;
use HTTP::Request;
use HTTP::Headers;
use LWP::UserAgent;
use XML::Parser;

# set the preferred xml simple parser
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

our $DEBUG = 0;

=head1 NAME 

eBay::API::Simple - Simple version of the eBay API supporting all APIs

=head1 DESCRIPTION

This is the base class for the eBay::API::Simple::* libraries. 

L<eBay::API::Simple::Finding>
L<eBay::API::Simple::Shopping>
L<eBay::API::Simple::Trading>
L<eBay::API::Simple::HTML>
L<eBay::API::Simple::RSS>

=head1 SOURCE

http://code.google.com/p/ebay-api-simple

=head1 METHODS

=head2 eBay::API::Simple::{subclass}->new()

see subclass for more docs.

=cut

sub new {
    my $class    = shift;
    my $api_args = shift;

    my $self = {};  
    bless( $self, $class );
    
    # set some defaults 
    $self->api_config->{siteid}  = 0;
    $self->api_config->{timeout} = 20 unless defined $api_args->{timeout};

    # set the config args 
    $self->api_config_append( $api_args );
    
    return $self;   
}

=head1 execute( $verb, $call_data )

** This method should be supplied by the subclass. This one
is only here to provide an example. See actual subclass for docs.

Calling this method will make build and execute the api request.
  
required:
    $verb      = call verb, i.e. FindItems 
    $call_data = hashref of call_data that will be turned
                 into xml.
=cut

sub execute {
    my $self = shift;
    
    $self->{verb}      = shift;
    $self->{call_data} = shift;
    
    if ( ! defined $self->{verb} || ! defined $self->{call_data} ) {
        die "missing verb and call_data";
    }
       
    $self->{response_content} = $self->_execute_http_request();

    # remove xmlns 
    $self->{response_content}  = s/xmlns=["'][^"']+//;

    if ( $DEBUG ) {
        require Data::Dumper;
        print STDERR $self->{response_content};
    }

}

=head1 response_content

Accessor for the HTTP response body content

=cut

sub response_content {
    my $self = shift;
    return $self->{response_content};
}

=head1 request_agent

Accessor for the HTTP request agent

=cut

sub request_agent {
    my $self = shift;
    return $self->{request_agent};
}

=head1 request_object

Accessor for the HTTP request object

=cut

sub request_object {
    my $self = shift;
    return $self->{request_object};
} 

=head1 request_content

Accessor for the HTTP request body content

=cut

sub request_content {
    my $self = shift;
    return $self->{request_object}->as_string();
} 

=head1 response_object

Accessor for the HTTP response body content

=cut

sub response_object {
    my $self = shift;
    return $self->{response_object};
}

=head1 response_dom

Accessor for the LibXML response DOM

=cut

sub response_dom {
    my $self = shift;

    if ( ! defined $self->{response_dom} ) {
        my $parser = XML::LibXML->new();    
        eval {
            $self->{response_dom} = 
                $parser->parse_string( $self->response_content );
        };
        if ( $@ ) {
            $self->errors_append( { 'parsing_error' => $@ } );
        }

    }

    return $self->{response_dom};
}

=head1 response_hash

Accessor for the hashified response content

=cut

sub response_hash {
    my $self = shift;

    if ( ! defined $self->{response_hash} ) {
        $self->{response_hash} = XMLin( $self->response_content,
            forcearray => [],
            keyattr    => []
        );
    }

    return $self->{response_hash};
}

=head1 response_json

Not implemented yet.

=cut

sub response_json {
    my $self = shift;

    if ( ! defined $self->{response_json} ) {
        $self->{response_json} = ''; # xml2json( $self->{response_content} );
    }

    return $self->{response_json};
}

=head1 api_config

Accessor to a hashref of api config data that will be used to execute
the api call.

  siteid,domain,uri,etc.

=cut

sub api_config {
    my $self = shift;
    $self->{api_config} = {} unless defined $self->{api_config};
    return $self->{api_config};
}

=head1 api_config_append( $hashref )

This method is used to merge config into the config_api hash

=cut

sub api_config_append {
    my $self = shift;
    my $config_hash = shift;

    for my $k ( keys %{ $config_hash } ) {
        $self->api_config->{$k} = $config_hash->{$k};
    }
}

=head1 errors 

Accessor to the hashref of errors

=cut

sub errors {
    my $self = shift;
    $self->{errors} = {} unless defined $self->{errors};
    return $self->{errors};
}

=head1 has_error

Returns true if the call contains errors

=cut

sub has_error {
    my $self = shift;
    my $has_error =  (keys( %{ $self->errors } ) > 0) ? 1 : 0;
    return $has_error;
}

=head1 errors_append

This method lets you append errors to the errors stack

=cut

sub errors_append {
    my $self = shift;
    my $hashref = shift;

    for my $k ( keys %{ $hashref } ) {
        $self->errors->{$k} = $hashref->{$k};
    }

}

=head1 errors_as_string

Returns a string of API errors if there are any.

=cut

sub errors_as_string {
    my $self = shift;

    my @e;
    for my $k ( keys %{ $self->errors } ) {
        push( @e, $k . '-' . $self->errors->{$k} );
    }
    
    return join( "\n", @e );
}

=head1 nodeContent( $tag, [ $dom ] ) 

Helper for LibXML that retrieves node content

optionally a DOM object can be passed in. If no DOM object 
is passed then the main response DOM object is used.

=cut
 
sub nodeContent {
    my $self = shift;
    my $tag  = shift;
    my $node = shift;

    $node ||= $self->response_dom();

    return if ! $tag || ! $node;

    my $e = $node->getElementsByTagName($tag);
    if ( defined $e->[0] ) {
        return $e->[0]->textContent();

    }
    else { 
        #print STDERR "no info for $tag\n";
        return;
    }
}

=head1 _execute_http_request

This method performs the http request and should be used by 
each subclass.

=cut

sub _execute_http_request {
    my $self = shift;

    # clear previous call data
    $self->_reset();
 
    unless ( defined $self->{request_agent} ) {
        $self->{request_agent} = $self->_get_request_agent();
    }

    unless ( defined $self->{request_object} ) {
        $self->{request_object} = $self->_get_request_object();
    }

    my $max_tries = 1;
    
    if ( defined $self->api_config->{retry} ) {
        $max_tries =  $self->api_config->{retry} + 1;
    }

    my $content = '';
    my $error   = '';

    for ( my $i=0; $i < $max_tries; ++$i ) {

        my $response = $self->{request_agent}->request( $self->{request_object} );
        $self->{response_object} = $response;

        if ( $response->is_success ) {
            $content   = $response->content();
            $self->{response_content} = $content;
            $error     = undef;
            
            # call the classes validate response method if it exists
            $self->_validate_response() if $self->can('_validate_response');
            
            last; # exit the loop
        }
        
        # store the error 
        $error   = $response->status_line;
        $content = $response->content();
    }
  
    $self->errors_append( { http_response => $error } ) if defined $error;     
  
    $self->{response_content} = $content;
    return $content;
}

=head1 _reset

Upon execute() we need to undef any data from a previous call. This
method will clear all call data and is usually done before each execute

=cut

sub _reset {
    my $self = shift;

    # clear previous call
    $self->{errors}            = undef;
    $self->{response_object}   = undef;
    $self->{response_content}  = undef;
    $self->{request_agent}     = undef;
    $self->{request_object}    = undef;
    $self->{response_dom}      = undef;
    $self->{response_json}     = undef;
    $self->{response_hash}     = undef;

}

=head1 _get_request_body

The request body should be provided by the subclass

=cut

sub _get_request_body {
    my $self = shift;
    
    my $xml = "<sample>some content</sample>";

    return $xml; 
}

=head1 _get_request_headers 

The request headers should be provided by the subclass

=cut

sub _get_request_headers {
    my $self = shift;
   
    my $obj = HTTP::Headers->new();

    $obj->push_header("SAMPLE-HEADER" => 'foo');
    
    return $obj;
}

=head1 _get_request_agent

The request request agent should be used by all subclasses

=cut

sub _get_request_agent {
    my $self = shift;

    my $ua= LWP::UserAgent->new();

    $ua->agent( sprintf( '%s / eBay API Simple (Version: %s)',
        $ua->agent,
        $eBay::API::SimpleBase::VERSION,
    ) );

    # timeout in seconds
    if ( defined $self->api_config->{timeout} ) {
        $ua->timeout( $self->api_config->{timeout} );
    }
    
    # add proxy
    if ( $self->api_config->{http_proxy} ) {
        $ua->proxy( ['http'], $self->api_config->{http_proxy} );
    }

    if ( $self->api_config->{https_proxy} ) {
        $ua->proxy( ['https'], $self->api_config->{https_proxy} );
    }
    
    return $ua;
}

=head1 _get_request_object

The request object should be provided by the subclass

=cut

sub _get_request_object {
    my $self = shift;

    my $url = sprintf( 'http%s://%s%s',
        ( $self->api_config->{https} ? 's' : '' ),
        $self->api_config->{domain},
        $self->api_config->{uri}
    );
  
    my $objRequest = HTTP::Request->new(
        "POST",
        $url,
        $self->_get_request_headers,
        $self->_get_request_body
    );

    return $objRequest;
}

1;

=head1 AUTHOR

Tim Keefer <tim@timkeefer.com>

=cut
