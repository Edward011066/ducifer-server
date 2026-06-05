#!/bin/bash

echo "Aplicando configuração do Nextcloud..."

docker exec -it nextcloud php occ app:enable previewgenerator

docker exec -it nextcloud php occ config:system:set enable_previews --value=true

docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\MP4"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\Movie"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\AVI"
docker exec -it nextcloud php occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\MKV"

docker exec -it nextcloud php occ config:system:set preview_max_x --value=1024
docker exec -it nextcloud php occ config:system:set preview_max_y --value=1024

echo "Rodando cron setup..."
docker exec -it nextcloud php occ background:cron

echo "OK - Nextcloud configurado"