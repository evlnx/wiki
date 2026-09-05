============================================================================
Cortafuegos Perimetral e Interno con Firewalld: Zonas, Reglas Ricas e IPSets
============================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
Esta guía práctica y avanzada detalla la implementación de un cortafuegos perimetral e interno de nivel empresarial utilizando **firewalld** sobre el subsistema del núcleo de Linux **nftables** en **CentOS Stream 10** y **Fedora 44**.

Firewalld es el demonio de seguridad y filtrado dinámico de red estándar en distribuciones basadas en Red Hat Enterprise Linux y Fedora. A diferencia de las herramientas heredadas que requerían reiniciar o vaciar cadenas de filtrado completas, firewalld se comunica mediante el bus de mensajes del sistema (D-Bus) y compila las directivas en una tabla unificada del núcleo (``table inet firewalld``). Esta integración permite aplicar mutaciones atómicas a las reglas en tiempo de ejecución sin vaciar las tablas de seguimiento de conexiones (*conntrack*), evitando la desconexión o degradación de sesiones TCP/UDP activas durante las operaciones de mantenimiento.

Siguiendo una arquitectura de confianza cero (*Zero-Trust network boundaries*), esta guía aborda:

* **Zonas de seguridad segregadas**: Clasificación estricta de interfaces de red físicas y virtuales en dominios de confianza aislados, separando el perímetro externo expuesto a Internet (WAN) de las redes privadas y túneles seguros (LAN/VPN).
* **Reglas ricas (Rich Rules)**: Directivas de filtrado granular que combinan fuentes de red específicas, control de servicios y puertos, registro estructurado en el diario del sistema y limitación de tasa (*rate limiting*) contra ataques de denegación de servicio o sondeos automatizados.
* **Conjuntos de direcciones IP (IPSets)**: Estructuras hash optimizadas en el espacio de memoria del núcleo que permiten la evaluación en tiempo constante :math:`O(1)` de miles de prefijos o direcciones IP hostiles (*blocklists*) sin impacto perceptible en la latencia de conmutación de paquetes.
* **Traducción de direcciones de red (NAT)**: Enmascaramiento de salida (*masquerading/SNAT*) para dar salida a redes privadas y redirección de puertos perimetrales (*DNAT/port forwarding*) hacia servicios internos.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario administrativo (acceso mediante ``sudo``).
* Políticas de SELinux activas en modo restrictivo (**Enforcing**).
* Acceso a repositorios oficiales del sistema (BaseOS/AppStream en CentOS Stream 10 o fedora/updates en Fedora 44).
* Reenvío de paquetes IPv4 habilitado en el núcleo si el servidor realiza enrutamiento o enmascaramiento entre interfaces (``net.ipv4.ip_forward = 1``).


Instalación
===========
Firewalld y las herramientas complementarias para la gestión de conjuntos hash IP (*ipset*) se encuentran disponibles en los repositorios oficiales de **CentOS Stream 10** y **Fedora 44**.

Actualiza los metadatos de los repositorios e instala los paquetes requeridos mediante ``dnf``:

.. code:: bash

   # Actualizar metadatos e instalar firewalld junto a utilidades ipset
   sudo dnf -y install firewalld ipset


Configuración
=============
La administración de firewalld se organiza en dos capas de configuración complementarias:

* **Tiempo de ejecución (Runtime)**: Reglas activas cargadas en la memoria del núcleo mediante transacciones de ``libnftables``. Tienen efecto inmediato, pero se descartan si el servicio se reinicia o se recarga sin haberse consolidado.
* **Permanente (Permanent)**: Definiciones declarativas almacenadas en archivos XML en el directorio ``/etc/firewalld/``. Persisten a través de los reinicios del sistema y se compilan en el núcleo tras una recarga (``firewall-cmd --reload``).

Para ejecutar comandos en caliente mediante ``firewall-cmd``, el servicio ``firewalld.service`` debe encontrarse activo (ver sección posterior para su habilitación atómica). Si se realizan despliegues desatendidos o preparación de imágenes fuera de línea, es posible emplear ``firewall-offline-cmd`` para modificar directamente los archivos XML persistentes.

