#!/bin/sh

# simple script to grab grevy's zebra data from gbif

curl -s 'https://api.gbif.org/v1/occurrence/search?media_type=StillImage&taxon_key=2440894&limit=300'

