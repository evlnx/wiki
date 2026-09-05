===================================================================
Autoridad Certificadora Interna (PKI): Emisión y Automatización TLS
===================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
Una Infraestructura de Llave Pública privada (*Private Public Key Infrastructure* o PKI) proporciona el fundamento criptográfico de identidad, autenticación y cifrado en tránsito para arquitecturas modernas de microservicios, clústeres de cómputo, almacenes de datos y sistemas de control en **CentOS Stream 10** y **Fedora 44**. En entornos de red interna (como dominios corporativos ``.internal`` o direccionamiento RFC 1918), no es factible ni seguro depender de Autoridades Certificadoras públicas mediante retos ACME externos. La implementación de una PKI institucional soberana permite gobernar de extremo a extremo la emisión, delegación y revocación de certificados X.509 v3.

Esta guía implementa una arquitectura jerárquica de dos niveles (*two-tier CA hierarchy*):

* **Autoridad Certificadora Raíz (Root CA)**: Constituye el ancla de confianza absoluta (*trust anchor*) de la organización. Por razones operativas y de seguridad, la llave privada de la Root CA se mantiene estrictamente aislada y fuera de línea (*offline/air-gapped*), empleándose con una vigencia prolongada (10 años) exclusivamente para firmar Autoridades Intermedias y Listas de Revocación de Certificados (CRL).

* **Autoridad Certificadora Intermedia o Emisora (Intermediate/Issuing Sub-CA)**: Instancia subordinada delegada que gestiona la carga de trabajo operativa cotidiana. Firma certificados finales para servidores, servicios de red y clientes mTLS. Su certificado está restringido de forma estricta mediante la restricción básica ``pathlen:0`` (RFC 5280), impidiendo criptográficamente que pueda crear autoridades subordinadas adicionales y delimitando con precisión el radio de impacto (*blast radius*) en caso de compromiso.

* **Cifrado en Tránsito y Autenticación Mutua (mTLS)**: El protocolo Mutual TLS asegura que tanto el servidor como el cliente validen recíprocamente sus identidades criptográficas antes de negociar parámetros de sesión en TLS 1.3, eliminando vectores de suplantación y ataques de intermediario (*man-in-the-middle*).

* **Extensiones X.509 v3 y Cumplimiento Obligatorio de SAN (RFC 2818)**: Toda entidad emisora y final cumple rigurosamente con los perfiles del estándar IETF RFC 5280. De acuerdo con el estándar IETF RFC 2818, el campo heredado ``Common Name`` (CN) del Subject está formalmente obsoleto para la validación de nombres de host en clientes modernos (Go, Rust, cURL, navegadores web); la especificación de Nombres Alternativos del Sujeto (*Subject Alternative Name* o SAN) es mandataria mediante directivas ``DNS:`` e ``IP:``.

* **Seguridad Criptográfica y Llaves Privadas**: Se aplican estándares rigurosos de protección: algoritmos de Curvas Elípticas modernas (ECDSA con la curva NIST P-256/``prime256v1``) como estándar principal por su eficiencia computacional y tamaño reducido, o RSA de 4096 bits como alternativa para compatibilidad legada. Las llaves privadas se resguardan bajo permisos POSIX ``0600`` y directorios ``0700``, con contextos de SELinux aplicados en modo Enforcing e integración con las políticas criptográficas globales del sistema (*crypto-policies*).


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta root).
* Políticas de SELinux en modo ``Enforcing`` activas en el sistema.
* Políticas criptográficas globales del sistema en perfil compatible (``DEFAULT`` o ``FUTURE``):

   .. code-block:: bash

      update-crypto-policies --show

* Herramientas de administración criptográfica instaladas: ``openssl`` (OpenSSL 3.x), ``ca-certificates`` y ``gnutls-utils`` (utilidad ``certtool``).
* Resolución de nombres interna operativa (mediante BIND 9 institucional o entradas en ``/etc/hosts``).


Instalación
===========
En CentOS Stream 10 y Fedora 44, las herramientas requeridas provienen directamente de los repositorios oficiales de la distribución gestionados mediante ``dnf``:

