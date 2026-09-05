==================================================================
Cifrado de Discos LUKS2 y Desbloqueo por Red (NBDE: Clevis y Tang)
==================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
Network-Bound Disk Encryption (NBDE) es una arquitectura de seguridad diseñada para desbloquear automáticamente volúmenes de almacenamiento cifrados mientras los equipos clientes permanezcan vinculados a una red corporativa de confianza. Esta tecnología combina el cifrado robusto de bloques del kernel Linux (**LUKS2**), el marco de descifrado automatizado del lado cliente **Clevis** y el servidor de atestación de presencia de red **Tang**.

En infraestructuras modernas de centros de datos, clústeres de virtualización y nubes híbridas basadas en **CentOS Stream 10** y **Fedora 44**, el reinicio desatendido de servidores con almacenamiento cifrado solía representar un grave obstáculo operacional: exigía ingresar manualmente frases de paso (*passphrases*) mediante consolas remotas KVM/IPMI tras cada actualización de kernel, o bien forzaba a los administradores a almacenar llaves simétricas en texto claro en el arranque temprano (*early boot*).

NBDE elimina por completo esta fricción mediante un protocolo criptográfico de intercambio Diffie-Hellman sobre curvas elípticas (RFC 7516/JSON Web Encryption). En este esquema, el servidor Tang opera como un oráculo de presencia apátrida (*stateless*): no requiere almacenar claves secretas de los clientes ni información transaccional de descifrado, protegiendo al servidor central contra filtraciones masivas de llaves.

A su vez, el marco Clevis soporta políticas avanzadas mediante el algoritmo de compartición secreta de Shamir (*Shamir Secret Sharing* o SSS). Con SSS es posible implementar esquemas de tolerancia a fallas de umbral $t$-de-$n$ (por ejemplo, permitir el desbloqueo automático si responde al menos 1 de 2 servidores Tang redundantes) o requerir la combinación multifactor de presencia de red (Tang) junto con la atestación de hardware local mediante chip criptográfico TPM 2.0.

Bajo este modelo, la protección de los datos en reposo (*data-at-rest*) permanece inalterada: si un disco físico o el servidor completo es sustraído físicamente de las instalaciones o desconectado del segmento de red seguro donde reside Tang, el volumen permanece totalmente sellado e indescifrable ante la imposibilidad de resolver la negociación criptográfica. Asimismo, cada volumen conserva una frase de paso manual de rescate para intervenciones de emergencia fuera de línea (*offline/air-gapped*).


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta root) en ambos equipos.
* Políticas de SELinux activas en modo Enforcing en ambos sistemas.
* Un servidor independiente en la red interna dedicado al rol de servidor de llaves **Tang** (en esta guía utilizaremos el FQDN resoluble ``tang.internal`` y la dirección IPv4 ``192.168.10.200``).
* Un equipo cliente con conectividad de red hacia el servidor Tang y un disco o partición secundaria para el aprovisionamiento de pruebas (en esta guía utilizaremos la partición ``/dev/sdb1`` de 10 GiB; el mismo método aplica a volúmenes lógicos LVM o al disco raíz del sistema).


Instalación de Paquetes
=======================
En CentOS Stream 10 y Fedora 44, los componentes de NBDE forman parte de los repositorios estándar de la distribución.

En el Servidor Tang
-------------------
Instalar el paquete del servidor de presencia de red:

.. code-block:: bash

   # Instalar el servidor Tang
   dnf -y install tang

En el Cliente (Host Cifrado)
----------------------------
Instalar el núcleo de Clevis, sus extensiones para LUKS, los módulos de integración con Dracut para el arranque temprano y las herramientas de systemd:

.. code-block:: bash

   # Instalar Clevis, soporte LUKS2, integración con Dracut y herramientas criptográficas
   dnf -y install clevis clevis-luks clevis-dracut clevis-systemd cryptsetup


