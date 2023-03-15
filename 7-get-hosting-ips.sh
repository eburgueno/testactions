#!/bin/bash
HOSTING_IPS_DIR="hosting-ips"
rm -rf "$HOSTING_IPS_DIR"
mkdir -p "$HOSTING_IPS_DIR"

CONTAINER=$(docker ps -q)

wget -q -O hostingRanges.tsv.zip https://github.com/NikolaiT/IP-Address-API/raw/main/databases/hostingRanges.tsv.zip
#cd /tmp
unzip hostingRanges.tsv.zip
rm -f hostingRanges.tsv.zip
#cd -

#preprocessing
##if last field is empty, use a trimmed version of the first one
##if range is cidr already, add empty start and end fields
##else, add empty cidr field
##remove first field
cat hostingRanges.tsv | awk -F'\t' 'BEGIN{OFS="\t"} {if ($NF=="") { gsub(/[^[:alnum:]]/, "", $1); $NF=$1 }} { gsub(/[[:space:]]+/,"",$2) } {if ($2 ~ /\//) { $2="\t\t"$2 } else { gsub(/-/,"\t",$2); $3="\t"$3 }} {for(i=2;i<=NF-1;i++) printf $i"\t"; print $NF}' > preprocessed.tsv

docker cp preprocessed.tsv "${CONTAINER}":/tmp/preprocessed.tsv
docker exec -u postgres "${CONTAINER}" mkdir /tmp/pgexport

export PGPASSWORD="postgres"
psql -h localhost -p 5432 -U postgres ipdata -c "CREATE TABLE hosting(ipstart INET,ipend INET, iprange CIDR, provider TEXT NOT NULL);"

psql -h localhost -p 5432 -U postgres ipdata -c "COPY hosting FROM '/tmp/preprocessed.tsv' WITH (DELIMITER E'\t', NULL '');"

psql -h localhost -p 5432 -U postgres ipdata -c "UPDATE hosting SET iprange=inet_merge(ipstart, ipend) WHERE iprange IS NULL;"
psql -h localhost -p 5432 -U postgres ipdata <<'EOF'
DO $$
DECLARE
rec record;
filename text;
BEGIN
FOR rec IN SELECT DISTINCT provider FROM hosting LOOP
filename := '/tmp/pgexport/' || rec.provider;
EXECUTE format('COPY (SELECT iprange as cidr FROM hosting WHERE provider = %L ORDER BY cidr) TO %L', rec.provider, filename);
END LOOP;
END $$;
EOF

docker exec "${CONTAINER}" tar -cf /tmp/pgexport.tar /tmp/pgexport
docker cp "${CONTAINER}":/tmp/pgexport.tar "$HOSTING_IPS_DIR"/pgexport.tar
cd "$HOSTING_IPS_DIR"
tar --strip-components=2 -xf pgexport.tar
rm -f pgexport.tar
cd

