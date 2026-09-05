===
SSH
===
--------------------------------------------------------------------
HowTo: Cómo instalar y asegurar OpenSSH en CentOS Stream 10/Fedora 44
--------------------------------------------------------------------

Descripción
===========
SSH (*Secure Shell*) es el protocolo estándar para la administración remota cifrada de sistemas GNU/Linux.

Permite acceder a consolas de comandos remotas, transferir archivos mediante SCP o SFTP, ejecutar comandos individuales de forma segura y redirigir puertos o túneles de red a través de conexiones autenticadas y cifradas.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta root).
* SELinux activo y en modo Enforcing.


Instalación
===========

```bash:/howto/ssh/instalacion.bash```


Generación de Llaves de Acceso
==============================
En tu estación de trabajo local, debes generar un par de llaves criptográficas (una pública y una privada).

Se recomienda enfáticamente el uso de curvas elípticas Ed25519 por su rendimiento y nivel de seguridad:

.. code:: bash

    # Generar llave de curva elíptica Ed25519 (Recomendado)
    ssh-keygen -t ed25519 -C "usuario@estacion"

    # Alternativa: generar llave RSA de 4096 bits (compatibilidad con sistemas legados)
    ssh-keygen -t rsa -b 4096 -C "usuario@estacion"

.. warning::

    La **llave privada** (ej. ``~/.ssh/id_ed25519``) es estrictamente confidencial y nunca debe compartirse ni exponerse. Cualquier entidad con acceso a la llave privada obtendrá los mismos privilegios del usuario correspondiente.

.. note::

    La **llave pública** (ej. ``~/.ssh/id_ed25519.pub``) puede compartirse e instalarse libremente en los servidores de destino sin riesgo de seguridad.

.. important::

    Asigna siempre una frase de paso (*passphrase*) robusta a tus llaves privadas. Si la llave es extraviada o comprometida, la frase de paso otorga una ventana crítica para revocar los accesos antes de que un atacante pueda descifrarla.


Instalación de la Llave en el Servidor
=====================================

Método Automatizado (Recomendado)
---------------------------------
Utiliza la herramienta ``ssh-copy-id`` para transferir e instalar tu llave pública con los permisos adecuados:

.. code:: bash

    ssh-copy-id -i ~/.ssh/id_ed25519.pub usuario@mi-servidor.example.tld

Método Manual
-------------
Si necesitas configurar el acceso manualmente en el servidor:

.. code:: bash

    # Iniciar sesión en el servidor remoto
    ssh usuario@mi-servidor.example.tld

    # Ajustar máscara de creación para que solo el propietario tenga permisos
    umask 077

    # Crear directorio .ssh con permisos 700
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Agregar la llave pública al archivo authorized_keys con permisos 600
    cat << 'EOF' >> "$HOME/.ssh/authorized_keys"
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWo3RJ88qk1RS+P6b8U+rFJ1GpIxKvWW7AGrgiCx8dK usuario@estacion
    EOF
    chmod 600 "$HOME/.ssh/authorized_keys"

Prueba de Acceso
----------------
Abre una nueva terminal en tu estación de trabajo y verifica la conexión:

.. code:: bash

    ssh usuario@mi-servidor.example.tld

Si se configuró correctamente, iniciarás sesión autenticándote con la llave (y la frase de paso de la misma), sin solicitar la contraseña de la cuenta del servidor.


Aseguramiento (Hardening)
=========================
En **CentOS Stream 10** y **Fedora 44**, la configuración personalizada debe colocarse en archivos dentro del directorio ``/etc/ssh/sshd_config.d/``.

Crea el archivo ``/etc/ssh/sshd_config.d/01-seguridad.conf``:

```ssh-config:/howto/ssh/seguridad.conf```

.. warning::

    Antes de desactivar la autenticación por contraseña (``PasswordAuthentication no``) o restringir usuarios con ``AllowUsers``, asegúrate de haber verificado exitosamente el acceso por llave en una sesión paralela para evitar quedar incomunicado.


Servicios y Firewall
====================

```bash:/howto/ssh/servicios.bash```


Verificación y Pruebas
======================
Procedimientos para validar el correcto funcionamiento y la postura de seguridad de OpenSSH:

1. **Validación de la sintaxis de configuración**:

   Antes de reiniciar el servicio tras cambios en ``/etc/ssh/sshd_config.d/``, verifica que no existan errores sintácticos:

   .. code:: bash

      sshd -t

2. **Estado del servicio y socket en systemd**:

   Comprueba que el demonio esté activo y escuchando en el puerto TCP 22:

   .. code:: bash

      # Comprobar estado del servicio
      systemctl status sshd.service

      # Confirmar socket activo en el puerto 22
      ss -t4lnp | grep ':22\s'

3. **Prueba de autenticación no interactiva con llave**:

   Desde tu estación local, ejecuta una prueba automatizada en modo batch (no interactivo) para validar el intercambio de llaves:

   .. code:: bash

      # Probar autenticación por llave sin solicitar contraseña interactiva
      ssh -o BatchMode=yes -o ConnectTimeout=5 usuario@mi-servidor.example.tld echo "Acceso SSH autenticado exitosamente"

4. **Auditoría de huellas digitales de host (Host Keys)**:

   Comprueba las huellas públicas del servidor para verificar su identidad ante advertencias de *man-in-the-middle*:

   .. code:: bash

      # Obtener huella SHA-256 de la llave Ed25519 del host
      ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

5. **Monitoreo de bitácoras de autenticación**:

   .. code:: bash

      # Inspeccionar eventos recientes de conexión y autenticación en systemd
      journalctl -u sshd.service -e --no-pager


Problemática
============

Permisos incorrectos en directorio o archivos SSH
-------------------------------------------------
OpenSSH por defecto rechaza llaves si los permisos del directorio ``~/.ssh`` o del archivo ``authorized_keys`` son demasiado permisivos.

Corrige los permisos con:

.. code:: bash

    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/id_*
    chmod 644 ~/.ssh/*.pub

Contextos de SELinux
--------------------
Si el directorio ``~/.ssh`` o ``authorized_keys`` fue copiado o restaurado desde otro origen, SELinux puede bloquear el acceso:

.. code:: bash

    restorecon -Rv ~/.ssh

Depuración de Conexiones
------------------------
Para diagnosticar fallas de negociación criptográfica o rechazo de autenticación, ejecuta el cliente con nivel de detalle máximo:

.. code:: bash

    ssh -vvv usuario@mi-servidor.example.tld


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Manual oficial de OpenSSH: https://www.openssh.com/manual.html
