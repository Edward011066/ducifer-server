FROM nextcloud:latest

RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/*
	
COPY init-nextcloud.sh /init-nextcloud.sh
RUN chmod +x /init-nextcloud.sh