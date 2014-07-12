FROM cattle/server:dev
RUN apt-get update && apt-get install -y --no-install-recommends curl iptables
ADD http://stedolan.github.io/jq/download/linux64/jq /usr/bin/jq
RUN chmod +x /usr/bin/jq
ADD startup.sh /startup.sh
ADD done.sh /done.sh
ADD error.sh /error.sh
ADD notify.py /notify.py
CMD ["/startup.sh"]
