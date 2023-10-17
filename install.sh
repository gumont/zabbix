# Instalando o Zabbix via Docker
# Publicado em 16 de agosto de 2017
# Atualizado em: 06 de abril de 2023

# Neste repositório do GitHub tem várias informações sobre o uso das imagens oficiais do Zabbix no Docker.

# As instruções oficiais para instalação do Zabbix com Docker estão disponíveis em: https://www.zabbix.com/documentation/current/en/manual/installation/containers

# Se você não sabe o que é Docker, recomendo começar lendo os links abaixo. Vale a pena conhecer essa tecnologia.

# http://blog.aeciopires.com/palestra-transportando-as-aplicacoes-entre-varios-ambientes-com-docker/
# http://blog.aeciopires.com/primeiros-passos-com-docker/

# Também realizo curso de Docker: http://blog.aeciopires.com/curso-docker

# Neste tutorial, será mostrado como executar o Zabbix usando conteineres Docker, o que deixa a instalação bem simples e rápida. Será mostrado como iniciar os conteineres Zabbix e MySQL persistindo os dados.

# 0) Instale o Docker seguindo um dos tutoriais abaixo.

# No Ubuntu: https://docs.docker.com/engine/install/ubuntu
# No Debian: https://docs.docker.com/engine/install/debian
# No CentOS: https://docs.docker.com/engine/install/centos
# 1) Crie um diretório para persistir os dados do MySQL, Mibs e SNMP Traps.

sudo mkdir -p /docker/zabbix/mysql/data \
 /docker/zabbix/snmptraps \
 /docker/zabbix/mibs
# Atenção: O volume permite adicionar novos arquivos de MIB (Management Information Bases). Esse volume não suporta subdiretórios, todos os arquivos de MIBs devem ser colocados em /docker/zabbix/mibs. Fonte: https://www.zabbix.com/documentation/current/en/manual/installation/containers

# 2) OPCIONAL – Crie o diretório de certificado para uso do Zabbix via HTTPS (isso é recomendado por questões de segurança).

sudo mkdir -p /docker/zabbix/ssl
# Depois disso, copie o arquivo do certificado, da autoridade certificadora chave pública e privada para esse diretório.

# 3) Baixe as imagens Docker de alguns componentes do Zabbix. Altere os valores conforme as necessidades do seu ambiente.

ZABBIX_VERSION=ubuntu-6.4-latest

docker pull mysql:8
docker pull zabbix/zabbix-agent:${ZABBIX_VERSION}
docker pull zabbix/zabbix-proxy-sqlite3:${ZABBIX_VERSION}
docker pull zabbix/zabbix-server-mysql:${ZABBIX_VERSION}
docker pull zabbix/zabbix-web-nginx-mysql:${ZABBIX_VERSION}
docker pull zabbix/zabbix-snmptraps:${ZABBIX_VERSION}
# 4) Crie um rede virtual no Docker dedicada aos componentes do Zabbix. Altere os valores conforme as necessidades do seu ambiente.

ZABBIX_SUBNET="172.20.0.0/16"do
ZABBIX_IP_RANGE="172.20.240.0/20"

docker network create --subnet ${ZABBIX_SUBNET} --ip-range ${ZABBIX_IP_RANGE} zabbix-net

docker network inspect zabbix-net

# 5) Inicie o conteiner docker do MySQL criando o banco de dados para o Zabbix. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-mysql \
 --restart always \
 -p 3306:3306 \
 -v /docker/zabbix/mysql/data:/var/lib/mysql \
 -e MYSQL_ROOT_PASSWORD=secret \
 -e MYSQL_DATABASE=zabbix \
 -e MYSQL_USER=zabbix \
 -e MYSQL_PASSWORD=zabbix \
 --network=zabbix-net \
 mysql:8 \
 --default-authentication-plugin=mysql_native_password \
 --character-set-server=utf8 \
 --collation-server=utf8_bin

# Para ver o log, use o seguinte comando.

docker logs -f zabbix-mysql

# 6) Inicie o conteiner docker do Zabbix SNMP Trap. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-snmptraps -t \
 --restart always \
 -p 162:1162/udp \
 -v /docker/zabbix/snmptraps:/var/lib/zabbix/snmptraps:rw \
 -v /docker/zabbix/mibs:/usr/share/snmp/mibs:ro \
 --network=zabbix-net \
 zabbix/zabbix-snmptraps:${ZABBIX_VERSION}

# Para ver o log, use o seguinte comando.

docker logs -f zabbix-snmptraps