.. code-block:: bash

   # Actualizar metadatos e instalar paquetes base de criptografía
   dnf -y install openssl ca-certificates gnutls-utils

Verifica las versiones instaladas en el sistema para confirmar la compatibilidad con OpenSSL 3.x:

.. code-block:: bash

   # Comprobar versión de OpenSSL y proveedores criptográficos
   openssl version
   openssl list -providers

   # Comprobar versión de certtool
   certtool --version | head -n 1


Configuración
=============
La infraestructura de clave pública se divide en dos planos: la Autoridad Raíz (diseñada para ser resguardada de forma protegida) y la Autoridad Intermedia emisora de certificados de servicios y usuarios.

Estructura de Directorios y Permisos FHS
----------------------------------------
Se establece una jerarquía de directorios estandarizada conforme a FHS bajo el directorio ``/etc/pki/EVALinuxCA/``. La segregación incluye directorios dedicados para certificados emitidos (``certs``), listas de revocación (``crl``), nuevas emisiones de auditoría (``newcerts``), solicitudes de firma (``csr``) y almacenamiento exclusivo de llaves privadas protegidas (``private``):

.. code-block:: bash

   # Crear estructura de directorios para la Root CA
   mkdir -p /etc/pki/EVALinuxCA/{certs,crl,newcerts,private}

   # Crear estructura de directorios para la Intermediate Sub-CA
   mkdir -p /etc/pki/EVALinuxCA/intermediate/{certs,crl,csr,newcerts,private}

   # Aplicar permisos restrictivos a directorios de llaves privadas
   chmod 0700 /etc/pki/EVALinuxCA/private
   chmod 0700 /etc/pki/EVALinuxCA/intermediate/private

   # Inicializar bases de datos de seguimiento y números de serie
   touch /etc/pki/EVALinuxCA/index.txt
   echo 1000 > /etc/pki/EVALinuxCA/serial
   echo 1000 > /etc/pki/EVALinuxCA/crlnumber

   touch /etc/pki/EVALinuxCA/intermediate/index.txt
   echo 1000 > /etc/pki/EVALinuxCA/intermediate/serial
   echo 1000 > /etc/pki/EVALinuxCA/intermediate/crlnumber

Configuración de la CA Raíz (Root CA)
-------------------------------------
Crea el archivo de configuración ``/etc/pki/EVALinuxCA/openssl-root.cnf``. Este archivo define las políticas estrictas de emisión, los extensiones X.509 v3 para la propia Root CA y la extensión crítica con ``pathlen:0`` para las autoridades subordinadas:

.. code-block:: ini

   # Archivo: /etc/pki/EVALinuxCA/openssl-root.cnf
   [ ca ]
   default_ca = CA_default

   [ CA_default ]
   dir               = /etc/pki/EVALinuxCA
   certs             = $dir/certs
   crl_dir           = $dir/crl
   new_certs_dir     = $dir/newcerts
   database          = $dir/index.txt
   serial            = $dir/serial
   RANDFILE          = $dir/private/.rand

   private_key       = $dir/private/rootca.key.pem
   certificate       = $dir/certs/rootca.cert.pem

   crlnumber         = $dir/crlnumber
   crl               = $dir/crl/rootca.crl.pem
   crl_extensions    = crl_ext
   default_crl_days  = 30

   default_md        = sha256
   name_opt          = ca_default
   cert_opt          = ca_default
   default_days      = 3650
   preserve          = no
   policy            = policy_strict

   [ policy_strict ]
   countryName             = match
   stateOrProvinceName     = match
   organizationName        = match
   organizationalUnitName  = optional
   commonName              = supplied
   emailAddress            = optional

   [ req ]
   default_bits        = 4096
   distinguished_name  = req_distinguished_name
   string_mask         = utf8only
   default_md          = sha256
   x509_extensions     = v3_ca

   [ req_distinguished_name ]
   countryName                     = Country Name (2 letter code)
   stateOrProvinceName             = State or Province Name
   localityName                    = Locality Name
   0.organizationName              = Organization Name
   organizationalUnitName          = Organizational Unit Name
   commonName                      = Common Name
   emailAddress                    = Email Address

   [ v3_ca ]
   subjectKeyIdentifier   = hash
   authorityKeyIdentifier = keyid:always,issuer
   basicConstraints       = critical, CA:TRUE
   keyUsage               = critical, digitalSignature, cRLSign, keyCertSign

   [ v3_intermediate_ca ]
   subjectKeyIdentifier   = hash
   authorityKeyIdentifier = keyid:always,issuer
   basicConstraints       = critical, CA:TRUE, pathlen:0
   keyUsage               = critical, digitalSignature, cRLSign, keyCertSign

   [ crl_ext ]
   authorityKeyIdentifier = keyid:always

