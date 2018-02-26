===
SSH
===
------------------------
HowTo: Como instalar SSH
------------------------

Descripción
===========
El SSH, o "Secure Shell", se utiliza para conectarse a otros servidores.

Lo puedes usar para copiar archivos, correr programas de manera remota y hasta para navegar la red a través de otro servidor.

Prerrequisitos
==============
Cualquiera de los siguientes es suficionete:

* Instalación mínima de CentOS/Fedora.
* Instalación mínima de Arch Linux.

Fedora
======
Instalación
-----------

.. code:: bash

    # instalar ssh
    dnf -y install openssh


Arch Linux
==========
Instalación
-----------

.. code:: bash

    # instalar ssh
    pacman -Syu openssh


Configuración
=============
Ahora, necesitas generar tu llave en tu estación de trabajo.

.. code:: bash

    # generar llave RSA (local)
    ssh-keygen -b 8192

    # generar llave de curva elíptica (mucho más segura y rápida)
    ssh-keygen -t ed25519

Con ésto, has generado dos partes de cada llave. La parte pública y la parte privada.

.. warning::

    La parte privada de tu llave es muy importante y no debe ser accesible por nadie más que por tí. El tener una copia de la parte
    privada implica tener acceso a todo lo que se te haya concedido.

.. note::

    La parte pública de tu llave puede ser publicada hasta en tu sitio web. No implica riesgo.

.. note::

    Es muy importante que le pongas un muy buen password a tus llaves. De esta manera, si las pierdes, te da algo de tiempo para
    revocar el acceso antes de que el cracker pueda obtener el password.

.. note::

    No es estrictamente necesario generar los dos tipos de llaves. Lo hacemos por compatibilidad.


Acceso
======
Para obtener acceso a un servidor u estación de trabajo, solo debes copiar el contenido de la parte pública de tu llave a:
`/root/.ssh/authorized_keys` o `/home/<usuario>/.ssh/authorized_keys`.

He aquí una manera simple para agregar tu llave:

.. code:: bash

    # ir al servidor e identificarte con contraseña
    ssh renich@mi-servidor.example.tld

    # configurar la máscara de permisos adecuadamente:
    # 077: el dueño tiene todos los permisos, el grupo y el mundo no tienen permisos
    umask 077

    # crear el directorio $HOME/.ssh
    mkdir $HOME/.ssh

    # ir al directorio
    cd $HOME/.ssh

    # crear el archivo authorized_keys e insertar la parte pública de tu(s) llave(s)
    vim authorized_keys

    # verificar que todo está bien
    cat $HOME/.ssh/authorized_keys

El resultado debiera ser algo como:

::

    # Renich Bon Ciric
    ## Mi llave ED25519
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWo3RJ88qk1RS+P6b8U+rFJ1GpIxKvWW7AGrgiCx8dK renich@introdesk

    ## mi llave RSA
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAEAQC8LgmKrDAEEj/gYYjL/M6kfl5z19HaA8ANdY5bVaDMrdOQPVEvC0RPwMDW7te/C9Pnd+Ms7ImOydaos0FCyMKoSdVCK3i7rkuJPiLLVpaFR3qkM2v0eMaOAbpFvamac4TFuBrNWVsgRZKmataij2jE8EuGl+JMKXjaRPJLAkYwucq

.. note::

    Las llaves ocupan una sola línea por llave.

Ahora, para probar que todo funciona bien, hacemos lo siguiente en otra terminal:

.. code:: bash

    # probar el acceso
    ssh renich@mi-servidor.example.tld

El resultado debiera ser que pude entrar sin necesidad de contraseñas; más que la de mis llaves. Si configuro mi agente de SSH para
capturarlas, no tendré que poner el password. Más sobre el tema en la sección de optimización.

.. note::

    La locación del archivo de acceso puede ser modificada en `/etc/ssh/sshd_config`. La directiva es: AuthorizedKeysFile


Seguridad
=========
Necesitamos hacer algunas cosas para restringir el acceso a nuestro servidor solo a los usuarios interesados. Además, permitirle a
`root` entrar solo con llaves.

Restringir el acceso a root solo con llaves
-------------------------------------------
Para ésto, debemos de localizar la directiva:

.. code:: ssh-config

    # CentOS
    PermitRootLogin without-password

    # Fedora/Arch Linux
    PermitRootLogin prohibit-password

Es posible que la directiva esté en su lugar pero comentada. Ésto significa que es, por defecto, la configuración actual. Dicho
ésto, preferiremos quitarle el comentario para forzar la configuración en caso de un cambio de política por parte de upstream.

.. warning ::

    Una vez que cambiemos esta directiva, el acceso directo por ssh a root será restringido al uso de llaves. Asegúrate de copiar tu
    llave a `/root/.ssh/authorized_keys` antes de hacer ésto.

Para activar los cambios, es necesario reiniciar el servicio de SSH: `systemctl restart sshd.service`.

.. note::

    Si estás conectado por SSH al servidor y reinicias el servicio de SSH, no te preocupes, la conexión permanecerá. Si falla el
    reinicio, aún así, puedes corregir el error en el archivo de configuración e intentar de nuevo.

Restringir el acceso a los usuarios conocidos
---------------------------------------------
Para asegurarnos que solo los usuarios que queremos que tengan acceso lo tengan, es importante delimitarlos en la directiva:
`AllowUsers`. Por ejemplo:

.. code:: ssh-config

    ...
    AllowUsers root renich

 .. note::

    La lista es separada por espacios. Se pueden agregar grupos tambień usando %grupo. Más información en el manual de sshd_config.

Servicios
=========

.. code:: bash
    # activar
    systemctl enable sshd.service

    # encender
    systemctl start sshd.service

    # verificar
    systemctl status sshd.service

    # identifiquemos el puerto 22 siendo usado por sshd.
    ss -t4lnp


Troubleshooting
===============


Referencias
===========
* https://www.openssh.com/manual.html
