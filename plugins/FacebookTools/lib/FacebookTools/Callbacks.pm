package FacebookTools::Callbacks;
use strict;

use MT::Util qw ( trim remove_html encode_url );
use FacebookTools::Util qw( get_facebook_client shorten truncate_string first_img_url fbtools_pro );


sub entry_pre_save {
	my ($cb, $entry, $entry_orig) = @_;
	return if $entry->facebook_object_id;
	return if $entry->{fbtest_done};
	$entry->{fbtest_done} = 'done';
	
	my $plugin = MT->component('FacebookTools');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{auto_share};
	return if !$enabled;
	
    my $access_token = $config->{facebook_access_token};
    return if !$access_token;
    
    my $entry_id = $entry->id;
	my $share_it = 0;
	
	if ($entry->status == 2) {
#MT->log("fbt after status check");
		if (!$entry_id) {
#MT->log("fbt no entry_id");
			$share_it = 1;   # new entry with published status
		} else {
#MT->log("fbt entry_id found");
			# entry was previously saved in db -- now determine if it status has just been changed to published
			$entry->clear_cache();
			$entry->uncache_object();
			$entry_orig = MT->model('entry')->load($entry_id);
			if ($entry_orig->status != 2) {
				# now we know status has just been changed to published and we have no status_id on record - so tweet it
				$share_it = 1;
			}
		}
	}
	
	if ($share_it) {
#		MT->log($entry->title . " just published and should be shared on Facebook");
		$entry->{share_it} = 'yes';
	}
	
}

sub build_page {
    my ($cb, %params) = @_;
    my $entry = $params{Entry};
    return if !$entry;
    # MT->log("FBT build_page for: " . $entry->title);
    my $html = $params{Content};
    my $file = $params{File};
    if ($file && $html) {
        my $fmgr = $entry->blog->file_mgr;
        unless ($fmgr->content_is_updated( $file, $html )) {
            my $key = 'fbme_' . $entry->id;
            my $session = MT->model('session')->load({ kind => 'FB', id => $key });
            return if !$session;
            # okay should be tweeted
            $session->remove; # prevent duplicate tweets when multiple rpt daemons running
    
            $entry->{share_it} = 'manual'; #triggered by checkbox

            my $ctx = $params{Context};
            my $img_url = $ctx->var('lead_image_url') if $ctx;

            _share_entry($entry,$img_url);
        }
    }
}

sub build_file {
    my ($cb, %params) = @_;
    my $entry = $params{Entry};
    return if !$entry;
    my $key = 'fbme_' . $entry->id;
    my $session = MT->model('session')->load({ kind => 'FB', id => $key });
    return if !$session;
    # okay should be shared on FB
    $session->remove; # prevent duplicate tweets when multiple rpt daemons running
    
    $entry->{share_it} = 'yes';
    
    my $ctx = $params{Context};
    my $img_url = $ctx->var('lead_image_url') if $ctx;
    
    _share_entry($entry,$img_url);
}

sub entry_post_save {
    my ($cb, $entry, $entry_orig) = @_;
    _shareme($entry->id) if $entry->{share_it};
}

