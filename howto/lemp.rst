=============
Servidor LEMP
=============
----------------------------------------------------------------
HowTo de como instalar; en GNU & Linux, NginX, MariaDB y PHP-FPM
----------------------------------------------------------------

[[_TOC_]]

Descripción
===========
Éste es un servidor instalado en CentOS 7. Consta de servicios HTTP, de PHP por socket y Maria DB con un password de root generado
aleatoriamente y de 30 caracteres.


Prerrequisitos
==============

```bash:/howto/lemp/prerrequisitos```

.. note::

    Iniciamos los servicios porque MariaDB lo requiere para ser configurado.


NginX
=====
Primero hay que instalar ``NginX``. Éste es un servidor web bastante rápido y ligero. Es muy eficiente y por eso lo usamos.

Como NginX va a usar ``PHP-FPM`` por medio de FastCGI, debemos proveerle de algunos parametros para que funcione bien.

Edita el archivo ``/etc/nginx/fastcgi_params`` para que se vea así:

.. code:: nginx

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

Ahora, para facilitar el manejo de "servidores" o sitios, vamos a crear un directorio llamando ``/etc/nginx/server.d`` y vamos a
pedirle a ``NginX`` que incluya, de ahí, todos los archivos que terminen en '.conf'.

.. code:: sh

    # crear directorio
    mkdir /etc/nginx/server.d

Para pedirle a ``Nginx`` que los incluya, agregaremos el siguiente archivo en ``/etc/nginx/conf.d/server.conf``:

.. code:: nginx

    include server.d/*.conf;

De la misma manera, vamos a crear un directorio para configuraciones que, los servidores, van a estar necesitando constantemente. El
directorio será: ``/etc/nginx/include.d``:

.. code:: sh

    mkdir /etc/nginx/include.d

Ahora, vamos a poner la configuración mínima para PHP ahí. Ésta configuración hace varias cosas:

* indica que los archivos index son: index.html, index.htm e index.php.
* activa la configuración preferida para usar controlador frontal.
* incluye los parámetros para fastcgi.
* indica que el socket para usar ``PHP-FPM`` está en: ``/run/php-fpm/www.sock``.

Así, no tenemos que repetir toda esta configuración en caso de crear muchos servidores que necesiten PHP; solo incluimos el archivo.

El archivo se llamará: ``/etc/nginx/include.d/php.conf``:

.. code:: nginx

    index index.html index.htm index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/php-fpm.sock;
    }

Habiendo terminado la configuración de ``NginX``, vamos a crear un sitio de ejemplo. El sitio será ``misitio.tld``. Es un sitio
ficticio pero nos sirve para probar.

El archivo va en: ``/etc/nginx/server.d/misitio.tld.conf``

.. code:: nginx

    server {
        server_name misitio.tld;
        root /srv/www/php/misitio.tld/default/public;

        include include.d/php.conf;
    }

Este servidor responderá a la URL: ``misitio.tld``. Los archivos que ofrecerá se encontrarán en:
``/srv/www/php/misitio.tld/default/public``.

Además, como incluimos la configuración para PHP, pues podrá servir sitios hechos en el mismo.

.. warning::

    Es muy importante que borremos el archivo: `/srv/www/php/misitio.tld/default/public/info.php` después de usarlo para verificar
    el buen funcionamiento de PHP.

    El dejarlo implica el, potencialmente, mostrar mucha información; la cual, un cracker, pudiera usar para planear un ataque; por
    alguno de los medios disponibles.


MariaDB
=======

```bash:/howto/lemp/mariadb```

.. warning::

    El archivo: `/root/.my.cnf` representa un riesgo de seguridad, ya que, permite a root accesar a la base de datos sin requerir
    credenciales.

    Dicho ésto, si algún usuario no autorizado adquiere root en nuestro servidor, estaremos perdidos.


PHP-FPM
=======

```bash:/howto/lemp/php-fpm```

.. note::

    Por seguridad, practicidad y desempeño, utilizamos `PHP-FPM` por medio de sockets.

Servicios
=========


```bash:/howto/lemp/servicios```


Seguridad
=========

```bash:/howto/lemp/seguridad```


Pruebas
=======
Ahora, vamos a crear una tabla para probar que la conexión a MariaDb funciona bien.

Primero, creamos una tabla con algo de información:

.. code:: sh

    mysql -e 'DROP TABLE IF EXISTS `mst_tld-site`.visitas;'
    mysql -e '
    CREATE TABLE `mst_tld-site`.visitas(
        total int not null auto_increment,
        ultima timestamp default current_timestamp,
        navegador varchar(100) not null,
        primary key(total)
    );'

Ahora, vamos a crear un pequeño script de PHP que actualice el campo ``navegador`` y nos muestre cuantas veces hemos visitado:

.. code:: php

    <html>
        <head>
            <title>Prueba de PHP y MariaDB</title>
        </head>

        <body>
            <pre>
                <?php

                # datos
                # usa el usuario y password que generamos al momento de crear la base de datos
                $user = 'QCdsXh9MT5yGN5h';
                $password = 'jS9y4i9nPaFNwuXa2KX4R2XwVWK8NR';

                # verificar conexión
                try {
                    $db = new PDO( 'mysql:host=localhost;dbname=mst_tld-site', $user, $password );
                    echo( "\nEstatus: conectado!\n" );

                } catch ( PDOException $e ) {
                    echo( "Error!: " . $e->getMessage() );
                    die();
                }

                # insertar datos
                try {
                    $stmt = $db->prepare( 'insert into visitas( navegador ) values( :agente );' );
                    $stmt->bindParam( ':agente', $_SERVER['HTTP_USER_AGENT'] );
                    $stmt->execute();
                } catch ( PDOException $e ) {
                    echo( 'Error!: ' . $e->getMessage() );
                    die();
                }

                # obtener datos
                try {
                    $query = $db->query( 'select * from visitas order by total desc limit 1' );
                    $r = $query->fetch();

                    echo( 'Total de visita: ' . $r['total'] . "\n" );
                    echo( 'Hora de la visita: ' . $r['ultima'] . "\n" );
                    echo( 'Tu navegador es: ' . $r['navegador'] . "\n" );

                    $db = null;
                } catch ( PDOException $e ) {
                    echo( "Error!: " . $e->getMessage() );
                    die();
                }

                ?>
            </pre>
        </body>
    </html>

Ahora, solo ve a: http://misitio.tld/test.php y verás si se puede conectar o no.


Troubleshooting
===============

Referencias
===========
* https://wiki.centos.org/es
* https://www.nginx.com/resources/wiki/
* https://mariadb.com/kb/es/
* http://php.net/manual/es/
