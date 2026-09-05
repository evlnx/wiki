=======================================================
Redes Seguras y VPN Mesh con WireGuard y NetworkManager
=======================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
WireGuard es una solución de red privada virtual (VPN) moderna, segura y de alto rendimiento que opera directamente en el espacio de kernel de Linux. Diseñado como un reemplazo integral y simplificado para protocolos legados como IPsec y OpenVPN, WireGuard minimiza radicalmente la superficie de ataque y elimina la sobrecarga de procesamiento derivada de cambios de contexto frecuentes entre el espacio de kernel y el espacio de usuario.

A diferencia de implementaciones tradicionales que negocian complejas suites criptográficas, WireGuard aplica una disciplina estricta basada en el protocolo Noise:

* Criptografía asimétrica mediante curvas elípticas Curve25519 para intercambio autenticado de llaves (ECDH).
* Cifrado de flujo autenticado mediante ChaCha20 y Poly1305 (AEAD).
* Funciones de hash criptográfico de alta velocidad mediante BLAKE2s.
* Claves de tabla hash protegidas contra ataques de denegación de servicio con SipHash24.

El pilar arquitectónico de WireGuard es el enrutamiento por llave criptográfica (*Cryptokey Routing*): cada nodo remoto (*peer*) se asocia de forma determinista y estricta a una llave pública Curve25519 y a una lista explícita de direcciones IP permitidas (``allowed-ips``). Cuando el kernel despacha un paquete hacia la interfaz WireGuard, examina la dirección de destino, localiza la llave pública correspondiente en la tabla interna de enrutamiento criptográfico, cifra el paquete y lo encapsula en un datagrama UDP enviado directamente al *endpoint* de red configurado. A la inversa, al recibir un paquete UDP autenticado, el kernel valida que la dirección IP de origen coincida con las direcciones autorizadas para la llave pública del remitente antes de desencapsular el tráfico hacia la pila TCP/IP local.

En **CentOS Stream 10** y **Fedora 44**, el soporte de WireGuard está incorporado nativamente en el kernel Linux (*in-tree*). Asimismo, NetworkManager 1.56+ proporciona gestión declarativa completa para túneles WireGuard mediante perfiles en formato keyfile (archivos ``.nmconnection``) almacenados en ``/etc/NetworkManager/system-connections/``. Esta integración permite coordinar interfaces mediante ``nmcli``, garantizar persistencia automática tras reinicios, orquestar topologías punto a punto, estrella (*hub-and-spoke*) o malla distribuida (*full mesh*), y delegar la resolución de nombres DNS divididos (*split DNS*) a ``systemd-resolved`` sin depender de utilidades auxiliares en espacio de usuario como ``wg-quick``.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario administrativo (acceso mediante ``sudo``).
* SELinux activo en modo estricto (``Enforcing``).
* Kernel Linux con soporte nativo de WireGuard (módulo ``wireguard`` incorporado por defecto en la distribución).
* Servicio NetworkManager activo y gestionando la conectividad del sistema.
* Puerto UDP de escucha accesible a través de enrutadores o proveedores de nube (por omisión: ``51820/udp``).


Instalación
===========
En CentOS Stream 10 y Fedora 44, los módulos de kernel de WireGuard forman parte del paquete base del kernel. Para la administración del túnel se requieren las herramientas de línea de comandos de WireGuard y el cliente de control de NetworkManager:

.. code:: bash

   # Actualizar metadatos e instalar paquetes requeridos
   dnf -y install wireguard-tools NetworkManager

Verificar que el módulo de kernel de WireGuard esté disponible y pueda cargarse en memoria:

.. code:: bash

   # Cargar módulo de kernel wireguard
   modprobe wireguard

   # Confirmar carga exitosa en el árbol del kernel
   lsmod | grep wireguard


Configuración
=============
La arquitectura de WireGuard se fundamenta en un esquema de confianza simétrica entre pares. A continuación, se detalla la preparación de credenciales criptográficas, la creación del perfil declarativo en NetworkManager, la inspección del keyfile resultante y la activación del enrutamiento IP en el kernel.

