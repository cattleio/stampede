#!/usr/bin/env python

import requests
from collections import OrderedDict
from cattle import from_env

URLS = OrderedDict()
URLS['Stable'] = 'http://stable.release.core-os.net/amd64-usr/'
URLS['Beta'] = 'http://beta.release.core-os.net/amd64-usr/'
URLS['Alpha'] = 'http://alpha.release.core-os.net/amd64-usr/'

DIGEST = 'coreos_production_openstack_image.img.bz2.DIGESTS'
IMG = 'coreos_production_openstack_image.img.bz2'


def get_hash(base, version):
    url = '{0}{1}/{2}'.format(base, version, DIGEST)
    for line in requests.get(url).text.split('\n'):
        parts = line.split('  ')
        if len(parts) == 2 and len(parts[0]) == 40:
            return parts[0], parts[1]

    return None, None


def get_version(base):
    url = base + 'current/version.txt'
    data = {}
    for line in requests.get(url).text.split('\n'):
        parts = line.split('=', 1)
        if len(parts) == 2:
            data[parts[0]] = parts[1]

    version = data.get('COREOS_VERSION_ID')
    hash, file = get_hash(base, version)

    return version, hash, '{0}{1}/{2}'.format(base, version, file)


def save_image(client, name, version, hash, url):
    data = {
        'uuid': 'coreos-{0}-{1}'.format(name.lower(), version),
        'url': url,
        'isPublic': True,
        'checksum': hash,
        'name': 'CoreOS {0} {1}'.format(name, version)
    }

    print 'Registering CoreOS', name, 'Image', version

    images = client.list_image(uuid=data['uuid'])

    if len(images) == 1:
        client.update(images[0], **data)
    else:
        client.create_image(**data)


def create_images():
    client = from_env()

    for name, base in URLS.items():
        version, hash, url = get_version(base)
        if url is not None:
            save_image(client, name, version, hash, url)

if __name__ == '__main__':
    create_images()
