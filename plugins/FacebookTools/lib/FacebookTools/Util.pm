package FacebookTools::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( autolink_tweet shorten truncate_string get_facebook_client first_img_url fbtools_pro asset_from_url user_from_fb_profile );

use MT::Util qw( trim encode_url );

sub _callback_url {
	my ($app, $mode, $args) = @_;
	my $cgi_path = $app->config('CGIPath');
    $cgi_path .= '/' unless $cgi_path =~ m!/$!;
    my $script;
    if ($app->id eq 'comments') {
        $script = $app->config('CommentScript');
    } else {
        $script = $app->config('AdminScript');
    }
    my $url 
        = $cgi_path 
        . $script
        . uri_params(
        'mode' => $mode,
        args => $args
        );

    if ( $url =~ m!^/! ) {
		my $host = $ENV{SERVER_NAME} || $ENV{HTTP_HOST};
        $host =~ s/:\d+//;
        my $port = $ENV{SERVER_PORT};
        my $cgipath = '';
        $cgipath = $port == 443 ? 'https' : 'http';
        $cgipath .= '://' . $host;
        $cgipath .= ( $port == 443 || $port == 80 ) ? '' : ':' . $port;
        $url = $cgipath . $url;
    }
	return $url;
}

sub get_facebook_client {
	my ($app,$blog_id,$mode,$args) = @_;
	$mode ||= 'facebooktools';
	my $plugin = MT->component('FacebookTools');
	if (!$blog_id) {
	    if ($app->can('param')) {
	        my $q = $app->param();
        	$blog_id = $q->param('blog_id');
	    }
	}
	my $config = $plugin->get_config_hash('system');
	my $blog_config = $plugin->get_config_hash('blog:'.$blog_id) if $blog_id;
	my $facebook_application_id = $blog_config->{facebook_application_id} || $config->{facebook_application_id} || MT->config('FacebookToolsApplicationID');
	my $facebook_application_secret = $blog_config->{facebook_application_secret} || $config->{facebook_application_secret} || MT->config('FacebookToolsApplicationSecret');
	my $postback_url = _callback_url($app,$mode,$args);
	use Facebook::Graph;
	my $client = Facebook::Graph->new(
		app_id    => $facebook_application_id,
		secret => $facebook_application_secret,
		postback => $postback_url,
	);
	return $client;
}

