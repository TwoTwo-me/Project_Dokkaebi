#!/bin/sh
set -eu

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "missing_required_env=$name" >&2
    exit 64
  fi
}

for name in \
  DOKKAEBI_TICKET_ID \
  DOKKAEBI_TENANT_ID \
  DOKKAEBI_ROUTE_PROFILE \
  DOKKAEBI_NAMESPACE \
  DOKKAEBI_SERVICE_ACCOUNT \
  DOKKAEBI_IMAGE_PROFILE \
  DOKKAEBI_RESULT_PACKET_SINK \
  DOKKAEBI_PERMISSION_LEVEL
do
  require_env "$name"
done

echo "result_packet_status=accepted"
echo "ticket_id=$DOKKAEBI_TICKET_ID"
echo "tenant_id=$DOKKAEBI_TENANT_ID"
echo "route_profile=$DOKKAEBI_ROUTE_PROFILE"
echo "namespace=$DOKKAEBI_NAMESPACE"
echo "service_account=$DOKKAEBI_SERVICE_ACCOUNT"
echo "image_profile=$DOKKAEBI_IMAGE_PROFILE"
echo "result_packet_sink=$DOKKAEBI_RESULT_PACKET_SINK"
echo "permission_level=$DOKKAEBI_PERMISSION_LEVEL"
echo "log_surface=kubectl logs pod/$HOSTNAME -n $DOKKAEBI_NAMESPACE"
echo "exit_status=0"
