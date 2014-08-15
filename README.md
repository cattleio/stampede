# Stampede

Stampede is a hybrid IaaS/Docker orcherstration platform running on CoreOS.  Given you have a CoreOS cluster, with in a couple minutes you should have a very capable platform to run both virtual machines and Docker (containers).

## Demo

[![ScreenShot](docs/youtube.pn)](http://youtu.be/UsQ9cVLieaQ)

## Installation

```bash
wget http://stampede.io/latest/cattle-stampede.service
fleetctl start cattle-stampede.service
```
Wait for bits to fly across the interwebs (could take 10 minutes...)
```
fleetctl list-units
```
Output
```
UNIT                                            DSTATE          TMACHINE                STATE           MACHINE                 ACTIVE
cattle-libvirt.7ffe1d-b2c083.service            launched        b2c0835f.../10.42.1.115 launched        b2c0835f.../10.42.1.115 active
cattle-stampede-agent.76bcfb-b2c083.service     launched        b2c0835f.../10.42.1.115 launched        b2c0835f.../10.42.1.115 active
cattle-stampede-server.01c222-b2c083.service    launched        b2c0835f.../10.42.1.115 launched        b2c0835f.../10.42.1.115 active
cattle-stampede.service                         launched        b2c0835f.../10.42.1.115 launched        b2c0835f.../10.42.1.115 active
```

## Vagrant

```
git clone https://github.com/cattleio/stampede.git
cd stampede
vagrant up
```

API/UI will be accessible at http://localhost:9080.  Running from Vagrant may take ***10 minutes to install, so please be patient.***  [Refer to the documentation](vagrant/README.md) for running a multi-node Vagrant setup.

# Contact

IRC: darren0 on freenode

Twitter: @ibuildthecloud

Email: darren at ibuildthecloud.com
