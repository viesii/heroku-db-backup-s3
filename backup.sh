#!/bin/bash

PYTHONHOME=/app/vendor/awscli/
Green='\033[0;32m'
EC='\033[0m'
FILENAME=`date +%Y%m%d_%H_%M`

# terminate script on any fails
set -e

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

echo "$DB_BACKUP_GPG_PUB_KEY" > gpg-pubkey
gpg --import gpg-pubkey

printf "${Green}Start dump${EC}"
TMP_BACKUP=/tmp/"${DBNAME}_${FILENAME}".gpg

if [[ $DATABASE_URL = mysql* ]]; then
  DB_BACKUP_USER=$(echo $DATABASE_URL | cut -d/ -f3 | cut -d: -f1)
  DB_BACKUP_PASSWORD=$(echo $DATABASE_URL | cut -d: -f3 | cut -d@ -f1)
  DB_BACKUP_HOST=$(echo $DATABASE_URL | cut -d@ -f2 | cut -d: -f1)
  DB_BACKUP_DATABASE=$(echo $DATABASE_URL | cut -d/ -f4)
  mysqldump -h $DB_BACKUP_HOST -p$DB_BACKUP_PASSWORD -u$DB_BACKUP_USER $DB_BACKUP_DATABASE | gpg --encrypt --recipient "$DB_BACKUP_GPG_PUB_KEY_ID" --output "$TMP_BACKUP"
elif [[ $DATABASE_URL = postgres* ]]; then
  pg_dump $DBURL_FOR_BACKUP | gpg --encrypt --recipient "$DB_BACKUP_GPG_PUB_KEY_ID" --output "$TMP_BACKUP"
else
  echo "Unknown database URL protocol. Must be mysql, mysql2 or postgres"
  exit 1;
fi;

printf "${Green}Move dump to AWS${EC}"
AWS_ACCESS_KEY_ID=$DB_BACKUP_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$DB_BACKUP_AWS_SECRET_ACCESS_KEY /app/vendor/bin/aws --region $DB_BACKUP_AWS_DEFAULT_REGION s3 cp "$TMP_BACKUP" s3://$DB_BACKUP_S3_BUCKET_PATH/$DBNAME/"${DBNAME}_${FILENAME}".gpg

# cleaning after all
rm -rf "$TMP_BACKUP"
