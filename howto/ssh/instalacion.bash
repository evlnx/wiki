#!/usr/bin/bash
# Instalar servidor y clientes OpenSSH en CentOS Stream 10 y Fedora 44
set -euo pipefail
IFS=$'\n\t'

dnf -y install openssh-server openssh-clients
