# 静态首页公共配置（被 xiaodao.fun / www.xiaodao.fun 共用）
root /data1/www/htdocs/home;
index index.html;

include /etc/nginx/conf.d/ssl.conf;

access_log /var/log/nginx/blog-access.log;
error_log /var/log/nginx/blog-error.log;

gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

location / {
    try_files $uri $uri/ =404;
}

location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}

error_page 404 /404.html;
location = /404.html {
    internal;
}
