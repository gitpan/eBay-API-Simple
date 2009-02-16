package eBay::API::Simple::RSS;

use strict;
use warnings;

use base 'eBay::API::SimpleBase';

use HTTP::Request;
use HTTP::Headers;
use XML::Simple;

our $DEBUG = 0;

=head1 NAME 

eBay::API::Simple::RSS

=head1 SYNPOSIS

  my $call = ebay::API::Simple::RSS->new();
  $call->execute(
    'http://sfbay.craigslist.org/search/sss?query=shirt&format=rss'
  );

  if ( $call->has_error() ) {
     die "Call Failed:" . $call->errors_as_string();
  }

  # getters for the response DOM or Hash
  my $dom  = $call->response_dom();
  my $hash = $call->response_hash();

  # collect all item nodes
  my @items = $dom->getElementsByTagName('item');

  foreach my $n ( @items ) {
    print $n->findvalue('title/text()') . "\n";
  }
  
=head1 new 

Constructor for the RSS API call

  my $call = ebay::API::Simple::RSS->new();
  $call->execute(
    'http://sfbay.craigslist.org/search/sss?query=shirt&format=rss'
  );

=cut 

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self;    
}

=head1 execute( $feed_url )
 
Calling this method will make build and execute the api request.
  
  $url = feed to fetch
  $call->execute( 
    'http://sfbay.craigslist.org/search/sss?query=shirt&format=rss' 
  );

=cut 

sub execute {
    my $self = shift;
    
    $self->{url} = shift;

    if ( ! defined $self->{url} ) {
        die "missing url";
    }
    
    $self->{response_content} = $self->_execute_http_request();

    # remove xmlns 
    $self->{response_content}  =~ s/xmlns=["'][^"']+"//;

    if ( $DEBUG ) {
        print STDERR $self->{response_content};
    }

}

=head1 _get_request_body

This methods supplies an empty request body for the RSS API call

=cut

sub _get_request_body {
    my $self = shift;
    return "";
}

=head1 _get_request_headers 

This methods supplies the headers for the RSS API call

=cut

sub _get_request_headers {
    my $self = shift;
   
    #my $obj = HTTP::Headers->new();
    #return $obj;
    return '';
}

=head1 _get_request_object 

This method creates the request object and returns to the parent class

=cut

sub _get_request_object {
    my $self = shift;

    my $request_obj = HTTP::Request->new(
        "GET",
        $self->{url},
    );

    return $request_obj;
}

1;

=head1 AUTHOR

Tim Keefer <tim@timkeefer.com>

=head1 COPYRIGHT

Tim Keefer 2009

=cut
