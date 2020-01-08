=============
Servidor LEMP
=============
----------------------------------------------------------------
HowTo de como instalar; en GNU & Linux, nginx, MariaDB y PHP-FPM
----------------------------------------------------------------

[[_TOC_]]

Descripción
===========
Éste es un servidor instalado en CentOS 7. Consta de servicios HTTP, de PHP por socket y Maria DB con una contraseña de root
generado aleatoriamente y de 30 caracteres.


Prerrequisitos
==============
Primero, tenemos que instalar algunas cosas:

.. code:: sh

    # instalar repositorio necesario
    dnf -y install epel-release

    # instalar paquetes necesarios
    dnf -y install nginx mariadb-server mariadb php-fpm php-mysqlnd

    # activar servicios
    systemctl enable nginx.service mariadb.service php-fpm.service

    # iniciar servicios
    systemctl start nginx.service mariadb.service php-fpm.service

.. note::

    Iniciamos los servicios porque ``MariaDB`` lo requiere para ser configurado.


nginx
=====
Primero hay que instalar ``nginx``. Éste es un servidor web bastante rápido y ligero. Es muy eficiente y por eso lo usamos.

Como nginx va a usar ``PHP-FPM`` por medio de FastCGI, debemos proveerle de algunos parametros para que funcione bien.

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
pedirle a ``nginx`` que incluya, de ahí, todos los archivos que terminen en '.conf'.

.. code:: sh

    # crear directorio
    mkdir /etc/nginx/server.d

Para pedirle a ``nginx`` que los incluya, agregaremos el siguiente archivo en ``/etc/nginx/conf.d/server.conf``:

