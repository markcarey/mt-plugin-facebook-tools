package FacebookTools::Pro::App::Comments;
use strict;

use FacebookTools::Util qw( get_facebook_client fbtools_pro user_from_fb_profile );

sub fb_login {
    my $app = shift;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	my $access_token = $q->param('access_token');
	my $mode = 'fb_login';
	my $args;
	my $plugin = MT->component('FacebookTools');
	my ($session, $commenter) = $app->get_commenter_session();

    my $client = get_facebook_client($app,$blog_id,$mode,$args);
    $client->access_token($access_token);
use Data::Dumper;    
	my $profile = eval{ $client->fetch('me') };
	if ( my $error = $@ ) {
	    MT->log("Facebook Tools error during fetch me: " . Dumper($error));
	}
MT->log("FB Profile: " . Dumper($profile));

    my $commenter = user_from_fb_profile($profile,$access_token);

MT->log("FB MT User: " . Dumper($commenter));

    return 'bakka';
}

sub fb_action {
    my $app = shift;
	my $q = $app->param;
	my $plugin = MT->component('FacebookTools');
	my ($session, $commenter) = $app->get_commenter_session();

}

1;