Generación de Llaves Criptográficas
-----------------------------------
Cada nodo de la red VPN genera su propio par de llaves Curve25519 (privada y pública). De manera complementaria, se recomienda generar una llave precompartida (*Pre-Shared Key* o PSK) para dotar al túnel de una capa de cifrado simétrico adicional resistente a eventuales ataques criptoanalíticos post-cuánticos.

Crea un directorio protegido bajo control estricto de ``root`` para salvaguardar las llaves:

.. code:: bash

   # Crear directorio de trabajo con permisos restrictivos
   mkdir -p /etc/wireguard/keys
   chmod 0700 /etc/wireguard/keys
   cd /etc/wireguard/keys
   umask 077

   # Generar llave privada local y derivar inmediatamente la llave pública correspondiente
   wg genkey | tee privatekey | wg pubkey > publickey

   # Generar llave precompartida (PSK) para añadir resistencia post-cuántica
   wg genpsk > preshared.key

   # Asegurar permisos estrictos de solo lectura para superusuario
   chmod 0600 privatekey preshared.key
   chmod 0644 publickey

.. note::
   La llave privada (``privatekey``) y la llave precompartida (``preshared.key``) jamás deben transmitirse por canales inseguros. Únicamente la llave pública (``publickey``) debe compartirse con los nodos remotos.

Creación del Perfil de Conexión con NetworkManager
--------------------------------------------------
NetworkManager gestiona interfaces WireGuard mediante perfiles declarativos. En este escenario de producción, se configura el nodo local con la interfaz ``wg0``, dirección de túnel ``10.100.0.1/24`` y puerto de escucha ``51820/udp``. Se asocia a un nodo par remoto con dirección de túnel ``10.100.0.2/32`` accesible en el endpoint público ``remote.example.com:51820``.

#. **Crear el perfil base de conexión tipo wireguard**:

   .. code:: bash

      nmcli connection add type wireguard con-name wg0 ifname wg0 ip4 10.100.0.1/24

#. **Configurar el puerto de escucha UDP**:

   .. code:: bash

      nmcli connection modify wg0 wireguard.listen-port 51820

#. **Asignar la llave privada del nodo local**:

   La bandera ``wireguard.private-key-flags 0`` le indica a NetworkManager que el secreto se almacena en texto plano dentro del keyfile persistente protegido por permisos del sistema:

   .. code:: bash

      nmcli connection modify wg0 wireguard.private-key-flags 0 wireguard.private-key "$(cat /etc/wireguard/keys/privatekey)"

#. **Registrar el nodo remoto (peer)**:

   Asignar la llave pública remota, la dirección de transporte (*endpoint*) y las subredes autorizadas (*allowed-ips*). Opcionalmente se incorpora la llave PSK:

   .. code:: bash

      nmcli connection modify wg0 +wireguard.peers "public-key=$(cat /path/to/remote_publickey), allowed-ips=10.100.0.2/32, endpoint=remote.example.com:51820, preshared-key-flags=0, preshared-key=$(cat /etc/wireguard/keys/preshared.key)"

   .. tip::
      Para incorporar múltiples nodos y formar una topología en malla (*mesh*), repite la directiva ``+wireguard.peers`` por cada nodo participante especificando su respectiva llave pública y subred autorizada.

Inspección del Keyfile Declarativo
----------------------------------
NetworkManager materializa el perfil en el archivo ``/etc/NetworkManager/system-connections/wg0.nmconnection`` utilizando sintaxis estándar INI.

Inspecciona el contenido generado:

.. code:: ini

   # Archivo: /etc/NetworkManager/system-connections/wg0.nmconnection
   [connection]
   id=wg0
   uuid=c1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c
   type=wireguard
   interface-name=wg0
   autoconnect=true

   [wireguard]
   listen-port=51820
   private-key=YXBzb2x1dGVseS1zZWN1cmUtcHJpdmF0ZS1rZXktZXhhbXBsZQ==
   private-key-flags=0
   peer-routes=true

   [wireguard-peer.cmVtb3RlLXB1YmxpYy1rZXktZXhhbXBsZS12YWx1ZQ==]
   endpoint=remote.example.com:51820
   allowed-ips=10.100.0.2/32;
   preshared-key=ZXhhbXBsZS1wcmVzaGFyZWQta2V5LXNlY3JldC12YWx1ZQ==
   preshared-key-flags=0

   [ipv4]
   address1=10.100.0.1/24
   method=manual

   [ipv6]
   method=disabled

