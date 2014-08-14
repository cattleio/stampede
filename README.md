Stampede
========

Run and orchestrate both **KVM** and **Docker** on CoreOS.

Install
-------

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

UI
--

Fancy API UI
------------

REST API
--------

Python bindings
---------------

CLI
----

Random Notes
============

Why did you write this?
-----------------------

What do you plan on doing with this?
------------------------------------

No clue.  It started as a simple experiment to test new ideas with orchestration and Docker and I liked the outcome so I ran with it for a bit.  But... it just depends if anybody else thinks it's swell too.  If you find this particularily appealing and would like to use it in some capacity or want certain features, [contact me](#contact)

libswarm
--------
libswarm would be a very natural addition.  Coming soon :)


But I can already run Docker on CoreOS!
---------------------------------------

You ain't never ran containers like this.  The point of stampede and it's underlying framework [cattle.io](http://cattle.io) is to add higher level orchestration typically seen in IaaS to Docker.  For example, networking.  The default networking in stampede actually creates an IPSec based VPN between all your hosts.  Your containers appear to be on the same private network, even if they are across different servers (or clouds).  You can dynamically update links and ports and the orchestration will just make the magic bits fly where they should.

Can I run this on AWS, GCE, [insert cloud here]?
--------------------------------

Yes you can run this wherever you can get CoreOS running.  Obviously if you run KVM on AWS it will be slow because it's not fully virtualized, but still fun to just try out.  All of the container orchestration parts are built to run on AWS, any cloud, or any physical server.

Can you support X?
------------------

Probably, it's really easy to add new features.  Just put in an issue and hopefully I can get around to it.

Why KVM, aren't virtual machines totally lame now?
--------------------------------------------------

There's still plenty of reasons to use VMs, plus I think it's fun.  There's a practical reason also.  The only way to securely run docker multi-tenant is to restrict the capabilities of Docker exposed to the user.  For example, you can't give root access.  So if your going to have a multi-tenant docker environment, there is a good chance that you first carve up your servers with KVM and then run docker I'm the VMs.

Why did you write this when [fill in the blank]Stack already exists?
------------------------------------------------------------------------

The underlying framework, [cattle.io](http://cattle.io) was created as an experiment to specifically try things that weren't easily possible (or maybe just a stupid idea) in the well established IaaS projects.

Running containers on baremetal is the new Orange therefore you don't need a fancy orchestration tool like this.
------------------------------------------



Is this production ready?
-------------------------

No, but one of the goals when I first set out to build this was to create a simple, rock solid orchestration platform.  The underlying framework should be scalable and easily made production worthy, just pending proper testing.  Currently I've only tested running 15,000 containers across 100 servers in 20 minutes.


Contact
=======

IRC: darren0 on freenode

Twitter: @ibuildthecloud

Email: darren at ibuildthecloud.com