sub _share_entry {
    my ($entry,$img_url) = @_;
	return if $entry->facebook_object_id;   # alreaded shared
	return unless $entry->{share_it};
	my $entry_id = $entry->id;
	my $plugin = MT->component('FacebookTools');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{auto_share};
	
	my $pro = fbtools_pro();
#MT->log("fbt Eval error: " . $@) if $@;
#use Data::Dumper;
#MT->log("fbt pro is " . Dumper($pro));
	if ( $enabled && $pro && ($entry->{share_it} eq 'yes') ) {
#		MT->log("fbt inside pro filters if");
		$enabled = FacebookTools::Pro::Callbacks::auto_share_filters($entry, $config);
#		MT->log("fbt after filter check enabled is now $enabled");
	}
	return if !$enabled;
	my $facebook_username = $config->{facebook_username};

#	MT->log("entry share_it is:" . $entry->{share_it});

	## Send Facebook posts in the background.
#   MT::Util::start_background_task(
#        sub {
			my $client;
			if ( $entry->authored_on =~
                m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?! ) {
				my $s = $6 || 0;
				my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
				$entry->authored_on($ts);
			}
			my $user = $entry->author;			
			
			my $access_token = $config->{facebook_access_token};
			
			my $blog_tweet = 1 if ($access_token);
			my $user_tweet = 1 if ($user->facebook_access_token);
			return unless ($blog_tweet || $user_tweet);

			my $prefix = $config->{tweet_prefix} || '';
			$prefix .= ' ' if ($prefix !~ /\s$/);
			my $field = $config->{tweet_field} || 'title';
			my $tweet_text;
			if ($field eq 'custom') {
				if ($entry->has_meta('field.fbstatus')) {
	                $tweet_text = $entry->meta('field.fbstatus');
					$tweet_text = MT->app->param("customfield_fbstatus") if (!$tweet_text);
	            } 
			} else {
				$tweet_text = remove_html($entry->$field);
			}
			return if !$tweet_text;
			my $default_hashtags = $config->{default_hashtags} || '';
			$default_hashtags = ' ' . $default_hashtags unless ($default_hashtags =~ /^\s/);

			my $tweet = $prefix . truncate_string($tweet_text,420 - length($prefix) - length($default_hashtags)); 
			my $chars_left = 419 - length($tweet) - length($default_hashtags);
			my $entry_hashtags = '';
			if ($config->{entry_hashtags}) {
				if (my @tags = $entry->get_tags) {
					foreach my $tag (@tags) {
						$tag =~ s/\s//;  # remove spaces
						$entry_hashtags .= '#' . $tag . ' ' unless ($tag =~ /^\@/);
					}
					$entry_hashtags = truncate_hashtags($entry_hashtags, $chars_left - 1);
					$entry_hashtags = ' ' . $entry_hashtags if $entry_hashtags;
				}
			}
			my $short_url = shorten(MT::Util::strip_index($entry->permalink,$entry->blog), $config);
			# $tweet .= ' ' . $short_url . $default_hashtags . $entry_hashtags;
			
			my $desc = truncate_string(remove_html($entry->text), 200);
#			my $img_url;
			
			if (!$img_url) {
                my $oa = MT->model('objectasset')->load({
                    object_id => $entry->id,
                    blog_id => $entry->blog_id,
                    object_ds => $entry->datasource,
                }, { limit => 1 });
                if ($oa) {
                    my $asset = MT->model('asset')->load($oa->asset_id);
#MT->log("FBT entry asset found: " . Dumper($asset));
                    $img_url = $asset->url if ($asset && $asset->class_type eq 'image');
#MT->log("FBT img_url from asset is $img_url");
                }
                $img_url = first_img_url($entry) if !$img_url;
			}
			
			my $share_url = 'http://www.facebook.com/sharer.php?u=' . encode_url($short_url) . '&t=' . encode_url($entry->title);
			
			# start blog-level tweet			
			if ($access_token) {
				$client = get_facebook_client(MT->instance,$entry->blog_id,'facebooktools');
				$client->access_token($access_token);
				
				my $res = $client->add_post
                   ->set_message($tweet)
                   ->set_picture_uri($img_url)
                   ->set_link_uri($short_url)
                   ->set_link_name($entry->title)
                   ->set_link_caption($entry->blog->site_url)
                   ->set_link_description($desc)
                   ->set_actions([{ name => 'Share', link => $share_url }])
                   ->publish;
#        MT->log("FB Tools add_post response: " . Dumper($res->as_hashref));
                    my $fb_id = $res->as_hashref->{id};
                    if ($fb_id) {
        				$entry->facebook_object_id($fb_id);
        				# $entry->facebook_short_url($short_url) if ($short_url ne $entry->permalink);
        				$entry->save;
        			}
				$entry->{tweeted}{$facebook_username} = 1;
			}
			
			# start user-level tweet
			if ($user->facebook_access_token && !$entry->{tweeted}{$user->facebook_username}) {
			    my $args = {};
            	$args->{id} = $user->id;
				$client = get_facebook_client(MT->instance,$entry->blog_id,'facebook_account',$args);
				$client->access_token($user->facebook_access_token);
				my $res = $client->add_post
                   ->set_message($tweet)
                   ->set_picture_uri($img_url)
                   ->set_link_uri($short_url)
                   ->set_link_name($entry->title)
                   ->set_link_caption($entry->blog->site_url)
                   ->set_link_description($desc)
                   ->set_actions([{ name => 'Share', link => $share_url }])
                   ->publish;
#        MT->log("FB Tools user add_post response: " . Dumper($res->as_hashref));
                    my $fb_id = $res->as_hashref->{id};
                    if ($fb_id && !$entry->facebook_object_id) {
        				$entry->facebook_object_id($fb_id);
        				# $entry->facebook_short_url($short_url) if ($short_url ne $entry->permalink);
        				$entry->save;
        			}
			}
			
#        }
#    );

	return 1;
}

