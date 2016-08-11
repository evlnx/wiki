=============
Servidor LEMP
=============
---------------------
Componentes generales
---------------------

Descripción
===========
Se le llama LEMP al tipo de configuración que tiene éste tipo de servidores que es utilizado para almacenar y administrar un
servidor web.


NginX
=====
Éste es el servidor web, básicamente el mandadero, sólo lleva y trae cosas. En /etc/nginx/fastcgi_params agregar el comando:
`fastcgi_param  SCRIPT_FILENAME    $request_filename;`


PHP-FPM
=======
Éste es el lenguaje de programación base con un administrador de procesos en el script, es el que dentro del servidor hace todos los
procesos.


MariaDB
=======
Ésta es la base de datos de nuestro servidor.
#. **CREATE DATABASE**: Crear una nueva base de datos, es importante cambiar la configuración de entrada de texto, todo con el
   siguiente formato: "CREATE DATABASE `<título-de-la-base-de-datos>` DEFAULT CHARSET utf8;".
#. **CREATE USER**: Una vez en la configuración de MariaDB(a la cual se accesa con el comando *mysql*) se utiliza éste comando para
   crear un nuevo usuario en la case de datos, agregar *IDENTIFIED BY* si se desea con contraseña con el siguiente formato:
   "CREATE USER '<usuario>'@'localhost' IDENTIFIED BY '<contraseña>';".
#. **GRANT**: Comando utilizado para otorgar permisos a los usuarios sobre bases de datos especificadas, usaremos el siguiente
   formato: "GRANT ALL PRIVILEGES ON `<título de la base de datos>`.* TO '<usuario>'@'localhost';" en el cual el asterisco es
   utilizado para expresar *todas las tablas*.


Atajos y notas de utilidad
==========================
#. **Comando curl**: Ver si hay respuesta de una página web, nos permite hacer un request al puesrto que queramos y nos permite
   conocer el estado de nuestra página.
#. **Configurar sockets en PHP-FPM**: Ésto se lleva a cabo en la configuración de PHP-FPM que siempre se encuentra ubicada en los
   ficheros con terminación ".d"  y que generalmente y por default se llama "ww.conf", hay un apartado que es específico para éste tipo de configuración y a éste se le modifica la parte
   de *Listen* que, en lugar de tener una dirección IP vamos a establecer una especie de *link* respetando el Filesystem Hierarchy
   Standard en la carpeta: /run/php-fpm/. Para guardar los cambios reiniciamos el servicio con el comando **systemctl**.
#. **Para toda duda**: En caso de duda lo primero que se debe hacer es buscarlo en el navegador y ver preferentemente el manual
   oficial.
#. **Errores en la página**: Para cualquier error habido en la página hay un apartado en "/var/log/nginx/" para errores en el cual
   especifica el error.
#. Es necesario que tenga permisos aquel usuario encargado de éste tipo de tareas sobre ellos, jamás root, y debe, por cuestiones
   gramaticales también tener el permiso el grupo *webdev*.
#. Al instalar wordpress y haber creado el sitio se deben reconfigurar las etiquetas de los permisos que llevan éstas por ser
   utilizadas por las aplicaciones de manejo web, ésto se lleva a cabo con el comando: `restorecon -Rv <path-al-directorio-web>`.
   Regularmente se ejecuta éste comando a la ubicación en la que se encuentra el sitio web solamente, si se hace antes puede
   modificar otra páginas web, en caso de tenerlas.
   Ésta acción se ejecuta basado en el Filesystem Hierarchy Standard y sin eso no vamos ni siquiera a poder leer los archivos.
#. Para eliminar ficheros de una manera segura dándonos cuenta de que están vcíos se usa el comando `rmdir`, si nos marca error es
   que no se encuentra vacío y por tanto, no lo elimina.
#. Para listar los permisos se utiliza el comando `ls -l`.
#. Al configurar el firewall y abrir los puertos, en caso de que se use la opción `--permanent` es necesario correr posteriormente
   el comando `--reload` para que funcione y se aplique, en caso contrario al reiniciar el servicio o servidor se restaurará la
   configuración inicial.
