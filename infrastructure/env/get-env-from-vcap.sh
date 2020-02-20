if [[ ! $VCAP_SERVICES ]]; then
    >&2 echo "\$VCAP_SERVICES not found"
    exit 1
fi

echo $VCAP_SERVICES | ./env/jq -r '
    ."user-provided"
        | map(
            select(.name[-4:] == "-env")
                | .credentials
                | to_entries[]
                | "\(.key)=\(.value)"
        )
        | @tsv'

echo "KEYCLOAK_DATABASE_URI=$(echo $VCAP_SERVICES | ./env/jq -r '.postgres[] | select(.name == "keycloak-database") .credentials .uri')"
