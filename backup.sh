#!/bin/bash

PYTHONHOME=/app/vendor/awscli/
Green='\033[0;32m'
EC='\033[0m'
DATE=`date +%Y%m%d_%H_%M`

# terminate script on any fails
set -e

if [[ -z "$DB_BACKUP_FILENAME" ]]; then
  echo "Missing DB_BACKUP_FILENAME variable"
  exit 1
fi

if [[ -z "$DB_BACKUP_AWS_ACCESS_KEY_ID" ]]; then
  echo "Missing DB_BACKUP_AWS_ACCESS_KEY_ID variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing DB_BACKUP_AWS_SECRET_ACCESS_KEY variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_DEFAULT_REGION" ]]; then
  echo "Missing DB_BACKUP_AWS_DEFAULT_REGION variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_S3_BUCKET_PATH" ]]; then
  echo "Missing DB_BACKUP_S3_BUCKET_PATH variable"
  exit 1
fi
if [[ -z "$DATABASE_URL" ]] ; then
  echo "Missing DATABASE_URL variable"
  exit 1
fi

if [[ -z "$DB_BACKUP_GPG_PUB_KEY" ]]; then
  echo "Missing DB_BACKUP_GPG_PUB_KEY variable"
  exit 1
fi

printf "${Green}Import GPG key${EC}\n"
echo "$DB_BACKUP_GPG_PUB_KEY" > gpg-pubkey
gpg --quiet --import gpg-pubkey

printf "${Green}Start dump${EC}\n"
if [[ $DATABASE_URL = mysql* ]]; then
  TMP_BACKUP=/tmp/"${DB_BACKUP_FILENAME}_mysql_${DATE}".gpg

  DB_BACKUP_USER=$(echo $DATABASE_URL | cut -d/ -f3 | cut -d: -f1)
  DB_BACKUP_PASSWORD=$(echo $DATABASE_URL | cut -d: -f3 | cut -d@ -f1)
  DB_BACKUP_HOST=$(echo $DATABASE_URL | cut -d@ -f2 | cut -d: -f1)
  DB_BACKUP_DATABASE=$(echo $DATABASE_URL | cut -d/ -f4)
  
  cat > .my.cnf <<-EOF
    [client]
    password=${DB_BACKUP_PASSWORD}
EOF
  chmod 600 .my.cnf
  mysqldump -h $DB_BACKUP_HOST -u$DB_BACKUP_USER $DB_BACKUP_DATABASE | gpg --encrypt --recipient "$DB_BACKUP_GPG_PUB_KEY_ID" --output "$TMP_BACKUP" --trust-model always
elif [[ $DATABASE_URL = postgres* ]]; then
  TMP_BACKUP=/tmp/"${DB_BACKUP_FILENAME}_postgresql_${DATE}".gpg

  pg_dump $DATABASE_URL | gpg --encrypt --recipient "$DB_BACKUP_GPG_PUB_KEY_ID" --output "$TMP_BACKUP" --trust-model always
else
  echo "Unknown database URL protocol. Must be mysql, mysql2 or postgres"
  exit 1;
fi;

printf "${Green}Move dump to AWS${EC}\n"
AWS_ACCESS_KEY_ID=$DB_BACKUP_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$DB_BACKUP_AWS_SECRET_ACCESS_KEY /app/vendor/bin/aws --region $DB_BACKUP_AWS_DEFAULT_REGION s3 cp --no-progress "$TMP_BACKUP" s3://$DB_BACKUP_S3_BUCKET_PATH/

# cleaning after all
rm -rf "$TMP_BACKUP"
