# configurar PHP-FPM para usar socket y permisos para nginx
sed -ri 's@^listen =.*$@listen = /run/php-fpm/www.sock@' /etc/php-fpm.d/www.conf
sed -ri 's@^;?listen.owner =.*$@listen.owner = nginx@' /etc/php-fpm.d/www.conf
sed -ri 's@^;?listen.group =.*$@listen.group = nginx@' /etc/php-fpm.d/www.conf
sed -ri 's@^;?listen.mode =.*$@listen.mode = 0660@' /etc/php-fpm.d/www.conf