Generación de la Autoridad Raíz (Root CA)
-----------------------------------------
De acuerdo con los estándares institucionales de EVALinux, se utiliza el estándar de Curvas Elípticas (ECDSA con curva NIST P-256/``prime256v1``) para alto rendimiento criptográfico, o alternativamente RSA de 4096 bits cuando se requiera compatibilidad con software legado:

#. **Generar la llave privada de la Root CA**:

   .. code-block:: bash

      # Opción estándar: Curva elíptica NIST P-256 (prime256v1)
      openssl ecparam -name prime256v1 -genkey -noout          -out /etc/pki/EVALinuxCA/private/rootca.key.pem

      # Opción alternativa: Llave RSA de 4096 bits
      # openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096       #    -out /etc/pki/EVALinuxCA/private/rootca.key.pem

      # Restricción obligatoria de permisos a nivel archivo
      chmod 0600 /etc/pki/EVALinuxCA/private/rootca.key.pem

#. **Emitir el certificado autofirmado de la Root CA (vigencia de 10 años/3650 días)**:

   .. code-block:: bash

      openssl req -config /etc/pki/EVALinuxCA/openssl-root.cnf          -key /etc/pki/EVALinuxCA/private/rootca.key.pem          -new -x509 -days 3650 -sha256 -extensions v3_ca          -subj "/C=MX/ST=Jalisco/L=Ixtlahuacan de los Membrillos/O=EVALinux/OU=Infrastructure/CN=EVALinux Root CA"          -out /etc/pki/EVALinuxCA/certs/rootca.cert.pem

      # Asignar permisos públicos de lectura al certificado raíz
      chmod 0644 /etc/pki/EVALinuxCA/certs/rootca.cert.pem

Configuración y Emisión de la Autoridad Intermedia (Sub-CA)
-----------------------------------------------------------
Crea el archivo de configuración ``/etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf`` para gobernar las emisiones operativas de la Sub-CA:

.. code-block:: ini

   # Archivo: /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf
   [ ca ]
   default_ca = CA_default

   [ CA_default ]
   dir               = /etc/pki/EVALinuxCA/intermediate
   certs             = $dir/certs
   crl_dir           = $dir/crl
   new_certs_dir     = $dir/newcerts
   database          = $dir/index.txt
   serial            = $dir/serial
   RANDFILE          = $dir/private/.rand

   private_key       = $dir/private/intermediate.key.pem
   certificate       = $dir/certs/intermediate.cert.pem

   crlnumber         = $dir/crlnumber
   crl               = $dir/crl/intermediate.crl.pem
   crl_extensions    = crl_ext
   default_crl_days  = 30

   default_md        = sha256
   name_opt          = ca_default
   cert_opt          = ca_default
   default_days      = 1825
   preserve          = no
   policy            = policy_loose

   [ policy_loose ]
   countryName             = optional
   stateOrProvinceName     = optional
   localityName            = optional
   organizationName        = optional
   organizationalUnitName  = optional
   commonName              = supplied
   emailAddress            = optional

   [ req ]
   default_bits        = 4096
   distinguished_name  = req_distinguished_name
   string_mask         = utf8only
   default_md          = sha256

   [ req_distinguished_name ]
   countryName                     = Country Name (2 letter code)
   stateOrProvinceName             = State or Province Name
   localityName                    = Locality Name
   0.organizationName              = Organization Name
   organizationalUnitName          = Organizational Unit Name
   commonName                      = Common Name
   emailAddress                    = Email Address

   [ server_cert ]
   basicConstraints       = CA:FALSE
   nsCertType             = server
   subjectKeyIdentifier   = hash
   authorityKeyIdentifier = keyid,issuer:always
   keyUsage               = critical, digitalSignature, keyEncipherment
   extendedKeyUsage       = serverAuth, clientAuth

   [ client_cert ]
   basicConstraints       = CA:FALSE
   nsCertType             = client
   subjectKeyIdentifier   = hash
   authorityKeyIdentifier = keyid,issuer:always
   keyUsage               = critical, digitalSignature
   extendedKeyUsage       = clientAuth

   [ crl_ext ]
   authorityKeyIdentifier = keyid:always

