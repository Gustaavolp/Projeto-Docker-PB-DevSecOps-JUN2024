#!/bin/bash
# Atualizar e instalar pacotes necessários
sudo yum update -y
sudo yum install -y amazon-efs-utils nfs-utils

# Instalar Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Variáveis
EFS_ID=fs-0e3e3735f38bb30d7  # Substitua pelo seu ID do EFS
MOUNT_POINT="/mnt/efs"

# Montar o EFS usando amazon-efs-utils com TLS
sudo mkdir -p ${MOUNT_POINT}
sudo mount -t efs -o tls ${EFS_ID}:/ ${MOUNT_POINT}

# Verificar se o EFS foi montado com sucesso
if mountpoint -q ${MOUNT_POINT}; then
    echo "EFS montado com sucesso em ${MOUNT_POINT}"
else
    echo "Falha ao montar o EFS com TLS. Tentando montar com NFS."

    # Montar usando cliente NFS se o método TLS falhar
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_ID}.efs.us-east-1.amazonaws.com:/ ${MOUNT_POINT}
    
    # Verificar se a montagem via NFS foi bem-sucedida
    if mountpoint -q ${MOUNT_POINT}; then
        echo "EFS montado com sucesso em ${MOUNT_POINT} usando NFS"
    else
        echo "Erro ao montar o EFS. Verifique a configuração de rede e grupos de segurança."
        exit 1
    fi
fi

# Executar o contêiner Docker do WordPress
sudo docker run -d \
  --name wordpress \
  -p 80:80 \
  -v ${MOUNT_POINT}/html:/var/www/html \
  -e WORDPRESS_DB_HOST=wordpressdb.c7ee0kcmeckx.us-east-1.rds.amazonaws.com:3306 \
  -e WORDPRESS_DB_USER=admin \
  -e WORDPRESS_DB_PASSWORD=sua_senha_de_bd \
  -e WORDPRESS_DB_NAME=wordpressdb \
  wordpress:latest
