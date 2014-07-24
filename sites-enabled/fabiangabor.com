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
	listen 80;
	server_name www.fabiangabor.com direct.fabiangabor.com;
	
	include /etc/nginx/php.conf;
	root /home/gabor/www/public_html/fabiangabor.com;
	
	add_header X-Cache $upstream_cache_status;
	add_header rt-Fastcgi-Cache $upstream_cache_status;	
	
	location / {
        try_files $uri $uri/ /index.html;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass php;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_cache microcache;
        fastcgi_cache_valid 200 60m;
    }
	
	
}
