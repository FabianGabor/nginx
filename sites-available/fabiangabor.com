server {
   server_name fabiangabor.com;
   return 301 $scheme://www.fabiangabor.com$request_uri;
}

server {
   server_name fabiangabor.nspiron.com;
   return 301 $scheme://www.fabiangabor.com$request_uri;
}

server 
{
	server_name www.fabiangabor.com direct.fabiangabor.com;
	
	include conf.d/redirects.conf;
	
	include /etc/nginx/php.conf;
	root /home/gabor/www/public_html/fabiangabor.com;
	
	add_header X-Cache $upstream_cache_status;
	add_header rt-Fastcgi-Cache $upstream_cache_status;	
	
	
	# here i'm telling the server to rewrite all requests
	# for that contain a html extension-- remove the html
	if (!-e $request_filename)
    {
		rewrite (.*)\.html $1/ permanent;
		break;
	}
	#rewrite ^([^.]*[^/])\.html$ $1/ permanent;
	 
	# here i'm telling the server to try finding the file by appending
	# the .html on to it
	# important since the files all have extensions
	try_files $uri.html $uri/ /index.html;
	#try_files $uri.html $uri $uri/ =404;
	
	# removes trailing "index" from all controllers
    if ($request_uri ~* index/?$)
    {
        rewrite ^/(.*)/index/?$ /$1 permanent;
    }
 
    # catch all
    error_page 404 /index.php;
	
	location / 
	{	
		root /home/gabor/www/public_html/fabiangabor.com;
		access_log on;

		access_log  /home/gabor/www/logs/error.log;
		error_log  /home/gabor/www/logs/error.log;
		
		#try_files $uri $uri/ /index.php$is_args$args;		
		# Use cached or actual file if they exists, otherwise pass request to WordPress
		try_files /wp-content/cache/page_enhanced/${host}${cache_uri}_index.html $uri $uri/ /index.php?$args ;
	}

	include conf.d/h5bp.conf;
	
	location ~ \.html$ {
		if (!-f $request_filename) {
			# rewrite ^(.*)\.html$ $1 permanent;
			# rewrite (.*)\.html $1 permanent;
			rewrite ^(/.+)\.html$ $scheme://$host$1 permanent;
		}
	}
	
	
	#http://seravo.fi/2013/optimizing-web-server-performance-with-nginx-and-php
	
	set $cache_uri $request_uri;

	# POST requests and urls with a query string should always go to PHP
	if ($request_method = POST) {
		set $cache_uri 'null cache';
	}
	if ($query_string != "") {
		set $cache_uri 'null cache';
	}

	# Don't cache uris containing the following segments
	if ($request_uri ~* "(/wp-admin/|/xmlrpc.php|/wp-(app|cron|login|register|mail).php|wp-.*.php|/feed/|index.php|wp-comments-popup.php|wp-links-opml.php|wp-locations.php|sitemap(_index)?.xml|[a-z0-9_-]+-sitemap([0-9]+)?.xml)") {
		set $cache_uri 'null cache';
	}

	# Don't use the cache for logged in users or recent commenters
	if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_logged_in") {
		set $cache_uri 'null cache';
	}

	location ~ \.php$ {

		
		
		##
		# Fastcgi cache
		##
		set $skip_cache 1;
		if ($cache_uri != "null cache") {
		  add_header X-Cache-Debug "$cache_uri $cookie_nocache $arg_nocache$arg_comment $http_pragma $http_authorization";
		  set $skip_cache 0;
		}
		fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
		fastcgi_cache_bypass $skip_cache;
		fastcgi_cache microcache;
		#fastcgi_cache_key $scheme$host$request_uri$request_method;
		fastcgi_cache_valid any 60m;
		fastcgi_cache_bypass $http_pragma;
		fastcgi_cache_use_stale updating error timeout invalid_header http_500;
		
		##
		# WordPress PHP
		##
		try_files $uri /index.php;
		include fastcgi_params;
		fastcgi_read_timeout 300;
		proxy_pass http://php;
		fastcgi_pass unix:/var/run/php5-fpm.sock;
		
	}
}