Configuración
=============
El despliegue requiere configurar el demonio Tang en el servidor central y aprovisionar el enlace Clevis sobre el volumen LUKS2 en el cliente.

Configuración del Servidor Tang
-------------------------------
Tang utiliza la arquitectura de activación por socket (*socket activation*) de systemd mediante la unidad ``tangd.socket``. Aunque escucha de forma predeterminada en el puerto HTTP estándar (80/tcp), en entornos de infraestructura es habitual asignarle un puerto dedicado como ``8888/tcp`` para evitar conflictos con servidores web.

1. **Configurar el puerto de escucha personalizado en systemd**:
   Crear un archivo de configuración complementario (*drop-in*) en ``/etc/systemd/system/tangd.socket.d/port.conf``:

   .. code-block:: ini

      # Archivo: /etc/systemd/system/tangd.socket.d/port.conf
      [Socket]
      ListenStream=
      ListenStream=8888

2. **Ajustar el etiquetado de SELinux para el puerto 8888/tcp**:
   Con SELinux en modo Enforcing, es necesario asociar el nuevo puerto al contexto de red permitido:

   .. code-block:: bash

      # Asociar el puerto 8888/tcp con la etiqueta de servicio HTTP
      semanage port -a -t http_port_t -p tcp 8888

3. **Recargar systemd y activar el socket**:

   .. code-block:: bash

      # Recargar la configuración de systemd
      systemctl daemon-reload

      # Habilitar e iniciar inmediatamente el socket de Tang
      systemctl enable --now tangd.socket

4. **Verificar la publicidad y huellas digitales de las llaves**:
   Tang genera automáticamente sus pares de claves de firma y derivación JWK en ``/var/db/tang``. Inspeccionar las huellas digitales SHA-256 de las claves anunciadas:

   .. code-block:: bash

      # Obtener la huella digital SHA-256 de las llaves activas en el puerto 8888
      tang-show-keys 8888

   Comprobar la respuesta HTTP del servicio y la entrega del conjunto de claves públicas (*advertisement*):

   .. code-block:: bash

      # Validar la respuesta del endpoint de anuncio criptográfico
      curl -s http://tang.internal:8888/adv

Configuración de Cortafuegos y Red
----------------------------------
En el servidor Tang, autorizar el tráfico entrante hacia el puerto 8888/tcp en la zona activa de ``firewalld``:

.. code-block:: bash

   # Permitir permanentemente el puerto 8888/tcp
   firewall-cmd --permanent --add-port=8888/tcp

   # Aplicar la regla en caliente
   firewall-cmd --reload

   # Confirmar la apertura del puerto
   firewall-cmd --list-ports

Configuración del Cliente y Cifrado LUKS2
-----------------------------------------
En el nodo cliente, formatear el dispositivo de almacenamiento con formato LUKS2 y enlazar la clave de descifrado con la política de red de Tang.

1. **Formatear el volumen con formato LUKS2**:
   Inicializar la partición ``/dev/sdb1`` asignando una frase de paso manual de rescate (*passphrase*). Esta contraseña servirá de salvaguarda ante contingencias de red:

   .. code-block:: bash

      # Formatear el volumen con LUKS2, cifrado AES-XTS y función de derivación Argon2id
      cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha256 --pbkdf argon2id /dev/sdb1

2. **Vincular el volumen a Tang mediante Clevis**:
   Asociar el dispositivo al servidor Tang indicando su dirección de red. Durante este paso, Clevis contacta al servidor, recupera la clave de anuncio, solicita la frase de paso de rescate para autorizar la operación y genera un nuevo keyslot protegido por un token JWE:

   .. code-block:: bash

      # Vincular el volumen LUKS2 al servidor Tang
      clevis luks bind -d /dev/sdb1 tang '{"url":"http://tang.internal:8888"}'

   .. tip::
      Para mitigar posibles ataques de intermediario (*Man-in-the-Middle* o MitM) en redes no protegidas, declare explícitamente la huella digital (*thumbprint*) obtenida con ``tang-show-keys``:

      .. code-block:: bash

         # Vinculación estricta verificando la huella digital SHA-256 del servidor Tang
         clevis luks bind -d /dev/sdb1 tang '{"url":"http://tang.internal:8888","thp":"Plm3xK9_8wQq1zZ0y4N7j2Rt5vBn8m6Lk3p0Ws1q4E8"}'

