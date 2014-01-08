package FacebookTools::Tags;
use strict;

sub facebook_share_option {
    my($ctx, $args) = @_;
	my $get_cookie_function = $args->{get_cookie_function};
	if (!$get_cookie_function) {
		if (MT->VERSION >= 4.2) {
			$get_cookie_function = 'mtGetCookie';
		} else {
			$get_cookie_function = 'getCookie';
		}
	}
	my $out = <<"HTML";
	<div id="facebook-share" style="display: none">
	      <p>
	         <label for="comment-cc-facebook"><input type="checkbox"
	            id="comment-cc-facebook" name="facebook_share" value="1" />
	            Share this comment on Facebook?</label>
	      </p>
	</div>
	<script type="text/javascript">
	    var commenter_auth_type = $get_cookie_function("commenter_auth_type");
	    if (commenter_auth_type == 'Facebook') {
	      var el = document.getElementById('facebook-share');
	      if (el) el.style.display = 'block';
	    }
	</script>
HTML
}

1;