Inspección del Estado y Zonas Activas
-------------------------------------
Antes de modificar cualquier política de seguridad, es indispensable inspeccionar el estado actual del cortafuegos, la zona asignada por omisión y las zonas con interfaces vinculadas:

.. code:: bash

   # Comprobar el estado operativo del demonio
   sudo firewall-cmd --state

   # Consultar la zona predeterminada configurada en el sistema
   sudo firewall-cmd --get-default-zone

   # Listar las zonas activas y las interfaces o fuentes asociadas
   sudo firewall-cmd --get-active-zones

   # Inspeccionar detalladamente las directivas de la zona predeterminada
   sudo firewall-cmd --list-all

Asignación de Interfaces de Red a Zonas
---------------------------------------
En un entorno perimetral típico, el servidor dispone de al menos dos interfaces: una interfaz WAN externa (por ejemplo, ``eth0``) conectada a la red no confiable, y una interfaz de red interna o túnel VPN (por ejemplo, ``wg0``) que conecta la infraestructura privada.

Asigna la interfaz externa a la zona ``public`` y la interfaz interna a la zona ``internal``. Se recomienda utilizar el parámetro ``--change-interface`` con la bandera ``--permanent`` para reubicar adaptadores de manera atómica, evitando fallos de enlaces duplicados:

.. code:: bash

   # Asignar la interfaz WAN perimetral a la zona public
   sudo firewall-cmd --permanent --zone=public --change-interface=eth0

   # Asignar la interfaz VPN o LAN segura a la zona internal
   sudo firewall-cmd --permanent --zone=internal --change-interface=wg0

Gestión de Servicios y Puertos
------------------------------
Firewalld incluye definiciones de servicios en formato XML (almacenadas en ``/usr/lib/firewalld/services/``) que agrupan números de puerto, protocolos y módulos de seguimiento de conexiones (*conntrack helpers*).

En la zona perimetral ``public``, autoriza el servicio HTTPS estándar y un puerto TCP personalizado (por ejemplo, un puerto alternativo de gestión web en el puerto 8443):

.. code:: bash

   # Permitir el servicio HTTPS estándar (puerto 443/tcp) en la zona perimetral
   sudo firewall-cmd --permanent --zone=public --add-service=https

   # Permitir el puerto TCP personalizado 8443 en la zona perimetral
   sudo firewall-cmd --permanent --zone=public --add-port=8443/tcp

Reglas Ricas (Rich Rules) Avanzadas
-----------------------------------
Las reglas ricas (*Rich Rules*) permiten definir políticas de filtrado avanzadas mediante una sintaxis estructurada sin necesidad de manipular tablas de bajo nivel en nftables. Proporcionan control de origen, limitación de tasa (*rate limiting*) y registro en el diario del sistema con prefijos legibles para auditoría.

Autorizar el acceso SSH (puerto 22/tcp) exclusivamente desde una subred administrativa interna (``192.168.10.0/24``), registrando eventos informativos con un límite de 5 intentos por minuto:

.. code:: bash

   # Permitir SSH administrativo con registro informativo y limitación de tasa
   sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.10.0/24" service name="ssh" log prefix="FIREWALL_SSH: " level="info" limit value="5/m" accept'

Descartar silenciosamente y auditar el tráfico procedente de una subred de origen hostil (``198.51.100.0/24``), registrando advertencias con un límite de 5 eventos por minuto:

.. code:: bash

   # Registrar y descartar paquetes provenientes de una red hostil
   sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="198.51.100.0/24" log prefix="FIREWALL_DROP: " level="warning" limit value="5/m" drop'

Conjuntos de Direcciones IP (IPSets)
------------------------------------
Cuando se requiere gestionar cientos o miles de direcciones IP o bloques CIDR (como fuentes de inteligencia de amenazas o listas de reputación), las reglas ricas individuales degradan el rendimiento al crear cadenas lineales extensas. Los conjuntos IP (*IPSets*) utilizan tablas hash en memoria del núcleo que realizan comparaciones en tiempo constante :math:`O(1)`.

Crea un conjunto IP permanente de tipo red (``hash:net``) para direcciones IPv4:

.. code:: bash

   # Crear conjunto IP persistente optimizado para subredes IPv4
   sudo firewall-cmd --permanent --new-ipset=blocklist --type=hash:net --option=family=inet --option=maxelem=100000

Agrega los bloques CIDR que deben ser bloqueados de forma permanente:

.. code:: bash

   # Agregar rangos de red a la lista de bloqueo permanente
   sudo firewall-cmd --permanent --ipset=blocklist --add-entry=198.51.100.0/24
   sudo firewall-cmd --permanent --ipset=blocklist --add-entry=203.0.113.0/24

Vincula el conjunto IP a la zona perimetral mediante una regla rica que descarte inmediatamente el tráfico coincidente:

.. code:: bash

   # Descartar cualquier tráfico cuyo origen coincida con el ipset blocklist
   sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule source ipset="blocklist" drop'

Para agregar direcciones de forma dinámica en caliente sin necesidad de recargar el cortafuegos:

.. code:: bash

   # Agregar una entrada en caliente a la tabla hash del núcleo
   sudo firewall-cmd --ipset=blocklist --add-entry=192.0.2.100

Enmascaramiento (Masquerading) y Redirección de Puertos
-------------------------------------------------------
En escenarios donde el host actúa como enrutador perimetral o pasarela (*gateway*), se configuran mecanismos de traducción de direcciones de red (NAT):

* **Enmascaramiento (SNAT/Masquerade)**: Permite que equipos o contenedores en redes privadas salgan a Internet utilizando la dirección IP pública del cortafuegos.
* **Redirección de puertos (DNAT/Port Forwarding)**: Redirige tráfico entrante en un puerto perimetral hacia otro puerto local o hacia una dirección IP interna.

Habilitar el enmascaramiento de salida en la zona perimetral ``public``:

.. code:: bash

   # Habilitar enmascaramiento en la zona pública
   sudo firewall-cmd --permanent --zone=public --add-masquerade

Asegura que el reenvío de paquetes IPv4 esté habilitado de forma permanente en los parámetros del núcleo de Linux:

.. code:: bash

   # Habilitar reenvío de paquetes en el archivo de configuración sysctl
   echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-ipforward.conf
   sudo sysctl --system

Configurar la redirección de puertos (*DNAT*) para capturar conexiones dirigidas al puerto 443 público y reenviarlas al puerto 8443 de un servidor interno en la dirección ``10.0.10.5``:

.. code:: bash

   # Redirigir el puerto 443 WAN hacia el host interno 10.0.10.5 en el puerto 8443
   sudo firewall-cmd --permanent --zone=public --add-forward-port=port=443:proto=tcp:toport=8443:toaddr=10.0.10.5

Para redirigir tráfico entre puertos dentro del mismo servidor local (por ejemplo, del puerto 80 al 8080 local):

.. code:: bash

   # Redirigir puerto local 80 hacia el puerto local 8080
   sudo firewall-cmd --permanent --zone=public --add-forward-port=port=80:proto=tcp:toport=8080

Aplicación y Persistencia de Cambios
------------------------------------
Todas las modificaciones configuradas con la bandera ``--permanent`` se graban en los archivos XML del sistema dentro de ``/etc/firewalld/``, pero no se inyectan en el núcleo hasta que el demonio procesa una recarga de configuración.

Aplica los cambios de manera segura y sin corte de servicio ejecutando ``firewall-cmd --reload``:

.. code:: bash

   # Recargar configuración permanente preservando sesiones activas
   sudo firewall-cmd --reload

.. note::

   El comando ``firewall-cmd --reload`` compila las transacciones atómicamente a través de ``libnftables`` y preserva las tablas de seguimiento de conexiones (*conntrack*). No ejecutes ``--complete-reload`` en producción, ya que dicho modificador vacía las tablas de seguimiento de estado del núcleo y desconecta todas las sesiones TCP activas.


Habilitación e Inicio de Servicios
==================================
Siempre habilita e inicia los servicios del sistema de manera atómica con ``systemctl enable --now`` para asegurar su arranque inmediato y su activación automática tras cada reinicio del equipo:

.. code:: bash

   # Habilitar el arranque en el inicio y arrancar inmediatamente el servicio
   sudo systemctl enable --now firewalld.service

Verifica que el servicio se encuentre activo, en ejecución y supervisado correctamente por systemd:

.. code:: bash

   # Inspeccionar el estado operativo de la unidad systemd
   sudo systemctl status firewalld.service --no-pager


Verificación y Pruebas
======================
Finalizada la aplicación de reglas, es indispensable verificar la coherencia de la configuración en firewalld, comprobar las estructuras compiladas en el núcleo mediante nftables y validar el comportamiento de los puertos desde equipos remotos.

Inspección de Configuración Activa en Firewalld
-----------------------------------------------
Inspecciona detalladamente la configuración activa de la zona perimetral para confirmar que los servicios, puertos, enmascaramiento, reglas ricas e interfaces estén aplicados:

.. code:: bash

   # Verificar directivas activas en la zona public
   sudo firewall-cmd --list-all --zone=public

Inspecciona la configuración activa de la zona interna:

.. code:: bash

   # Verificar directivas activas en la zona internal
   sudo firewall-cmd --list-all --zone=internal

Consulta las entradas activas cargadas en el conjunto hash ``blocklist``:

.. code:: bash

   # Consultar los prefijos CIDR cargados en el conjunto IP
   sudo firewall-cmd --ipset=blocklist --get-entries

Inspección del Backend Nftables en el Núcleo
--------------------------------------------
Dado que firewalld opera como capa de abstracción sobre nftables, es posible examinar directamente las estructuras y cadenas inyectadas en el núcleo con el comando ``nft``:

.. code:: bash

   # Inspeccionar el conjunto completo de reglas netfilter/nftables en el núcleo
   sudo nft list ruleset

   # Listar la tabla unificada inet administrada por firewalld
   sudo nft list table inet firewalld

   # Inspeccionar la cadena de filtrado de entrada (filter_INPUT)
   sudo nft list chain inet firewalld filter_INPUT

   # Inspeccionar la estructura del conjunto hash en el núcleo
   sudo nft list set inet firewalld blocklist

Validación de Conectividad con Nmap y Netcat
--------------------------------------------
Desde una estación de trabajo remota o equipo de pruebas en la red perimetral, valida la disponibilidad de los servicios permitidos y el descarte de los puertos restringidos:

.. code:: bash

   # Probar la conectividad hacia el puerto seguro 443 con netcat
   nc -zv 198.51.100.10 443

   # Escanear los puertos administrados para validar su estado de filtrado
   nmap -sS -Pn -p 22,80,443,8443 198.51.100.10

Comprobar que una dirección IP perteneciente al bloque del ipset ``blocklist`` experimente un descarte silencioso sin respuestas de rechazo (RST):

.. code:: bash

   # Debe expirar por límite de tiempo (timeout) sin rechazo explícito
   nc -zv 198.51.100.10 443 -w 3


Problemática
============

Pérdida de Acceso Remoto SSH y Mecanismos de Recuperación
---------------------------------------------------------
Al reconfigurar la zona perimetral o modificar políticas de filtrado globales, un error de sintaxis o una omisión de puerto puede revocar el acceso administrativo SSH remoto (puerto 22/tcp).

Para mitigar este riesgo y recuperar el acceso, implementa las siguientes prácticas:

#. **Pruebas en tiempo de ejecución**:
   Aplica directivas críticas omitiendo el parámetro ``--permanent``. Si la nueva regla te desconecta, un reinicio del servicio o del servidor devolverá el estado a la última configuración permanente guardada.

#. **Temporizador de recarga de seguridad**:
   Antes de aplicar modificaciones en un servidor remoto sin acceso fuera de banda, programa una reversión automática en segundo plano:

   .. code:: bash

      # Programar una recarga de seguridad que revertirá cambios temporales en 3 minutos
      (sleep 180 && sudo firewall-cmd --reload) &

#. **Recuperación fuera de línea con firewall-offline-cmd**:
   Si el acceso remoto se interrumpió y únicamente se dispone de consola de emergencia/rescate local donde el demonio no puede comunicar por D-Bus, modifica directamente la configuración en disco:

   .. code:: bash

      # Autorizar permanentemente el servicio SSH sin requerir el demonio activo
      sudo firewall-offline-cmd --zone=public --add-service=ssh