A continuación se procede con la generación de la llave y la solicitud de firma (CSR) de la Sub-CA:

#. **Generar la llave privada de la Intermediate Sub-CA**:

   .. code-block:: bash

      openssl ecparam -name prime256v1 -genkey -noout          -out /etc/pki/EVALinuxCA/intermediate/private/intermediate.key.pem

      chmod 0600 /etc/pki/EVALinuxCA/intermediate/private/intermediate.key.pem

#. **Generar la solicitud de firma (CSR) de la Intermediate Sub-CA**:

   .. code-block:: bash

      openssl req -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -new -sha256          -key /etc/pki/EVALinuxCA/intermediate/private/intermediate.key.pem          -subj "/C=MX/ST=Jalisco/L=Ixtlahuacan de los Membrillos/O=EVALinux/OU=Security/CN=EVALinux Intermediate CA"          -out /etc/pki/EVALinuxCA/intermediate/csr/intermediate.csr.pem

#. **Firmar el CSR con la Root CA aplicando la extensión de restricción básica (pathlen:0)**:

   .. code-block:: bash

      openssl ca -config /etc/pki/EVALinuxCA/openssl-root.cnf          -extensions v3_intermediate_ca          -days 1825 -notext -md sha256 -batch          -in /etc/pki/EVALinuxCA/intermediate/csr/intermediate.csr.pem          -out /etc/pki/EVALinuxCA/intermediate/certs/intermediate.cert.pem

      chmod 0644 /etc/pki/EVALinuxCA/intermediate/certs/intermediate.cert.pem

#. **Construir el archivo de la cadena de confianza unificada (CA Chain Bundle)**:

   .. code-block:: bash

      cat /etc/pki/EVALinuxCA/intermediate/certs/intermediate.cert.pem          /etc/pki/EVALinuxCA/certs/rootca.cert.pem          > /etc/pki/EVALinuxCA/intermediate/certs/ca-chain.cert.pem

      chmod 0644 /etc/pki/EVALinuxCA/intermediate/certs/ca-chain.cert.pem

Emisión de Certificados de Servidor con Extensiones SAN
-------------------------------------------------------
Para cada servidor o servicio interno (por ejemplo, ``auth.internal.evalinux.com``), es mandatario generar la extensión SAN explícita que contenga todos los nombres de dominio admisibles y sus direcciones IP:

#. **Generar la llave privada del servidor**:

   .. code-block:: bash

      openssl ecparam -name prime256v1 -genkey -noout          -out /etc/pki/EVALinuxCA/intermediate/private/node01.internal.evalinux.com.key.pem

      chmod 0600 /etc/pki/EVALinuxCA/intermediate/private/node01.internal.evalinux.com.key.pem

