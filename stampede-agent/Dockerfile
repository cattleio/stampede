FROM cattle/agent:dev
RUN mv /usr/local/bin/cattle /usr/local/cattle; cp /usr/bin/jq /usr/bin/cattle-jq
ADD /files /files/
ADD /cattle /usr/bin/cattle
ADD /cattle-default-ssh-key /usr/bin/cattle-default-ssh-key
ADD /startup.sh /
CMD ["/startup.sh"]
