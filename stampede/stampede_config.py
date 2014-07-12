#!/usr/bin/env python

import os
import requests
from cattle import from_env
from coreos_images import create_images

DATA_NAME = 'stampedeConfig'
DATA_VERSION = 1


def first(list):
    if len(list) > 0:
        return list[0]
    return None


def default_cred(client):
    cred = first(client.list_credential(uuid='defaultSshKey'))

    if cred is None:
        cred = client.create_ssh_key(name='Default SSH Key',
                                     uuid='defaultSshKey')

    return cred


def default_network(client):
    networks = client.list_network(uuid='managed-docker0')

    if len(networks) > 0:
        return networks[0]

    return None


def defaults(client):
    admin = first(client.list_account(uuid='admin'))
    if admin is None:
        return

    data = {}
    cred = default_cred(client)
    network = default_network(client)

    if cred is not None:
        print 'Default Credential', cred.id
        data['defaultCredentialIds'] = [cred.id]

    if network is not None:
        print 'Default Network', network.id
        data['defaultNetworkIds'] = [network.id]

    if len(data) > 0:
        client.update(admin, **data)


def get_registration_url(client):
    account = first(client.list_account(uuid='admin'))
    token = first(client.list_registration_token(accountId=account.id,
                                                 state='active'))

    if token is None:
        token = client.wait_success(client.create_registration_token())

    return token.registrationUrl


def registration_url(client):
    url = os.environ.get('REGISTRATION_URL')
    if url is None:
        return

    token_url = get_registration_url(client)
    update = False

    resp = requests.get(url).json()
    try:
        if resp['node']['value'] != token_url:
            update = True
    except KeyError:
        update = True

    if update:
        print 'Setting registration url', token_url
        requests.put(url, data={
            'value': token_url
        })


def setup_data():
    client = from_env()
    registration_url(client)

    data = first(client.list_data(name=DATA_NAME))

    if data is None or data.value != str(DATA_VERSION):
        defaults(client)

        if data is None:
            client.create_data(name=DATA_NAME, value=DATA_VERSION)
        else:
            client.update(data, value=DATA_VERSION)

        print 'Done with data version', DATA_VERSION


def setup():
    create_images()
    setup_data()


if __name__ == '__main__':
    setup()
