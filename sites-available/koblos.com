server
{
	server_name www.koblos.com;
	return 301 $scheme://koblos.com$request_uri;
}

server 
{
	server_name koblos.com;
	
	include /etc/nginx/php.conf;
	root /home/koblos/www/public_html/;
	location / 
	{
		root /home/koblos/www/public_html/;
		access_log on;

		access_log  /home/koblos/www/logs/error.log;
		error_log  /home/koblos/www/logs/error.log;
	}

	location ~* \.html$ {
	  expires -1;
	}

	location ~* \.(css|js|gif|jpe?g|png)$ {
	  expires 168h;
	  add_header Pragma public;
	  add_header Cache-Control "public, must-revalidate, proxy-revalidate";
	}
}