Verifica que el archivo posea propiedad de ``root:root`` y permisos estrictos ``0600``:

.. code:: bash

   ls -l /etc/NetworkManager/system-connections/wg0.nmconnection

.. important::
   NetworkManager ignora de forma explícita cualquier keyfile cuyos permisos sean más permisivos que ``0600`` para impedir fugas de información confidencial hacia usuarios sin privilegios.

Enrutamiento y Reenvío de Paquetes en el Kernel
-----------------------------------------------
Si este nodo actúa como servidor central, pasarela de enlace (*gateway*) o enrutador entre sedes en una arquitectura en malla, el kernel de Linux debe autorizar el reenvío de paquetes entre interfaces:

Crea el archivo de configuración persistente para ``sysctl``:

.. code:: ini

   # Archivo: /etc/sysctl.d/99-wireguard.conf
   net.ipv4.ip_forward = 1
   net.ipv6.conf.all.forwarding = 1

Aplica inmediatamente las directivas en el kernel activo:

.. code:: bash

   # Cargar directivas de reenvío de paquetes
   sysctl -p /etc/sysctl.d/99-wireguard.conf


Habilitación e Inicio de Servicios
----------------------------------
Con el perfil registrado y el cortafuegos configurado, activa la interfaz WireGuard mediante ``nmcli``:

.. code:: bash

   # Activar la conexión WireGuard inmediatamente
   nmcli connection up wg0

   # Asegurar que la conexión inicie automáticamente tras cada arranque
   nmcli connection modify wg0 connection.autoconnect yes

   # Verificar que el servicio principal de NetworkManager esté activo
   systemctl status NetworkManager.service


Configuración de Cortafuegos y Red
----------------------------------
En CentOS Stream 10 y Fedora 44, el cortafuegos del sistema es gestionado por ``firewalld``. La configuración requiere dos pasos fundamentales: abrir el puerto de escucha UDP en la zona externa para recibir paquetes cifrados, y asignar la interfaz lógica ``wg0`` a una zona de confianza para el tráfico interno desencapsulado.

#. **Abrir el puerto UDP del servicio en la zona activa (ej. ``public``)**:

   .. code:: bash

      firewall-cmd --permanent --zone=public --add-port=51820/udp

#. **Asignar la interfaz ``wg0`` a la zona confiable (``trusted``)**:

   Al asignar ``wg0`` a la zona ``trusted``, los paquetes ya validados y desencapsulados por el kernel pueden comunicarse con los servicios del host y atravesar rutas locales sin ser bloqueados por las políticas restrictivas de la zona pública:

   .. code:: bash

      firewall-cmd --permanent --zone=trusted --add-interface=wg0

#. **Habilitar enmascaramiento IP (opcional para nodos pasarela/gateway)**:

   Si el nodo enruta tráfico de los clientes hacia internet o subredes corporativas:

   .. code:: bash

      firewall-cmd --permanent --zone=public --add-masquerade

#. **Recargar y verificar la configuración de cortafuegos**:

   .. code:: bash

      # Aplicar cambios en caliente
      firewall-cmd --reload

      # Comprobar estado de la zona pública
      firewall-cmd --zone=public --list-all

      # Comprobar asignación de la interfaz wg0
      firewall-cmd --zone=trusted --list-interfaces


Verificación y Pruebas
======================
Valida el correcto establecimiento del túnel, la negociación de llaves y el flujo de paquetes mediante los siguientes procedimientos:

#. **Inspección de la interfaz y estado del handshake con ``wg``**:

   La herramienta oficial ``wg`` reporta el estado operativo del túnel en el espacio de kernel:

   .. code:: bash

      wg show wg0

   Salida esperada:

   .. code:: text

      interface: wg0
        public key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v=
        private key: (hidden)
        listening port: 51820

      peer: cmVtb3RlLXB1YmxpYy1rZXktZXhhbXBsZS12YWx1ZQ==
        preshared key: (hidden)
        endpoint: 198.51.100.25:51820
        allowed ips: 10.100.0.2/32
        latest handshake: 14 seconds ago
        transfer: 2.14 KiB received, 3.48 KiB sent

   .. important::
      La presencia de la directiva ``latest handshake`` (con valor inferior a 120 segundos) y un contador de ``transfer`` con bytes recibidos mayores a cero confirman que la autenticación mutua y el canal criptográfico Noise están operando correctamente. Si ``transfer`` muestra 0 bytes recibidos, el nodo remoto no está contestando o un cortafuegos intermedio descarta el tráfico UDP.