# 7) Inicie o conteiner docker do Zabbix-Server. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-server \
 --restart always \
 -p 10051:10051 \
 -e DB_SERVER_HOST="zabbix-mysql" \
 -e DB_SERVER_PORT="3306" \
 -e MYSQL_ROOT_PASSWORD="secret" \
 -e MYSQL_DATABASE="zabbix" \
 -e MYSQL_USER="zabbix" \
 -e MYSQL_PASSWORD="zabbix" \
 -e ZBX_ENABLE_SNMP_TRAPS="true" \
 --network=zabbix-net \
 --volumes-from zabbix-snmptraps \
 zabbix/zabbix-server-mysql:${ZABBIX_VERSION}

# Para ver o log, use o seguinte comando.

docker logs -f zabbix-server

# 8) Inicie o conteiner Zabbix-Web SEM HTTPS. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-web \
 --restart always \
 -p 80:8080 \
 -e ZBX_SERVER_HOST="zabbix-server" \
 -e DB_SERVER_HOST="zabbix-mysql" \
 -e DB_SERVER_PORT="3306" \
 -e MYSQL_ROOT_PASSWORD="secret" \
 -e MYSQL_DATABASE="zabbix" \
 -e MYSQL_USER="zabbix" \
 -e MYSQL_PASSWORD="zabbix" \
 -e PHP_TZ="America/Campo_Grande" \
 --network=zabbix-net \
 zabbix/zabbix-web-nginx-mysql:${ZABBIX_VERSION}

# Ou inicie o conteiner docker do Zabbix-Web COM HTTPS acessando o banco de dados criado no MySQL e o conteiner Zabbix-Server. Altere os valores conforme as necessidades do seu ambiente.

# OBS.: No fim deste tutorial, tem a seção EXTRA: Criando um certificado auto-assinado para uso com o Nginx, que pode ser utilizada como exemplo para configurar o uso do Nginx com HTTPS.

docker run -d --name zabbix-web \
 --restart always \
 -p 80:8080 -p 443:8443 \
 -v /docker/zabbix/ssl/ssl.crt:/etc/ssl/nginx/ssl.crt \
 -v /docker/zabbix/ssl/ssl.key:/etc/ssl/nginx/ssl.key \
 -v /docker/zabbix/ssl/dhparam.pem:/etc/ssl/nginx/dhparam.pem \
 -e ZBX_SERVER_HOST="zabbix-server" \
 -e DB_SERVER_HOST="zabbix-mysql" \
 -e DB_SERVER_PORT="3306" \
 -e MYSQL_ROOT_PASSWORD="secret" \
 -e MYSQL_DATABASE="zabbix" \
 -e MYSQL_USER="zabbix" \
 -e MYSQL_PASSWORD="zabbix" \
 -e PHP_TZ="America/Campo_Grande" \
 --network=zabbix-net \
 zabbix/zabbix-web-nginx-mysql:${ZABBIX_VERSION}

# Para ver o log, use o seguinte comando.

docker logs -f zabbix-web

# 9) Inicie o conteiner docker do Zabbix-Agent. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-agent \
 --hostname "$(hostname)" \
 --privileged \
 -v /:/rootfs \
 -v /var/run:/var/run \
 --restart always \
 -p 10050:10050 \
 -e ZBX_HOSTNAME="$(hostname)" \
 -e ZBX_SERVER_HOST="172.17.0.1" \
 -e ZBX_PASSIVESERVERS="${ZABBIX_IP_RANGE}" \
 zabbix/zabbix-agent:${ZABBIX_VERSION}

# Para ver o log, use o seguinte comando.

docker logs -f zabbix-agent

# 10) OPCIONAL – Inicie o conteiner docker do Zabbix-Proxy. Altere os valores conforme as necessidades do seu ambiente.

docker run -d --name zabbix-proxy \
 --restart always \
 -p 10053:10050 \
 -e ZBX_HOSTNAME="$(hostname)" \
 -e ZBX_SERVER_HOST="zabbix-server" \
 -e ZBX_ENABLE_SNMP_TRAPS="true" \
 --network=zabbix-net \
 --volumes-from zabbix-snmptraps \
 zabbix/zabbix-proxy-sqlite3:${ZABBIX_VERSION}

# Para ver o log, use o seguinte comando.


docker logs -f zabbix-proxy

11) Acesse o Zabbix na URL http://IP-Servidor (com HTTP) ou https://IP-Servidor (com HTTPS). O login é Admin e a senha padrão é zabbix.

Lembre-se de cadastrar o Zabbix Proxy e o Host com o Zabbix Agent instalado.