.. code:: nginx

    include server.d/*.conf;

De la misma manera, vamos a crear un directorio para configuraciones que, los servidores, van a estar necesitando constantemente. El
directorio será: ``/etc/nginx/include.d``:

.. code:: sh

    mkdir /etc/nginx/include.d

Ahora, vamos a poner la configuración mínima para PHP ahí. Ésta configuración hace varias cosas:

* indica que los archivos index son: index.php, index.html e index.htm.
* activa la configuración preferida para usar controlador frontal.
* incluye los parámetros para fastcgi.
* indica que el socket para usar ``PHP-FPM`` está en: ``/run/php-fpm/www.sock``.

Así, no tenemos que repetir toda esta configuración en caso de crear muchos servidores que necesiten PHP; solo incluimos el archivo.

El archivo se llamará: ``/etc/nginx/include.d/php.conf``:

.. code:: nginx

    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
    }

Habiendo terminado la configuración de ``nginx``, vamos a crear un sitio de ejemplo. El sitio será ``misitio.tld``. Es un sitio
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

Ahora, debemos crear nuestro árbol de directorios para nuestros sitios web; siguiendo, siempre, lo que el Fylesystem Hierarchy
Standard (FHS) más reciente nos indica: https://refspecs.linuxfoundation.org/fhs.shtml

Entonces, creémos el árbol de directorio:

.. code:: sh

    # poner la máscara de permisos para archivos nuevos adecuada
    umask 006

    # crear los directorios
    mkdir -p /srv/www/php/misitio.tld/default/public

    # regresar la máscara de permisos para archivos nuevos a la habitual
    umask 022

Agregaremos, ahora, un archivo de ejemplo:

Primero: ``/srv/www/php/misitio.tld/default/public/index.html``:

.. code:: html

    <html>
        <head>
            <title>Mi Sitio</title>
        </head>

        <body>
            <h1>Bienvenido(a)</h1>

            <p>
                Éste es mi sitio!
            </p>
        </body>
    </html>

Este archivo nos ayudará a comprobar si ``nginx`` está funcionando bien.

MariaDB
=======
MariaDB es el servidor de base de datos que vamos a usar. Es muy utilizado y sirve muy bien.

Primero, necesitamos generar la contraseña de root de MariaDB para utilizar el servicio. Esto es muy importante porque, de no
hacerlo, cualquier usuario en nuestro servidor puede accesar como root.

.. code:: sh

    mariadb_root=$( cat /dev/urandom | tr -dc A-Za-z0-9 | head -c ${1:-30}; echo )

Lo hemos puesto en una variable. Para conocer cual es la contraseña, solo hay que hacerle ``echo`` a esa variable:

.. code:: sh

    echo "La contraseña de root de MariaDB es: $mariadb_root"

.. warning::
    Recuerda que, si te sales de la sesión (sSH o cierras tu terminal) perderás el valor de esa variable.

Lo que sigue es asegurar MariaDB para evitar que sea tan vulnerable como cuando recien se instala. Hay un script para eso llamado:
``mysql_secure_installation``; el cual puedes correr en cualquier momento y te guiará por los siguientes pasos.

En nuestro caso, vamos a correr cada comando para poder aprender, a detalle, qué es lo que hace.

Primero, vamos a usar el cliente de ``MariaDB`` para iniciar una sesión para con el servidor.

.. code:: sh

    mysql -u root

Luego, vamos a agregarle una contraseña a root de MariaDb. Recuerda consultar la contraseña de root de MariaDB que generamos
anteriormente. Substituye "<la-contraseña-de-root-de-mariadb>":

.. code:: sql

    UPDATE mysql.user SET Password = PASSWORD( '<la-contraseña-de-root-de-mariadb>' ) WHERE User = 'root';

Lo que sigue es eliminar el acceso para el usuario sin nombre.

.. code:: sql

    DELETE FROM mysql.user WHERE User = '';

Eliminar el acceso a root de manera remota:

.. code:: sql

    DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

Remover las bases de datos de prueba:

.. code:: sql

    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';

Recargamos los privilegios:

.. code:: sql

    FLUSH PRIVILEGES;
    EXIT;

Ahora, si queremos volver a entrar a MariaDB, debemos usar el cliente e indicarle que queremos usar una contraseña para entrar.

.. code:: sh

    mysql -u root -p

Para ser un poco prácticos, vamos a crear un archivo de configuración para el cliente; el cual contendrá nuestras credenciales.

El archivo se llamará: ``/root/.my.cnf``.

.. code:: ini

    [client]
    hostname = localhost
    user = root
    password = <la-contraseña-de-root-de-mariadb>

.. warning::

    El archivo: `/root/.my.cnf` representa un riesgo de seguridad, ya que, permite a root accesar a la base de datos sin requerir
    credenciales.

    Dicho ésto, si algún usuario no autorizado adquiere root en nuestro servidor, estaremos perdidos.

Sigue crear la base de datos de prueba. Para hacer eso, necesitamos, primero, un nombre de usuario y una contraseña. Vamos a
generarlos:

.. code:: sh

    mariadb_usuario=$( cat /dev/urandom | tr -dc A-Za-z0-9 | head -c ${1:-15}; echo; )
    mariadb_contra=$( cat /dev/urandom | tr -dc A-Za-z0-9 | head -c ${1:-30}; echo; )

Tanto el usuario como la contraseña están en las variables:

* $mariadb_usuario
* $mariadb_contra

Para verlas, podemos hacer ``echo``; como en el ejemplo anterior, o podemos, también, hacer lo siguiente:

.. code:: sh

    cat << EOF
    Base de datos

    Usuario:    $mariadb_usuario
    Contraseña: $mariadb_contra

    EOF

Para iniciar una sesión para con ``MariaDB`` a través de su cliente, ahora solo debemos escribir el nombre del cliente. Todos los
datos están en el archivo de configuración:

.. code:: sh

    mysql

Bueno, ahora, estamos listos para crear una base de datos de prueba. No olvides substituir: "<mariadb_usuario>" y "<mariadb_contra>"
por los actuales.

La base de datos de prueba solamente debe poder ser accesada por root y por un usuario sin privilegios. Debemos crear tal usuario y
otorgarle privilegios sobre la base de datos también.

.. code:: sql

    CREATE DATABASE `mst_tld-site` DEFAULT CHARSET utf8;
    CREATE USER '<mariadb_usuario>'@'localhost' IDENTIFIED BY '<mariadb_contraseña>';
    GRANT ALL PRIVILEGES ON `mst_tld-site`.* TO '<mariadb_usuario>'@'localhost';

La base de datos que hemos creado necesita una tabla. Vamos a crearla:

.. code:: sql

    DROP TABLE IF EXISTS `mst_tld-site`.visitas;

    CREATE TABLE `mst_tld-site`.visitas (
        total INT NOT NULL AUTO_INCREMENT,
        ultima TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        navegador VARCHAR(100) NOT NULL,
        PRIMARY KEY (total)
    );

PHP-FPM
=======
Este servicio es el que procesa el código PHP y lo envía a ``nginx`` para ser enviado como respuesta a una petición. Es uno de los
lenguajes de programación más usados en todo el mundo.

Para configurarlo, debemos editar su archivo de configuración en: ``/etc/php-fpm.d/www.conf``:

.. code:: ini

    [www]
    ; User and group
    user = apache
    group = apache

    ; socket
    listen = /run/php-fpm/www.sock
    listen.owner = nginx
    listen.group = nginx
    listen.mode = 0660
    listen.acl_users = apache,nginx
    listen.allowed_clients = 127.0.0.1

    ; processes
    pm = dynamic
    pm.max_children = 50
    pm.start_servers = 5
    pm.min_spare_servers = 5
    pm.max_spare_servers = 35

    ; logs
    slowlog = /var/log/php-fpm/www-slow.log
    php_admin_value[error_log] = /var/log/php-fpm/www-error.log
    php_admin_flag[log_errors] = on

    ; sessions
    php_value[session.save_handler] = files
    php_value[session.save_path] = /var/lib/php/session

    ; cache
    php_value[soap.wsdl_cache_dir] = /var/lib/php/wsdlcache

Esta configuración es suficiente para que nos dé servicio como queremos.

.. note::

    Por seguridad, practicidad y desempeño, utilizamos `PHP-FPM` por medio de sockets.

Servicios
=========
Ahora, vamos a reiniciar los servicios para ver si la configuración está correcta y no impidió que iniciaran los servidores.

.. code:: sh

    systemctl restart nginx.service mariadb.service php-fpm.service

Y revisaremos su estado:

.. code:: sh

    systemctl status nginx.service mariadb.service php-fpm.service

Si no hay lineas coloreadas de rojo, tenemos muy buena probabilidad de que todo funcione bien.

Seguridad
=========
En esta sección veremos como abrir puertos y configurar permisos para que todo funcione como debe y de manera segura.

Primero vamos a darle acceso al mundo a nuestro servicio de HTTP y HTTPS; que son los servicios que otorga ``nginx``.

.. code:: sh

    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --add-port=80/tcp --add-port=443/tcp
    firewall-cmd --reload

Ahora, vamos a asegurarnos de que ``root`` sea dueño de todo  en ``/etc/nginx``; de que ``nginx`` sea el grupo y que solo tenga
permiso de lectura. El mundo no debe tener permisos de nada ahí:

.. code:: sh

    chown -R root:nginx /etc/nginx
    find /etc/nginx -type d -exec chmod 2750 {} \;
    find /etc/nginx -type f -exec chmod 640 {} \;


Pruebas
=======
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
                # usa el usuario y contraseña que generamos al momento de crear la base de datos
                $usuario = 'QCdsXh9MT5yGN5h';
                $contra = 'jS9y4i9nPaFNwuXa2KX4R2XwVWK8NR';

                # verificar conexión
                try {
                    $db = new PDO( 'mysql:host=localhost;dbname=mst_tld-site', $user, $contra );
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