3. **Configuración de alta disponibilidad con Shamir Secret Sharing (SSS)**:
   Si la infraestructura cuenta con dos servidores Tang redundantes (``tang1.internal:8888`` y ``tang2.internal:8888``), utilice el pin ``sss`` para configurar un umbral (*threshold*) de 1 de 2:

   .. code-block:: bash

      # Enlace con tolerancia a fallas: desbloquear si responde al menos uno de los dos servidores Tang
      clevis luks bind -d /dev/sdb1 sss '{"t":1,"pins":{"tang":[{"url":"http://tang1.internal:8888"},{"url":"http://tang2.internal:8888"}]}}'

4. **Configuración de /etc/crypttab con la opción _netdev**:
   Para volúmenes secundarios o de datos, el sistema de inicio debe postergar el descifrado hasta que el subsistema de red esté completamente operativo. Editar ``/etc/crypttab``:

   .. code-block:: ini

      # Archivo: /etc/crypttab
      # Identificador del dispositivo mapeado, ruta de bloque y opción de red
      data_storage /dev/sdb1 none _netdev

   .. note::
      En entornos de producción se recomienda utilizar el UUID del dispositivo en lugar de rutas dinámicas como ``/dev/sdb1``. Obtenga el UUID con ``blkid -s UUID -o value /dev/sdb1`` y defínalo como: ``data_storage UUID=3f4e2b1a-8c9d-4e5f-b1a2-9c8d7e6f5a4b none _netdev``.

   Crear el sistema de archivos (XFS o Ext4) en el volumen mapeado y declarar su montaje en ``/etc/fstab``:

   .. code-block:: bash

      # Abrir temporalmente el volumen para formatear el sistema de archivos
      clevis luks unlock -d /dev/sdb1 -n data_storage

      # Crear sistema de archivos XFS
      mkfs.xfs /dev/mapper/data_storage

      # Crear punto de montaje y cerrar el dispositivo de prueba
      mkdir -p /srv/data
      cryptsetup close data_storage

   Declarar el punto de montaje en ``/etc/fstab`` incluyendo la bandera ``_netdev``:

   .. code-block:: ini

      # Archivo: /etc/fstab
      /dev/mapper/data_storage /srv/data xfs defaults,_netdev 0 2

5. **Regeneración de initramfs para volúmenes raíz (root/boot)**:
   Si el volumen cifrado corresponde a la partición raíz (``/``) del sistema operativo, el descifrado debe llevarse a cabo dentro del initramfs antes de montar la raíz pivotante. Regenerar la imagen initramfs con Dracut:

   .. code-block:: bash

      # Regenerar todas las imágenes initramfs incorporando clevis y módulos de red
      dracut -fv --regenerate-all

Habilitación e Inicio de Servicios
----------------------------------
En el host cliente, habilitar e iniciar el servicio receptor de peticiones de contraseña de Clevis:

.. code-block:: bash

   # Habilitar e iniciar inmediatamente el listener de contraseñas de Clevis
   systemctl enable --now clevis-luks-askpass.path

Esta unidad monitorea las solicitudes generadas en ``/run/systemd/ask-password/``. Cuando ``systemd-cryptsetup@.service`` requiere la clave de un volumen marcado con ``_netdev`` durante el arranque, Clevis intercepta la petición, contacta al servidor Tang vía HTTP, resuelve el intercambio criptográfico y suministra la llave de descifrado a systemd en memoria volátil de forma instantánea.