#. **Inspección del perfil en NetworkManager**:

   Verifica que NetworkManager reconozca la interfaz como activa y con los direccionamientos correctos:

   .. code:: bash

      # Inspeccionar detalles de la conexión en NetworkManager
      nmcli connection show wg0

      # Inspeccionar el enlace de red en el kernel
      ip addr show dev wg0

      # Confirmar las rutas locales asociadas al túnel
      ip route show dev wg0

#. **Prueba de conectividad ICMP a través del túnel**:

   Envía paquetes ICMP hacia la dirección IP privada del nodo remoto:

   .. code:: bash

      # Enviar 4 paquetes ICMP echo request al par remoto
      ping -c 4 10.100.0.2

   Probar la transmisión de paquetes con bandera "Don't Fragment" (DF) para validar la ruta sin fragmentación:

   .. code:: bash

      # Validar transporte con tamaño estándar de carga útil (1392 bytes + 28 bytes ICMP/IP = 1420 bytes)
      ping -c 4 -M do -s 1392 10.100.0.2


Problemática
============

Discrepancias de MTU y Fragmentación TCP (Black Hole)
-----------------------------------------------------
WireGuard encapsula paquetes IP dentro de datagramas UDP autenticados. Esta encapsulación añade una sobrecarga estricta de 60 bytes en conexiones IPv4 (20 bytes cabecera IPv4 + 8 bytes cabecera UDP + 32 bytes cabecera WireGuard) o de 80 bytes en IPv6. Si la interfaz física subyacente opera con una MTU estándar de 1500 bytes, cualquier paquete en el túnel con tamaño superior a 1420 bytes requiere fragmentación.

Si dispositivos de red intermedios descartan paquetes ICMP "Fragmentation Needed" (Path MTU Discovery Black Hole), las sesiones interactivas livianas (como ``ping``) funcionarán normalmente, pero transferencias pesadas (como conexiones SSH al emitir comandos interactivos o peticiones HTTP grandes) se congelarán indefinidamente tras la negociación inicial.

**Diagnóstico y mitigación**:

#. Configurar de forma explícita la MTU de la interfaz WireGuard a 1420 (o 1412 en líneas PPPoE con MTU base de 1492):

   .. code:: bash

      nmcli connection modify wg0 wireguard.mtu 1420
      nmcli connection up wg0

#. Aplicar MSS Clamping en el cortafuegos mediante ``firewalld`` para forzar a las conexiones TCP a negociar un tamaño máximo de segmento seguro:

   .. code:: bash

      # Activar MSS clamping en la zona pública
      firewall-cmd --permanent --zone=public --add-passthrough='nft add rule inet firewalld filter_FORWARD tcp flags syn tcp option maxseg size set rt mtu'
      firewall-cmd --reload

Handshake Criptográfico Ausente y Bloqueo de Cortafuegos
--------------------------------------------------------
WireGuard no responde a paquetes que no contengan una firma criptográfica Noise válida. Si un atacante o un escáner de puertos envía paquetes UDP al puerto 51820, el kernel descarta los paquetes silenciosamente sin devolver respuestas ICMP "Port Unreachable" ni respuestas TCP RST. Esta característica de diseño defensivo implica que si el handshake no se concreta, la interfaz permanecerá muda.

**Procedimiento de diagnóstico**:

#. Ejecutar ``wg show wg0`` y verificar si la línea ``latest handshake`` existe. Si no aparece o si el tiempo supera los 150 segundos, el intercambio inicial falló.
#. Verificar la coincidencia estricta de llaves cruzadas:
   * La llave pública remota configurada en el perfil local debe corresponder exactamente a la llave privada en uso en el nodo remoto.
   * La llave pública del nodo local debe estar configurada en la lista de peers del nodo remoto con la dirección ``10.100.0.1/32`` en sus ``allowed-ips``.
   * Si se empleó PSK, la cadena de ``preshared.key`` debe ser idéntica en ambos extremos.
