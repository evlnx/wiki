=============
Servidor LEMP
=============
----------------------------------------------------------
HowTo de como instalar; en Linux, NginX, MariaDB y PHP-FPM
----------------------------------------------------------

[[_TOC_]]

Descripción
===========
Éste es un servidor instalado en CentOS 7. Consta de servicios HTTP, de PHP por socket y Maria DB con un password de root generado
aleatoriamente y de 30 caracteres.


Prerrequisitos
==============

.. code:: bash

    # instalar repositorio necesario
    yum -y install epel-release

    # instalar paquetes necesarios
    yum -y install nginx mariadb-server mariadb php-fpm php-mysql apg


    # activar servicios
    systemctl enable nginx.service mariadb.service php-fpm.service

    # iniciar servicios
    systemctl start nginx.service mariadb.service php-fpm.service

.. note::

    Iniciamos los servicios porque MariaDB lo requiere para ser configurado.


NginX
=====

.. code:: bash

    # editar fastcgi_params
    cat << 'EOF' > /etc/nginx/fastcgi_params
    fastcgi_param  CONTENT_LENGTH     $content_length;
    fastcgi_param  CONTENT_TYPE       $content_type;
    fastcgi_param  QUERY_STRING       $query_string;
    fastcgi_param  REQUEST_METHOD     $request_method;

    fastcgi_param  DOCUMENT_ROOT      $document_root;
    fastcgi_param  DOCUMENT_URI       $document_uri;
    fastcgi_param  HTTPS              $https if_not_empty;
    fastcgi_param  REQUEST_SCHEME     $scheme;
    fastcgi_param  REQUEST_URI        $request_uri;
    fastcgi_param  SCRIPT_FILENAME    $request_filename;
    fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
    fastcgi_param  SERVER_PROTOCOL    $server_protocol;

    fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
    fastcgi_param  SERVER_SOFTWARE    nginx;

    fastcgi_param  REMOTE_ADDR        $remote_addr;
    fastcgi_param  REMOTE_PORT        $remote_port;
    fastcgi_param  SERVER_ADDR        $server_addr;
    fastcgi_param  SERVER_NAME        $server_name;
    fastcgi_param  SERVER_PORT        $server_port;

    # PHP only, required if PHP was built with --enable-force-cgi-redirect
    fastcgi_param  REDIRECT_STATUS    200;

    EOF

    # activar configuración independiente de servidores
    cat << 'EOF' > /etc/nginx/conf.d/servers.conf
    include server.d/*.conf;

    EOF

    # crear directorios server.d e include.d
    mkdir /etc/nginx/{server,include}.d

    # crear configuración /include.d/php.conf
    cat << 'EOF' > /etc/nginx/include.d/php.conf
    index index.html index.htm index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/php-fpm.sock;
    }

    EOF

    # crear primera instancia de servidor
    cat << 'EOF' > /etc/nginx/server.d/misitio.tld.conf
    server {
        listen 80;
        server_name misitio.tld;
        root /srv/www/php/misitio.tld/default/public;

        include include.d/php.conf;
    }

    EOF

    # crear directorios contenedores del sitio
    mkdir -p /srv/www/php/misitio.tld/default/public

    # arreglar permisos
    chmod -R 2771 /srv/www/php
    chmod 2775 /srv/www/php/misitio.tld/default/public
    restorecon -Rv /srv/www

    # asignar grupo webdev a los directorios pertinentes
    chgrp -R webdev /srv/www/*

    # crear archivos de prueba
    cat << 'EOF' > /srv/www/php/misitio.tld/default/public/index.php
    bienvenid@

    EOF

    ## éste archivo es de uso exclusivo de prueba y debemos borrarlo inmediatamente después de usarlo
    cat << 'EOF' > /srv/www/php/misitio.tld/default/public/info.php
    <?php

    phpinfo();

    EOF

server.d
--------
Para facilitar el manejo de las instancias de servidor de NginX que vamos a utilizar, vamos a utilizar la funcionalidad de `include`
para poder segmentar la configuración.

Para agregar una instancia es necesario simplemente crear un archivo en `/etc/nginx/server.d/`; el cual tiene que tener `.conf`
como extensión. Por ejemplo: `/etc/nginx/server.d/misitio.tld.conf`.

include.d
---------
Para facilitar la configuración de nuestras instancias de servidor, preferimos agregar el directorio `include.d` para manejar
nuestras configuraciones específicas.

En el caso de PHP, es necesario solamente incluir el archivo `include.d/php.conf` para activar su uso.

.. warning::

    Es muy importante que borremos el archivo: `/srv/www/php/misitio.tld/default/public/info.php` después de usarlo para verificar
    el buen funcionamiento de PHP.

    El dejarlo implica el, potencialmente, mostrar mucha información; la cual, un cracker, pudiera usar para planear un ataque; por
    alguno de los medios disponibles.


MariaDB
=======

.. code:: bash

    # generar password para mysql
    password=$( apg -M CLN -m 30 -n 1 )
    echo "El password para mysql será: $password"

    # instalación segura de MariaDB
    mysql_secure_installation

    # crear archivo .my.cnf
    cat << EOF > /root/.my.cnf
    [client]
    user = root
    password = $password
    host = localhost

    EOF

    # crear usuario y contraseña para base de datos
    user=$( apg -M CLN -m 15 -n 1 )
    password=$( apg -M CLN -m 30 -n 1 )
    cat << EOF
    Base de datos

    Usuario:  $user
    Password: $password

    EOF

    # crear base de datos
    mysql -e 'CREATE DATABASE `mst_tld-site` DEFAULT CHARSET utf8;'
    mysql -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password';"
    mysql -e "GRANT ALL PRIVILEGES ON \`mst_tld-site\`.* TO '$user'@'localhost';"

.. warning::

    El archivo: `/root/.my.cnf` representa un riesgo de seguridad, ya que, permite a root accesar a la base de datos sin requerir
    credenciales.

    Dicho ésto, si algún usuario no autorizado adquiere root en nuestro servidor, estaremos perdidos.


PHP-FPM
=======

.. code:: bash

    # configurar PHP-FPM para usar sockets
    sed -ri 's@^listen =.*$@listen = /run/php-fpm/php-fpm.sock@' /etc/php-fpm.d/www.conf

    # arreglar dueño, grupo y modo
    sed -ri 's@^;listen.owner =.*$@listen.owner = nginx@' /etc/php-fpm.d/www.conf
    sed -ri 's@^;listen.group =.*$@listen.group = nginx@' /etc/php-fpm.d/www.conf
    sed -ri 's@^;listen.mode =.*$@listen.mode = 660@' /etc/php-fpm.d/www.conf

.. note::

    Por seguridad, practicidad y desempeño, utilizamos `PHP-FPM` por medio de sockets.


Servicios
=========

.. code:: bash

    # reiniciar servicios
    systemctl restart nginx.service mariadb.service php-fpm.service


Seguridad
=========

.. code:: bash

    # abrir puertos de firewall para nginx
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --add-port=80/tcp --add-port=443/tcp
    firewall-cmd --reload


Troubleshooting
===============

Referencias
===========
* https://wiki.centos.org/es
* https://www.nginx.com/resources/wiki/
* https://mariadb.com/kb/es/
* http://php.net/manual/es/