#. **Definir el archivo de extensiones X.509 v3 con SAN obligatorio**:

   Crea el archivo ``/etc/pki/EVALinuxCA/intermediate/csr/node01.internal.evalinux.com.ext``:

   .. code-block:: ini

      # Archivo: /etc/pki/EVALinuxCA/intermediate/csr/node01.internal.evalinux.com.ext
      basicConstraints       = CA:FALSE
      nsCertType             = server
      subjectKeyIdentifier   = hash
      authorityKeyIdentifier = keyid,issuer:always
      keyUsage               = critical, digitalSignature, keyEncipherment
      extendedKeyUsage       = serverAuth, clientAuth
      subjectAltName         = @alt_names

      [ alt_names ]
      DNS.1 = auth.internal.evalinux.com
      DNS.2 = api.internal.evalinux.com
      DNS.3 = node01.internal.evalinux.com
      IP.1  = 192.168.10.15
      IP.2  = 127.0.0.1

#. **Generar la solicitud de firma (CSR) para el servidor**:

   .. code-block:: bash

      openssl req -new -sha256          -key /etc/pki/EVALinuxCA/intermediate/private/node01.internal.evalinux.com.key.pem          -subj "/C=MX/ST=Jalisco/L=Ixtlahuacan de los Membrillos/O=EVALinux/OU=Services/CN=auth.internal.evalinux.com"          -out /etc/pki/EVALinuxCA/intermediate/csr/node01.internal.evalinux.com.csr.pem

#. **Firmar el certificado de servidor con la Intermediate Sub-CA**:

   Se establece una vigencia estandarizada moderna de 397 días (conforme a los estándares de la industria para certificados de servidor):

   .. code-block:: bash

      openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -extfile /etc/pki/EVALinuxCA/intermediate/csr/node01.internal.evalinux.com.ext          -days 397 -notext -md sha256 -batch          -in /etc/pki/EVALinuxCA/intermediate/csr/node01.internal.evalinux.com.csr.pem          -out /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem

      chmod 0644 /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem

Emisión de Certificados de Cliente para Autenticación mTLS
----------------------------------------------------------
En un esquema de autenticación mutua TLS (mTLS), los clientes y microservicios deben presentar credenciales criptográficas válidas emitidas por la misma autoridad de confianza:

#. **Generar la llave privada y CSR del cliente**:

   .. code-block:: bash

      openssl ecparam -name prime256v1 -genkey -noout          -out /etc/pki/EVALinuxCA/intermediate/private/client01.key.pem

      chmod 0600 /etc/pki/EVALinuxCA/intermediate/private/client01.key.pem

      openssl req -new -sha256          -key /etc/pki/EVALinuxCA/intermediate/private/client01.key.pem          -subj "/C=MX/ST=Jalisco/L=Ixtlahuacan de los Membrillos/O=EVALinux/OU=Clients/CN=client01"          -out /etc/pki/EVALinuxCA/intermediate/csr/client01.csr.pem

#. **Firmar el certificado de cliente con extensiones clientAuth**:

   .. code-block:: bash

      openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -extensions client_cert          -days 365 -notext -md sha256 -batch          -in /etc/pki/EVALinuxCA/intermediate/csr/client01.csr.pem          -out /etc/pki/EVALinuxCA/intermediate/certs/client01.cert.pem

      chmod 0644 /etc/pki/EVALinuxCA/intermediate/certs/client01.cert.pem

Despliegue de Anclas de Confianza en el Sistema Operativo
---------------------------------------------------------
Para que todas las herramientas del sistema (cURL, navegadores, Python, Go, Java, GnuTLS y OpenSSL) reconozcan los certificados emitidos por la PKI interna, el certificado de la Root CA debe instalarse en el almacén de confianza consolidado de CentOS Stream 10 y Fedora 44:

.. code-block:: bash

   # Copiar el certificado de la Root CA al directorio de anclas del sistema
   cp /etc/pki/EVALinuxCA/certs/rootca.cert.pem       /etc/pki/ca-trust/source/anchors/evalinux-rootca.cert.pem

   chmod 0644 /etc/pki/ca-trust/source/anchors/evalinux-rootca.cert.pem

   # Reconstruir atómicamente los almacenes de confianza consolidados
   update-ca-trust extract

Verifica que el ancla se encuentre correctamente incorporada en la base de datos de confianza del sistema:

