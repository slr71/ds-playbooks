#! /bin/bash -e

# iRODS packaging directory
readonly PackagingDir=/var/lib/irods/packaging


# escapes / and \ for sed script
escape()
{
  local var="$*"

  # Escape \ first to avoid escaping the escape character, i.e. avoid / -> \/ -> \\/
  var="${var//\\/\\\\}"

  printf '%s' "${var//\//\\/}"
}


set -e

# define service account for this installation
"$PackagingDir"/setup_irods_service_account.sh <<EOF
$IRODS_SYSTEM_USER
$IRODS_SYSTEM_GROUP
EOF

# configure irods
sudo -i -u "$IRODS_SYSTEM_USER" "$PackagingDir"/setup_irods_configuration.sh <<EOF
$IRODS_ZONE_PORT
$IRODS_FIRST_EPHEMERAL_PORT
$IRODS_LAST_EPHEMERAL_PORT
$IRODS_DEFAULT_VAULT
$IRODS_ZONE_KEY
$IRODS_NEGOTIATION_KEY
$IRODS_CONTROL_PLANE_PORT
$IRODS_CONTROL_PLANE_KEY
$IRODS_SCHEMA_VALIDATION
$IRODS_ZONE_USER
yes
EOF

mkdir --parents "$IRODS_DEFAULT_VAULT"
chown "$IRODS_SYSTEM_USER":"$IRODS_SYSTEM_GROUP" "$IRODS_DEFAULT_VAULT"

# setup resource server script
sudo -i -u "$IRODS_SYSTEM_USER" \
  CONTROL_PLANE_KEY="$IRODS_CONTROL_PLANE_KEY" \
  CONTROL_PLANE_PORT="$IRODS_CONTROL_PLANE_PORT" \
  IRODS_HOST="$IRODS_HOST" \
  IRODS_LOCAL_RESOURCE="$IRODS_LOCAL_RESOURCE" \
  IRODS_PORT="$IRODS_ZONE_PORT" \
  IRODS_ADMIN_NAME="$IRODS_ZONE_USER" \
  /tmp/setup_resource.sh \
<<EOF
$IRODS_IES
$IRODS_ZONE_NAME
yes
EOF

# create bootstrap.sh
cat <<EOF | sed --file - /tmp/service.sh.template > /service.sh
s/\$IRODS_IES/$(escape $IRODS_IES)/g
s/\$IRODS_ZONE_PASSWORD/$(escape $IRODS_ZONE_PASSWORD)/g
s/\$IRODS_SYSTEM_USER/$(escape $IRODS_SYSTEM_USER)/g
s/\$IRODS_ZONE_PORT/$(escape $IRODS_ZONE_PORT)/g
EOF

chmod a+rx /service.sh
