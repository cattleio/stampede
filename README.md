# Stampede

Stampede is a hybrid IaaS/Docker orcherstration platform running on CoreOS.  Starting with an empty CoreOS cluster, with in a couple minutes you should have a very capable platform to run both virtual machines and Docker.  Stampede strives to add complex orchestration already seen in IaaS to Docker to achieve things such as secure and dynamic cross server linking.

[![ScreenShot](docs/youtube.png)](http://youtu.be/UsQ9cVLieaQ)

## Installation

Start with a blank CoreOS cluster with Fleet and Etcd configured.

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

The API/UI is available at 9080 of your server.

## Vagrant

```
git clone https://github.com/cattleio/stampede.git
cd stampede
vagrant up
```

API/UI will be accessible at http://localhost:9080.  Running from Vagrant may take ***10 minutes to install, so please be patient.***  [Refer to the documentation](vagrant/README.md) for running a multi-node Vagrant setup.

# UI

![UI](docs/ui.png)

# Functionality

* Virtual Machines
  * Libvirt/KVM
  * EC2/OpenStack images work out of the box
  * EC2 style meta data
  * OpenStack config drive
  * Managed DNS/DHCP
  * User data
  * Floating IPs
  * Private networking
  * VNC Console
  * CoreOS, Ubuntu, Fedora, and Cirros templates preconfigured
* Docker
  * Link containers across servers
  * Dynamically reassign links and ports
* Networking
  * VMs and containers can share the same network space
  * By default, a private IPSec VPN is created that spans servers
  * All containers and VMs live on a virtual network that can span across cloud
* Interface
  * UI
  * REST API
    * Use web browser to explore and use API
  * Command line client
  * Python API bindings

# Stampede.io and Cattle.io

You’ll find plenty of references to cattle or cattle.io in Stampede.  [Cattle.io](http://cattle.io) is the underlying framework that implements all the real logic of Stampede.  Cattle.io is extremely flexible and can be bent to do many things and run on many platforms.  Stampede was created as a project to package Cattle.io in a very simple and straight forward fashion that should work for the majority of users.  As such, Stampede marries Cattle.io with CoreOS and Fleet to provide a very a simple full stack solution.

# Why was this built?

Stampede and the underlying cattle.io framework was created by me as part of a 6 month R&D project.  My current employer graciously allowed me to go off on my own and experiment with new ideas in the infrastructure orchestration space.  The basic premise was to take all that we know from 5+ years of writing IaaS systems, combine that with containerization, and see what we can do.  The purpose was really to play with new ideas.

## Concepts

If I have the time I'll blog in depth about the below topics, but just to give you any idea, here are a list of things I've focused on.

**Hybrid IaaS/Container Orchestation System:**  Traditional IaaS systems are not a good fit for containers.  Container orchestration systems largely ignore the complex orchestation of networking and storage.  Combining the two you get a very complete solution.

**Orchestration as a Service:**  By decoupling orchestration from infrastructure one can level the playing field such that you don't need to be as big as AWS, GCE, Azure to be relevant in the cloud space.  I've explored this concept [in depth on my blog](http://www.ibuildthecloud.com/blog/2014/08/12/evolution-of-docker-and-its-impact-on-aws/).

**Non-reliable messaging:** Reliable (and persistent) messaging adds yet another repository of state making an already complex problem more complex.  Stampede was built with no assumption of reliability in the messaging layer.  There is no guarantee that any message sent will ever be received.

**Idempotency:**  Infrastructure components fail often (in the computer science sense).  The use of idempotency allows operation to more easily recover from bad situations.  Idempotency in all operations is not only a good practice that was used in building Stampede, but it is actually built into the architecture and enforced by the framework.

**EC2 architectural compatibility:**  EC2 is the de-facto standard in IaaS.  While designing the core concepts of Stampede, extra care was take to ensure that the concepts used would be architecturally compatible with EC2 (especially networking).

**Extensibility:**  While the core languages used in Stampede were chosen for very specific reasons, one should be able to extend the orchestration of Stampede in any language using a very simple event driven REST API.

**Simplified orchestration:**  In an attempt to provide more reliable orchestration people often propose or gravitate towards complex workflow engines.  Stampede tries to find an elegant balance between complex workflows and naive sequential programming.  Stampede is heavily focused on the [concept of managing state transitions](http://docs.cattle.io/en/latest/concepts/orchestration.html) and attaching logic to those transitions.

**Flexible Networking:** The simplest and most scalable network designs are often in conflict with the current IaaS systems of today.  I wanted to build a networking model that not only caters to new SDN and L2 virtualization models, but also simple scalable L3 networks.

# Docker philosophy

While many systems today are “powered by” Docker, I wanted Docker to be a first class citizen.  Just as EC2 defined the language in how we now describe virtual machines in the cloud, I believe Docker will define a similar language for containers.  As such, Stampede does not try to mask Docker, bend it’s constructs, or invent new ones.  I am very interested in taking the concepts and models that Docker has defined, such as ports, link, volumes, and respecting those in Stampede.  The only difference being that while running in the context of Stampede I may often replace the implementation of those concepts with my own implementation to provide a more robust solution.  For example, one of the first features I implemented was cross server container linking.  This respects the full interface that Docker has defined with environment variables, but Stampede controls the values of the environment and the network target.

# Plans?

I don't know.  [Let me know](#contact) if you find this project interesting.

# Documentation

More documenation can be found at [cattle.io](http://cattle.io).  Granted it's all a bit light right now.

# Contact

IRC: darren0 on freenode

Twitter: @ibuildthecloud

Email: darren at ibuildthecloud.com

# License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)