sub _shareme {
    my ($entry_id) = @_;
    my $key = 'fbme_' . $entry_id;
    my $session = MT->model('session')->load({ kind => 'FB', id => $key });
    next if ($session); #if the session exists that means we queued this already
    
    # now create session
    $session = MT->model('session')->new;
    $session->kind('FB');
    $session->id($key);
    $session->start(time);
    $session->save;
}

sub comment_post_save_old {
    my ($cb, $comment, $comment_original) = @_;
}

sub comment_post_save {
	my ($cb, $comment, $comment_original) = @_;
# MT->log("start comment_post_save for: " . $comment->text);
	return if $comment->remote_id;
	return if $comment->remote_service;

	my $app = MT->instance->app;
	return if !($app->can('param')); 

	my ($session, $commenter) = $app->get_commenter_session();
	return if !$commenter;
	return if !($app->param('facebook_share') || $commenter->facebook_share);  # must have either comment form checkbox option or user setting to proceed
	my $access_token = $commenter->facebook_access_token;
# use Data::Dumper;
# MT->log("commenter is:" . Dumper($commenter) . " and access_token is $access_token");
	return unless ($access_token);


    ## Send Twitter posts in the background.
#    MT::Util::start_background_task(
#        sub {
			my $entry = $comment->entry;
			my $blog = $entry->blog;
			my $args = {};
        	$args->{id} = $commenter->id;
			my $client = get_facebook_client(MT->instance,$entry->blog_id,'facebook_account',$args);
			$client->access_token($access_token);

            my $fb_obj_id = $entry->facebook_object_id;
# MT->log("fb_obj_id is:" . $fb_obj_id);
            if (0) {
                # found on FB profile or Page -- try to post comment
                my $res;
                eval {
                    $res = $client->add_comment($fb_obj_id)
                       ->set_message($comment->text)
                       ->publish
                };
                MT->log("FB comment on Page story die error:" . Dumper($@)) if $@;
                MT->log("FB comment onj_id is " . $res->as_hashref->{id}) if $res;
            }
			my $tweet = 'commented on ' . $entry->title . ' on ' . $blog->name . '.'; 
			my $desc = truncate_string(remove_html($entry->text), 200);
			my $img_url;
			
			if (1) {
                my $oa = MT->model('objectasset')->load({
                    object_id => $entry->id,
                    blog_id => $entry->blog_id,
                    object_ds => $entry->datasource,
                }, { limit => 1 });
                if ($oa) {
                    my $asset = MT->model('asset')->load($oa->asset_id);
#MT->log("FBT entry asset found: " . Dumper($asset));
                    $img_url = $asset->url if ($asset && $asset->class_type eq 'image');
#MT->log("FBT img_url from asset is $img_url");
                }
                $img_url = first_img_url($entry) if !$img_url;
			}
			my $res = $client->add_post
               ->set_message($tweet)
               ->set_picture_uri($img_url)
               ->set_link_uri($entry->permalink)
               ->set_link_name($entry->title)
               ->set_link_caption($blog->site_url)
               ->set_link_description($desc)
               ->set_actions([
                   {
                       name    => 'Read on ' . $blog->name,
                       link    => $blog->site_url,
                   }
                ])
               ->publish;
			my $fb_id = $res->as_hashref->{id};
			$res = $client->add_comment($fb_id)
               ->set_message($comment->text)
               ->publish;
            my $fb_cmt_id = $res->as_hashref->{id};
			
			if ($fb_cmt_id) {
				$comment->remote_service('facebook');
				$comment->remote_id($fb_cmt_id);
				$comment->save;
			}
#        }
#    );

	return 1;
}


sub truncate_hashtags {
    my($text, $max) = @_;
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
    return $text;
}

1;