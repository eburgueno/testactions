#!/bin/bash
psql ipdata -c "create table iptable(ipstart inet not null,ipend inet not null,country text not null);"
psql ipdata -c "copy iptable from '/tmp/ip2country-v4.tsv' delimiter E'\t';"
psql ipdata -c "copy iptable from '/tmp/ip2country-v6.tsv' delimiter E'\t';"
psql ipdata -c "copy (select country,inet_merge(ipstart,ipend) from iptable) to '/tmp/export'"
head /tmp/export
tail /tmp/export