12) Se quiser parar o conteiner, é só executar o seguinte comando.

docker stop nome-conteiner
13) Para iniciá-lo novamente, execute o seguinte comando.

docker start nome-conteiner
14) Para remover um conteiner, use os seguintes comandos.

docker stop nome-conteiner
docker rm nome-conteiner
15) Para obter mais informações sobre o Zabbix, sobre as imagens docker e como customizar parâmetros de configuração, acesse os links abaixo.

https://scaron.info/blog/improve-your-nginx-ssl-configuration.html

http://zabbixbrasil.org/?page_id=7

https://blog.zabbix.com/zabbix-docker-containers/7150/

https://www.youtube.com/watch?v=ScKlF0ICVYA

https://www.zabbix.com/documentation/current/manual/installation/containers

16) OPCIONAL – Se precisar fazer o dump de todos os bancos de dados do conteiner MySQL criado anteriormente, use o comando abaixo. Altere os dados em negrito e em vermelho conforme as necessidades do seu ambiente. Lembrando que os dados do banco são persistidos no diretório /docker/zabbix/mysql/data do Docker Host no qual o conteiner está sendo executado.

docker exec zabbix-mysql sh -c 'exec mysqldump zabbix -uroot -p"MYSQL_ROOT_PASSWORD"' > /home/zabbix.sql
17- OPCIONAL – Se precisar restaurar o dump, siga os passos abaixo.

Remova o banco antigo e crie-o novamente.

docker exec -i -t zabbix-mysql /bin/bash

root@4f39b60a2dde:/# mysql -u root -p
Enter password: 

mysql> drop database zabbix;
mysql> create database zabbix;
mysql> quit

root@4f39b60a2dde:/# exit
Restaure o dump no banco novo. Altere os valores conforme as necessidades do seu ambiente.

docker stop zabbix-web
docker stop zabbix-server

docker exec -i zabbix-mysql /usr/bin/mysql -uroot -pMYSQL_ROOT_PASSWORD --database=zabbix < /home/zabbix.sql

docker start zabbix-server
docker start zabbix-web
Ou:

docker stop zabbix-web
docker stop zabbix-server

cat /home/zabbix.sql | docker exec zabbix-mysql sh -c 'exec /usr/bin/mysql -u root --password="MYSQL_ROOT_PASSWORD" zabbix'

docker start zabbix-server
docker start zabbix-web


# EXTRA: Criando um certificado auto-assinado para uso com o Nginx
Instale o pacote opensssl.

# No Debian/Ubuntu:

sudo apt-get -y install openssl

# No CentOS:

sudo yum install -y openssl

# Agora crie uma chave privada RSA. Execute os comandos abaixo. Será necessário definir uma senha para a chave privada.

sudo mkdir -p /docker/zabbix/ssl
cd /docker/zabbix/ssl
sudo openssl genrsa -aes256 -out ssl.key 4096

sudo cp ssl.key ssl.key.org
sudo openssl rsa -in ssl.key.org -out ssl.key

sudo chmod 755 ssl.key
sudo rm ssl.key.org

# Agora crie uma requisição de assinatura de certificado com validade para 1000 anos (ou 365000 dias). Execute o comando abaixo.

openssl req -new -sha256 -days 365000 -key ssl.key -out ssl.csr

# Durante a execução do comando acima será solicitado a senha da chave privada e os dados do certificado e que serão exibidos no navegador do usuário. Veja o exemplo abaixo.

# Country Name (2 letter code) [GB]:BR
# State or Province Name (full name) [Berkshire]:Estado
# Locality Name (eg, city) [Newbury]:Cidade
# Organization Name (eg, company) [My Company Ltd]: Minha empresa LTDA
# Organizational Unit Name (eg, section) []:Meu setor de trabalho
# Common Name (eg, your name or your server’s hostname) []:nomeservidor.empresa.com.br
# Email Address []:email@empresa.com.br
# Please enter the following ‘extra’ attributes
# to be sent with your certificate request
# A challenge password []: (deixe vazia, apertando ENTER)
# An optional company name []: (deixe vazia, apertando ENTER)
# Agora assine o certificado.

sudo openssl x509 -req -days 3650 -sha256 -in ssl.csr -signkey ssl.key -out ssl.crt

# Usando, o comando acima, você estará assinando o certificado com validade de 1000 anos (aproximadamente 365000 dias). Se quiser mudar este tempo, altere a quantidade de dias no parâmetro -days.

# Agora crie um par de chaves Diffie-Hellman com o seguinte comando:

sudo openssl dhparam -out dhparam.pem 4096