#. Monitorear el tráfico UDP en tiempo real en la interfaz de red pública física (por ejemplo, ``eth0``):

   .. code:: bash

      tcpdump -nn -i eth0 udp port 51820

   Si se observan paquetes salientes pero ningún paquete entrante, el puerto UDP está bloqueado por el proveedor de alojamiento, el enrutador perimetral o las reglas de entrada de ``firewalld``.

Pérdida de Conectividad Detrás de NAT (NAT Traversal)
-----------------------------------------------------
Los enrutadores y cortafuegos stateful intermedios rastrean conexiones UDP mediante tablas de seguimiento de conexiones (*conntrack*). Debido a la naturaleza sin conexión de UDP, los cortafuegos eliminan las reglas de traducción de puertos si no detectan tráfico bidireccional tras un periodo de inactividad breve (típicamente de 30 a 120 segundos).

Si un nodo cliente se encuentra detrás de un enrutador NAT de oficina o red móvil sin dirección IP pública estática, el nodo servidor no podrá enviarle tráfico una vez que la entrada en la tabla NAT expire.

**Solución**:

Configurar el parámetro ``persistent-keepalive`` en el nodo cliente detrás de NAT. Este valor instruye a WireGuard a emitir un paquete autenticado vacío cada 25 segundos para mantener abierto el canal de comunicación en la tabla del enrutador intermedio:

.. code:: bash

   nmcli connection modify wg0 +wireguard.peers "public-key=<LLAVE_PUBLICA_SERVIDOR>, allowed-ips=10.100.0.0/24, endpoint=servidor.example.com:51820, persistent-keepalive=25"
   nmcli connection up wg0

Conflictos de Enrutamiento y Directivas AllowedIPs
--------------------------------------------------
El mecanismo de *Cryptokey Routing* valida dos condiciones: hacia qué par enviar un paquete según la tabla de subredes, y si un paquete entrante proviene de la dirección autorizada para ese par.

* **Falla por descarte interno (*Required key not available*)**: Si intentas enviar tráfico hacia una dirección IP que no se encuentra explícitamente declarada en la lista ``allowed-ips`` del peer, el kernel descarta el paquete a nivel local antes de enviarlo por la red. Para resolverlo, amplía el rango en ``allowed-ips``:

  .. code:: bash

     nmcli connection modify wg0 +wireguard.peers "public-key=<LLAVE_PUBLICA>, allowed-ips=10.100.0.0/24;192.168.50.0/24"

* **Bucle de enrutamiento al redirigir todo el tráfico (Default Route)**: Si se configura ``allowed-ips=0.0.0.0/0`` para redirigir la navegación completa por la VPN, NetworkManager reemplazará la ruta predeterminada del sistema. Si no existe una ruta de host estática hacia la dirección pública del *endpoint*, los paquetes UDP encapsulados de WireGuard intentarán viajar a través de la propia interfaz ``wg0``, provocando un colapso total de la conexión. Para escenarios de túnel completo, configura tablas de enrutamiento por políticas o asegúrate de que NetworkManager reserve la ruta hacia el endpoint físico mediante la opción ``wireguard.ip4-auto-default-route yes``.


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10: `Configuring and Managing Networking - Chapter: Configuring a WireGuard VPN <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_networking/configuring-a-wireguard-vpn_configuring-and-managing-networking>`_
* Documentación oficial de Fedora Project: `Fedora Networking Guide - WireGuard VPN <https://docs.fedoraproject.org/>`_
* Documentación oficial de CentOS Stream: `CentOS Stream Documentation <https://www.centos.org/centos-stream/>`_
* Especificación técnica y Whitepaper de WireGuard (Jason A. Donenfeld): `WireGuard: Next Generation Kernel Network Tunnel <https://www.wireguard.com/papers/wireguard.pdf>`_
* Documentación upstream del proyecto WireGuard: `WireGuard Homepage and Protocol Documentation <https://www.wireguard.com/>`_
* Referencia de perfiles de conexión de NetworkManager: `NetworkManager Settings and Keyfile Specification <https://networkmanager.dev/docs/api/latest/nm-settings-keyfile.html>`_