Omisión del Cortafuegos por Motores de Contenedores (Docker/Podman)
-------------------------------------------------------------------
La interacción entre motores de contenedores y firewalld representa un riesgo de seguridad crítico en entornos de producción:

* **Docker**: Por diseño, el demonio Docker inyecta reglas de traducción de direcciones de destino (DNAT) directamente en las cadenas de netfilter en la fase ``PREROUTING``. Esto ocasiona que cualquier puerto publicado (por ejemplo, ``docker run -p 8080:80 ...``) sea accesible públicamente en la interfaz de red, omitiendo completamente las restricciones de zona configuradas en firewalld.

  Para forzar a Docker a respetar las directivas del cortafuegos en CentOS Stream 10 y Fedora 44, deshabilita la manipulación de iptables en ``/etc/docker/daemon.json``:

  .. code:: json

     {
       "iptables": false
     }

* **Podman**: Como motor de contenedores nativo en CentOS Stream 10 y Fedora 44, Podman está diseñado sin demonio central (*daemonless*). En entornos sin privilegios (*rootless*), aísla el tráfico de red mediante herramientas de espacio de nombres de usuario como ``pasta`` o ``slirp4netns``, respetando estrictamente las zonas de firewalld.

  Adicionalmente, se recomienda asegurar la exclusividad de las reglas en ``/etc/firewalld/firewalld.conf`` activando la propiedad de tabla nftables:

  .. code:: ini

     # Bloquear la tabla inet firewalld contra escrituras de procesos externos
     NftablesTableOwner = yes

Errores de Sintaxis XML y Fallas al Recargar el Demonio
-------------------------------------------------------
Cuando se modifican manualmente los archivos XML en ``/etc/firewalld/zones/``, ``/etc/firewalld/services/`` o ``/etc/firewalld/ipsets/``, la introducción de etiquetas no balanceadas, espacios ilegales o atributos no definidos en el esquema provoca fallas al ejecutar ``firewall-cmd --reload`` o durante el arranque del servicio.

Antes de solicitar la recarga de reglas, valida la sintaxis y conformidad de todos los archivos XML locales contra sus esquemas XSD oficiales:

.. code:: bash

   # Validar la sintaxis de todos los archivos XML de configuración
   sudo firewall-cmd --check-config

En caso de que el servicio falle o el comando de recarga devuelva error, consulta la bitácora del sistema:

.. code:: bash

   # Inspeccionar los registros de error emitidos por firewalld en journald
   sudo journalctl -u firewalld.service -e --no-pager

Bloqueos de Políticas de SELinux (Permission Denied)
----------------------------------------------------
En CentOS Stream 10 y Fedora 44 con SELinux en modo Enforcing, el demonio firewalld opera confinado en el dominio ``firewalld_t``. Si se introducen listas de direcciones, scripts de ayuda o archivos XML copiados desde directorios no estándar (como carpetas de usuario con etiqueta ``user_home_t`` o directorios temporales ``tmp_t``), SELinux bloqueará su lectura:

.. code:: bash

   # Inspeccionar denegaciones de SELinux recientes asociadas a firewalld
   sudo ausearch -m avc -c firewalld -ts recent

   # Restaurar contextos predeterminados en el árbol de configuración de firewalld
   sudo restorecon -Rv /etc/firewalld


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10: `Configuring firewalls and packet filtering <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_firewalls_and_packet_filtering/index>`__
* Guía de cortafuegos de Fedora Project: `Fedora Quick Docs: Firewalld <https://docs.fedoraproject.org/en-US/quick-docs/firewalld/>`__
* Sitio oficial y documentación de Firewalld: `Firewalld Documentation Index <https://firewalld.org/documentation/>`__
* Sintaxis y gramática de Reglas Ricas: `Firewalld Rich Language Reference <https://firewalld.org/documentation/man-pages/firewalld.richlanguage.html>`__
* Subredes y conjuntos hash en nftables: `Netfilter and Nftables Documentation <https://netfilter.org/projects/nftables/>`__