.. code-block:: bash

   # Validar presencia mediante trust-list
   trust list | grep -A 2 -B 1 -i "EVALinux Root CA"

Generación y Mantenimiento de Listas de Revocación (CRL)
--------------------------------------------------------
Cuando una llave privada se ve comprometida o un servicio es retirado, el certificado correspondiente debe revocarse inmediatamente para invalidar la cadena de confianza en toda la infraestructura:

#. **Generar la Lista de Revocación inicial de la Sub-CA**:

   .. code-block:: bash

      openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -gencrl -out /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem

      chmod 0644 /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem

#. **Revocar un certificado comprometido**:

   .. code-block:: bash

      # Revocar especificando la razón criptográfica estándar
      openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -revoke /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem          -crl_reason keyCompromise

#. **Regenerar la CRL tras la revocación**:

   .. code-block:: bash

      openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf          -gencrl -out /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem

#. **Inspeccionar la lista de certificados revocados**:

   .. code-block:: bash

      openssl crl -in /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem -text -noout

Automatización del Ciclo de Vida con Systemd
--------------------------------------------
Para evitar que la CRL expire (lo que ocasionaría el bloqueo total de verificaciones TLS estrictas), se configura un temporizador de systemd para actualizar la lista de revocación periódicamente:

Crea la unidad de servicio ``/etc/systemd/system/pki-crl-update.service``:

.. code-block:: ini

   # Archivo: /etc/systemd/system/pki-crl-update.service
   [Unit]
   Description=Actualización periódica de CRL para EVALinux PKI
   After=network.target

   [Service]
   Type=oneshot
   ExecStart=/usr/bin/openssl ca -config /etc/pki/EVALinuxCA/intermediate/openssl-intermediate.cnf -gencrl -out /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem
   ExecStartPost=/usr/bin/chmod 0644 /etc/pki/EVALinuxCA/intermediate/crl/intermediate.crl.pem
   User=root
   Group=root

Crea el temporizador ``/etc/systemd/system/pki-crl-update.timer``:

.. code-block:: ini

   # Archivo: /etc/systemd/system/pki-crl-update.timer
   [Unit]
   Description=Temporizador semanal de actualización de CRL

   [Timer]
   OnCalendar=weekly
   Persistent=true

   [Install]
   WantedBy=timers.target

Habilita e inicia el temporizador de forma atómica:

.. code-block:: bash

   # Habilitar e iniciar inmediatamente la tarea periódica
   systemctl enable --now pki-crl-update.timer
   systemctl list-timers pki-crl-update.timer


Verificación y Pruebas
======================
El proceso de homologación comprende tres fases rigurosas de validación criptográfica y funcional.

Inspección de Extensiones X.509 v3 y Nombres Alternativos (SAN)
----------------------------------------------------------------
Inspecciona el certificado de servidor generado para verificar que las extensiones críticas, el emisor, la vigencia temporal y los registros SAN cumplan con los estándares definidos:

.. code-block:: bash

   # Inspección completa con OpenSSL
   openssl x509 -in /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem       -text -noout

Deberás comprobar los siguientes campos en la salida:

* **Issuer**: Corresponde a ``CN=EVALinux Intermediate CA``.
* **Subject**: Corresponde a ``CN=auth.internal.evalinux.com``.
* **X509v3 Basic Constraints**: Debe reflejar explícitamente ``CA:FALSE``.
* **X509v3 Key Usage**: Debe incluir ``Digital Signature, Key Encipherment``.
* **X509v3 Extended Key Usage**: Debe reflejar ``TLS Web Server Authentication, TLS Web Client Authentication``.
* **X509v3 Subject Alternative Name**: Debe listar con precisión las identidades admitidas:

   .. code-block:: text

      DNS:auth.internal.evalinux.com, DNS:api.internal.evalinux.com, DNS:node01.internal.evalinux.com, IP Address:192.168.10.15, IP Address:127.0.0.1

Alternativamente, efectúa la auditoría mediante ``certtool``:

.. code-block:: bash

   # Inspección técnica con certtool
   certtool -i --infile /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem

Verificación Criptográfica de la Cadena de Confianza
----------------------------------------------------
Para verificar que el certificado final es válido y se enlaza correctamente a través de la Sub-CA intermedia hasta el ancla raíz, utiliza ``openssl verify`` indicando la CA raíz como ancla de confianza y la Sub-CA como certificado intermedio:

.. code-block:: bash

   # Validar cadena de confianza completa
   openssl verify -CAfile /etc/pki/EVALinuxCA/certs/rootca.cert.pem       -untrusted /etc/pki/EVALinuxCA/intermediate/certs/intermediate.cert.pem       /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem

La salida exitosa esperada debe ser:

.. code-block:: text

   /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem: OK

Validación de Canal Seguro TLS 1.3 y Autenticación Mutua (mTLS)
----------------------------------------------------------------
Para simular un canal de producción con autenticación mutua, inicia un servidor TLS de pruebas mediante ``openssl s_server`` que requiera obligatoriamente un certificado de cliente válido firmado por la autoridad interna:

#. **Iniciar servidor de prueba con soporte mTLS estricto**:

   En una terminal de prueba, ejecuta:

   .. code-block:: bash

      openssl s_server -accept 8443          -cert /etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem          -key /etc/pki/EVALinuxCA/intermediate/private/node01.internal.evalinux.com.key.pem          -CAfile /etc/pki/EVALinuxCA/intermediate/certs/ca-chain.cert.pem          -Verify 1 -tls1_3 -www

#. **Ejecutar prueba de cliente sin certificado (verificación de rechazo esperado)**:

   Un cliente no autorizado debe ser rechazado inmediatamente por el servidor al carecer de credenciales mTLS:

   .. code-block:: bash

      openssl s_client -connect 127.0.0.1:8443          -CAfile /etc/pki/EVALinuxCA/intermediate/certs/ca-chain.cert.pem          -tls1_3 -brief < /dev/null

   El servidor abortará la conexión indicando fallo en la recepción del certificado del cliente.

#. **Ejecutar prueba de cliente con certificado válido (aprobación mTLS)**:

   .. code-block:: bash

      openssl s_client -connect 127.0.0.1:8443          -cert /etc/pki/EVALinuxCA/intermediate/certs/client01.cert.pem          -key /etc/pki/EVALinuxCA/intermediate/private/client01.key.pem          -CAfile /etc/pki/EVALinuxCA/intermediate/certs/ca-chain.cert.pem          -tls1_3 -brief < /dev/null

   La salida reportará la negociación exitosa del protocolo TLS 1.3 con la suite criptográfica ``TLS_AES_256_GCM_SHA384`` y el código de verificación ``Verification: OK``.

#. **Validación funcional con cURL contra el ancla instalada en el sistema**:

   Gracias a la instalación del ancla con ``update-ca-trust``, cURL no requerirá especificar la bandera ``--cacert``:

   .. code-block:: bash

      curl --cert /etc/pki/EVALinuxCA/intermediate/certs/client01.cert.pem          --key /etc/pki/EVALinuxCA/intermediate/private/client01.key.pem          https://127.0.0.1:8443/


Problemática
============

Rechazo por Ausencia de Extensiones SAN (RFC 2818)
--------------------------------------------------
Al interactuar con microservicios en Go, Python 3.12+, aplicaciones basadas en Chromium o herramientas CLI modernas como cURL, las solicitudes TLS pueden fallar con el error ``SSL: no alternative certificate subject name matches target host name`` o ``x509: certificate relies on legacy Common Name field, use SANs instead``.

* **Causa raíz**: El campo tradicional ``Common Name`` (CN) fue desaprobado formalmente por el RFC 2818 en el año 2000. Los validadores X.509 contemporáneos ignoran por completo el valor del CN para la comprobación del nombre de host y exigen la presencia explícita de las extensiones ``subjectAltName``.
* **Solución**: Al firmar solicitudes de certificados con ``openssl ca``, asegúrate de proporcionar el archivo de extensiones mediante la opción ``-extfile <archivo.ext>`` que contenga la sección ``[ alt_names ]`` con cada nombre DNS y dirección IP del host de destino.

