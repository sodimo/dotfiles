FROM ghcr.io/paperclipai/paperclip:sha-b8725c5
USER root
RUN npm install -g @mariozechner/pi@latest \
  && rm -rf /tmp/* /root/.npm
USER node