sub autolink_tweet {
	my ($str) = @_;
	# autolink URLs
    $str =~ s!(^|\s|>)(https?://[^\s<]+)!$1<a href="$2">$2</a>!gs;
	# autolink @mentions
	$str =~ s!\@([a-zA-Z_]+)!\@<a href="http://facebook.com/$1">$1</a>!gs;
	return $str;
}

sub shorten {
	my ($long_url, $config) = @_;
	return $long_url if $config->{never_shorten};
	return $long_url if (length($long_url) < 26);
	my $service = $config->{shortner_service};
	$service = 'Bitly' if ($service eq 'Bit.ly');
	my $user = $config->{shortner_username};
	my $api_key = $config->{shortner_apikey};
	return $long_url if !$service;
	my $class = "WWW::Shorten " . "'" . $service . "'";
	eval "use $class";
	if ($@) {
		MT->log("Facebook Tools shorten Error: " . $@);
		return $long_url;
	}
    my $short_url = makeashorterlink($long_url,$user,$api_key);	
	return $short_url;
}

sub truncate_string {
    my($text, $max) = @_;
	$max = $max - 3;
	my $len = length($text);
	return $text if $len <= $max;
    my @words = split /\s+/, $text;
	$text = '';
	foreach my $word (@words) {
		if (length($text . $word) <= $max) {
			$text .= $word . ' ';
		}
	}
	$text = trim($text);
	$text .= '...' if ($len > length($text));
    return $text;
}

sub first_img_url {
    my ($entry) = @_;
    my $text = $entry->excerpt . $entry->text . $entry->text_more;
    $text = '' unless defined $text;
	my $img;
	if ($text =~ m#<img[^>]+src=['"]?([^'" ]+)#i) {
		$img = $1;
    	if ($img =~ m!^/!) {
        	# relative path, prepend blog domain
        	my $blog = $entry->blog;
        	if ($blog) {
            	my ($blog_domain) = $blog->archive_url =~ m|(.+://[^/]+)|;
            	$img = $blog_domain . $img;
        	}
    	}
	} else {
		$img = '';
	}
	return  $img;
}

sub fbtools_pro {
    eval{ require FacebookTools::Pro::Callbacks };
}

#copied from MT::App::uri_params for case where running via run-periodic-tasks (scheduled post publishing)
sub uri_params {
    #my $app = shift;
    my (%param) = @_;
    my @params;
    push @params, '__mode=' . $param{mode} if $param{mode};
    if ( $param{args} ) {
        foreach my $p ( keys %{ $param{args} } ) {
            if ( ref $param{args}{$p} eq 'ARRAY' ) {
                push @params, ( $p . '=' . encode_url($_) )
                    foreach @{ $param{args}{$p} };
            }
            else {
                push @params, ( $p . '=' . encode_url( $param{args}{$p} ) )
                    if defined $param{args}{$p};
            }
        }
    }
    @params ? '?' . ( join '&', @params ) : '';
}

sub asset_from_url {
    my ($image_url) = @_;
    my $ua   = _get_ua() or return;
    my $resp = $ua->get($image_url);
    return undef unless $resp->is_success;
    my $image = $resp->content;
    return undef unless $image;
    my $mimetype = $resp->header('Content-Type');
    my $def_ext = {
        'image/jpeg' => '.jpg',
        'image/png'  => '.png',
        'image/gif'  => '.gif'}->{$mimetype};

    require Image::Size;
    my ( $w, $h, $id ) = Image::Size::imgsize(\$image);

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new('Local');

    my $save_path  = '%s/support/uploads/';
    my $local_path =
      File::Spec->catdir( MT->instance->static_file_path, 'support', 'uploads' );
    $local_path =~ s|/$||
      unless $local_path eq '/';    ## OS X doesn't like / at the end in mkdir().
    unless ( $fmgr->exists($local_path) ) {
        $fmgr->mkpath($local_path);
    }
    my $filename = substr($image_url, rindex($image_url, '/'));
    if ( $filename =~ m!\.\.|\0|\|! ) {
        return undef;
    }
    my ($base, $uploaded_path, $ext) = File::Basename::fileparse($filename, '\.[^\.]*');
    $ext = $def_ext if $def_ext;  # trust content type higher than extension

    # Find unique name for the file.
    my $i = 1;
    my $base_copy = $base;
    while ($fmgr->exists(File::Spec->catfile($local_path, $base . $ext))) {
        $base = $base_copy . '_' . $i++;
    }

    my $local_relative = File::Spec->catfile($save_path, $base . $ext);
    my $local = File::Spec->catfile($local_path, $base . $ext);
    $fmgr->put_data( $image, $local, 'upload' );

    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local);
    return undef if $asset_pkg ne 'MT::Asset::Image';

    my $asset;
    $asset = $asset_pkg->new();
    $asset->file_path($local_relative);
    $asset->file_name($base.$ext);
    my $ext_copy = $ext;
    $ext_copy =~ s/\.//;
    $asset->file_ext($ext_copy);
    $asset->blog_id(0);

    my $original = $asset->clone;
    my $url = $local_relative;
    $url  =~ s!\\!/!g;
    $asset->url($url);
    $asset->image_width($w);
    $asset->image_height($h);
    $asset->mime_type($mimetype);

    $asset->save
        or return undef;

    MT->run_callbacks(
        'api_upload_file.' . $asset->class,
        File => $local, file => $local,
        Url => $url, url => $url,
        Size => length($image), size => length($image),
        Asset => $asset, asset => $asset,
        Type => $asset->class, type => $asset->class,
    );
    MT->run_callbacks(
        'api_upload_image',
        File => $local, file => $local,
        Url => $url, url => $url,
        Size => length($image), size => length($image),
        Asset => $asset, asset => $asset,
        Height => $h, height => $h,
        Width => $w, width => $w,
        Type => 'image', type => 'image',
        ImageType => $id, image_type => $id,
    );

    $asset;
}

sub _get_ua {
    return MT->new_ua( { paranoid => 1 } );
}

sub user_from_fb_profile {
    my ($profile,$access_token) = @_;
    # first check for this user in the database
	my $user_class = MT->model('author');
	my @authors = $user_class->search_by_meta('facebook_id',$profile->{id});
	my $commenter;
	my $mt_user;
	if (@authors) {
	    foreach my $author (@authors) {
	        if ($author->auth_type eq "MT") {
	            $commenter = $author;
	            $mt_user = 1;
	        }
	    }
	    $commenter = $authors[0] if !$commenter;
	}
	if (!$commenter) {
	    # check for commenter from old FB Commenters
	    $commenter = $user_class->load({ name => $profile->{id}, auth_type => 'Facebook' });
	}
	
	if (!$commenter) {
		# user not found in db, create the user
		my $user = $profile->{id};
        my $nick = $profile->{name} ? $profile->{name} : $user;
		$commenter = $user_class->new;
		$commenter->name($user);
		$commenter->nickname($nick);
		$commenter->url($profile->{link});
		$commenter->password('(none)');
		$commenter->auth_type('Facebook');
		$commenter->type(2);
		$commenter->remote_auth_token($profile->{id});
	}
	if (!$mt_user) {
	    my $asset = asset_from_url('http://graph.facebook.com/' . $profile->{id} . '/picture');
    	if ($commenter->userpic_asset_id && $asset) {
    	    #remove old userpic asset and replace, in case they have change their profile pic on FB
    	    my $old_userpic = MT->model('asset')->load($commenter->userpic_asset_id);
    	    $old_userpic->remove if $old_userpic;
    	}
    	$commenter->userpic_asset_id($asset->id) if $asset;
    }
	$commenter->facebook_username($profile->{name});
	$commenter->facebook_id($profile->{id});
	$commenter->facebook_access_token($access_token);
	$commenter->save;
	return $commenter;
}

1;