Monitorización y Expiración Silenciosa de Certificados
------------------------------------------------------
Un certificado vencido en una cadena mTLS detiene de inmediato las comunicaciones del servicio, generando interrupciones severas en cascada (*cascading outages*).

Para prevenir la expiración silenciosa, implementa un script de monitorización automatizado que compruebe la validez del certificado con un margen de seguridad de 30 días (2,592,000 segundos):

.. code-block:: bash

   #!/usr/bin/bash
   set -euo pipefail

   CERT_FILE="/etc/pki/EVALinuxCA/intermediate/certs/node01.internal.evalinux.com.cert.pem"
   SECONDS_WINDOW=2592000

   if ! openssl x509 -checkend "${SECONDS_WINDOW}" -noout -in "${CERT_FILE}"; then
      echo "ALERTA: El certificado ${CERT_FILE} expira en menos de 30 días." >&2
      exit 1
   else
      echo "OK: El certificado ${CERT_FILE} es válido por más de 30 días."
   fi

Permisos Inseguros y Fugas de Llaves Privadas (0600)
----------------------------------------------------
El compromiso de una llave privada destruye irrevocablemente las garantías de confidencialidad y no repudio del servicio afectado. Asimismo, en sistemas CentOS Stream 10 y Fedora 44 con SELinux en modo Enforcing, ubicar llaves privadas en rutas no convencionales genera bloqueos inmediatos de acceso por AVC (*Access Vector Cache*):

* **Permisos POSIX obligatorios**: Las llaves privadas deben pertenecer exclusivamente al usuario del servicio (o ``root:root`` para llaves maestras de la CA) con permisos estrictos ``0600`` (lectura/escritura únicamente para el propietario). Los directorios contenedores deben poseer permisos ``0700``.

* **Etiquetado de contexto SELinux**: Si un demonio de red (como Nginx, Caddy o HAProxy) no puede iniciar tras instalar una nueva llave, inspecciona la bitácora de auditoría y aplica el tipo de contexto ``cert_t``:

   .. code-block:: bash

      ausearch -m avc -ts recent
      semanage fcontext -a -t cert_t "/etc/pki/EVALinuxCA/intermediate/certs(/.*)?"
      restorecon -Rv /etc/pki/EVALinuxCA/intermediate/certs

Caché del Almacén de Confianza y Persistencia en Actualizaciones
----------------------------------------------------------------
Un error operacional recurrente consiste en concatenar directamente certificados de autoridades personalizadas al final de ``/etc/pki/tls/certs/ca-bundle.crt``.

* **Causa del problema**: Dicho archivo es un enlace simbólico o un artefacto efímero administrado por el subsistema ``ca-certificates``. Toda modificación manual se sobreescribe de forma destructiva durante la siguiente actualización de paquetes del sistema operativo.
* **Procedimiento estándar y persistente**: Deposita siempre el certificado raíz con extensión ``.pem`` o ``.crt`` dentro de ``/etc/pki/ca-trust/source/anchors/`` y ejecuta ``update-ca-trust extract``. Esto garantiza que los almacenes de confianza consolidados para OpenSSL, GnuTLS, NSS y Java Virtual Machine se sincronicen de manera atómica y persistente frente a actualizaciones del sistema.


Referencias
===========
* Red Hat Enterprise Linux 10: *Securing networks - Managing certificates and certificate authorities*: https://docs.redhat.com/
* IETF RFC 5280: *Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile*: https://datatracker.ietf.org/doc/html/rfc5280
* IETF RFC 2818: *HTTP Over TLS (Subject Alternative Name Specification)*: https://datatracker.ietf.org/doc/html/rfc2818
* IETF RFC 8446: *The Transport Layer Security (TLS) Protocol Version 1.3*: https://datatracker.ietf.org/doc/html/rfc8446
* Fedora Project Documentation: *Shared System Certificates Guide*: https://docs.fedoraproject.org/