Verificación y Pruebas
======================
Para validar la correcta operatividad y tolerancia a contingencias del despliegue NBDE, ejecutar los siguientes procedimientos:

1. **Inspección de metadatos LUKS2 y tokens de Clevis**:
   Comprobar que el volumen cuenta con el token registrado por Clevis:

   .. code-block:: bash

      # Volcar cabecera LUKS2 para verificar keyslots y tokens JWE
      cryptsetup luksDump /dev/sdb1

      # Listar los enlaces activos administrados por Clevis
      clevis luks list -d /dev/sdb1

2. **Prueba de descifrado manual bajo demanda**:
   Verificar que Clevis es capaz de resolver el intercambio con Tang y desbloquear el volumen:

   .. code-block:: bash

      # Desbloquear el dispositivo y mapearlo bajo el nombre data_storage
      clevis luks unlock -d /dev/sdb1 -n data_storage

      # Comprobar la creación del dispositivo mapeado
      ls -l /dev/mapper/data_storage

      # Cerrar el dispositivo mapeado
      cryptsetup close data_storage

3. **Prueba funcional del servicio systemd**:
   Comprobar que systemd desbloquea el volumen utilizando el generador automático de crypttab:

   .. code-block:: bash

      # Iniciar la unidad de servicio generada para el volumen
      systemctl start systemd-cryptsetup@data_storage.service

      # Consultar el estado operativo del servicio
      systemctl status systemd-cryptsetup@data_storage.service

      # Detener el servicio para cerrar el volumen
      systemctl stop systemd-cryptsetup@data_storage.service

4. **Simulación de aislamiento de red (Prueba de robo/aislamiento (Data-at-Rest))**:
   Simular la desconexión física del equipo o el robo del disco fuera del centro de datos deteniendo el socket de Tang:

   .. code-block:: bash

      # En el servidor Tang: detener temporalmente el socket
      systemctl stop tangd.socket

      # En el cliente: intentar el desbloqueo por red
      clevis luks unlock -d /dev/sdb1 -n data_storage

   La orden finalizará con un error de conexión o tiempo de espera agotado (*timeout*), impidiendo el acceso a los datos sin la frase de paso manual de rescate. Al reactivar el socket en el servidor Tang (``systemctl start tangd.socket``), el descifrado volverá a completarse satisfactoriamente.


Problemática
============

Retardo en la inicialización de red en initramfs (rd.neednet=1 e ip=dhcp)
-------------------------------------------------------------------------
Cuando la partición raíz (``/``) está cifrada con LUKS2 y vinculada a Tang, el initramfs puede intentar desbloquear el volumen antes de que la interfaz de red haya completado la negociación DHCP. Al fallar el contacto inicial con Tang, el arranque se detiene solicitando la contraseña de rescate por consola.

Para solucionar este comportamiento, instruir al kernel de Linux para que exija y configure la red antes de invocar los servicios de almacenamiento en el initramfs. Utilizar ``grubby``:

.. code-block:: bash

   # Forzar activación de red DHCP en initramfs para todos los kernels instalados
   grubby --update-kernel=ALL --args="rd.neednet=1 ip=dhcp"

Si el host opera con direccionamiento IP estático en lugar de DHCP, declarar la configuración correspondiente:

.. code-block:: bash

   # Sintaxis: ip=<ip-cliente>::<gateway>:<máscara>:<hostname>:<interfaz>:none
   grubby --update-kernel=ALL --args="rd.neednet=1 ip=192.168.10.50::192.168.10.1:255.255.255.0:client:eth0:none"

Ausencia de controladores de red en la imagen initramfs (dracut)
----------------------------------------------------------------
Si la imagen initramfs fue generada con la opción predeterminada ``hostonly="yes"`` de Dracut, es posible que no se hayan empaquetado los controladores de las interfaces de red físicas o los adaptadores virtuales (como ``virtio_net`` en máquinas virtuales KVM).

Para garantizar la inclusión de los controladores de red y el módulo de Clevis en cada generación, crear el archivo ``/etc/dracut.conf.d/clevis.conf``:

.. code-block:: ini

   # Archivo: /etc/dracut.conf.d/clevis.conf
   add_dracutmodules+=" clevis network "
   add_drivers+=" virtio_net e1000e r8169 "

Posteriormente, regenerar el initramfs:

.. code-block:: bash

   # Recompilar la imagen de arranque para el kernel activo
   dracut -fv --regenerate-all

Rotación de llaves Tang y actualización de enlaces (clevis luks regen/edit)
---------------------------------------------------------------------------
Por motivos de cumplimiento de seguridad, las claves maestras del servidor Tang deben rotarse periódicamente. En el servidor Tang, la rotación se lleva a cabo mediante el script:

.. code-block:: bash

   # En el servidor Tang: rotar llaves criptográficas
   /usr/libexec/tangd-rotate-keys

Este procedimiento renombra las llaves anteriores anteponiendo un punto (ej. ``.clave.jwk``) en el directorio ``/var/db/tang``. Las llaves ocultas continúan atendiendo peticiones de descifrado de volúmenes ya enlazados, pero quedan deshabilitadas para nuevos registros.

Para actualizar un cliente existente hacia las nuevas llaves publicitadas por Tang:

1. Identificar el número de slot utilizado por el enlace Clevis:

   .. code-block:: bash

      # Listar los slots asignados a Clevis
      clevis luks list -d /dev/sdb1

2. Regenerar el enlace para adoptar las nuevas claves del servidor Tang:

   .. code-block:: bash

      # Regenerar el enlace en el slot 1 sin modificar la frase de paso de rescate
      clevis luks regen -d /dev/sdb1 -s 1

3. Si el servidor Tang cambia de FQDN o dirección IP, actualizar el enlace con ``clevis luks edit``:

   .. code-block:: bash

      # Modificar la URL del servidor Tang en la configuración del slot 1
      clevis luks edit -d /dev/sdb1 -s 1 -c '{"url":"http://tang-nuevo.internal:8888"}'

4. Para revocar completamente el enlace de un dispositivo o slot:

   .. code-block:: bash

      # Desvincular Clevis del slot 1
      clevis luks unbind -d /dev/sdb1 -s 1

Bloqueos por SELinux (Permission Denied) y cortafuegos
------------------------------------------------------
Si el demonio Tang se configura en un puerto alternativo (como 8888/tcp) y SELinux bloquea la apertura del socket, el servicio fallará con errores de permisos denegados.

Inspeccionar las denegaciones en la bitácora de auditoría de SELinux:

.. code-block:: bash

   # Revisar denegaciones recientes de SELinux
   ausearch -m avc -ts recent

Corregir la política de puertos mediante ``semanage``:

.. code-block:: bash

   # Asignar el puerto 8888/tcp al contexto http_port_t
   semanage port -a -t http_port_t -p tcp 8888 || semanage port -m -t http_port_t -p tcp 8888

Si los clientes reportan tiempos de espera agotados al conectar con Tang, verificar las reglas de cortafuegos en el servidor:

.. code-block:: bash

   # Validar zonas activas e interfaces asociadas
   firewall-cmd --get-active-zones

   # Comprobar la apertura de puertos en la zona activa
   firewall-cmd --list-ports


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10: Security Hardening - Network-Bound Disk Encryption (NBDE): https://docs.redhat.com/
* Repositorio oficial del proyecto Clevis: https://github.com/latchset/clevis
* Repositorio oficial del proyecto Tang: https://github.com/latchset/tang
* Documentación oficial de Fedora: https://docs.fedoraproject.org/
* Documentación oficial de CentOS Stream: https://www.centos.org/centos-stream/
* Especificación IETF RFC 7516 (JSON Web Encryption - JWE): https://datatracker.ietf.org/doc/html/rfc7516
