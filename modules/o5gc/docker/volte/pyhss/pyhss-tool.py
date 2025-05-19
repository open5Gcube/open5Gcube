#!/usr/bin/env python3

# SPDX-License-Identifier: CC0-1.0

"""
Small command-line utility program to talk to the PyHSS REST interface in order
to create and delete subscribers.

Author: Harald Welte <laforge@osmocom.org>.  Licensed under CC0-1.0.

This only covers the most basic use case
where every subscriber is both an EPS and IMS subscriber, has access to both
the "internet" and "ims" APN (no others) and has a single MSISDN.

Example usage:
    pyhss-tool.py subscriber-create --imsi 001011111111111 --msisdn 1111 --k 000102030405060708090a0b0c0d0e0f --opc 00000000000000000000000000000000
    pyhss-tool.py subscriber-delete --imsi 001011111111111

More complex use cases can always use the REST API directly.

You can find PyHSS at https://github.com/nickvsnetworking/pyhss
"""

import requests
import json
import argparse

from typing import Union, Optional, Dict, Tuple


def extract_plmn(imsi: str, mcc_2digits: bool = True) -> Tuple[int, int]:
    mcc = int(imsi[:3])
    if mcc_2digits:
        mnc = int(imsi[3:5])
    else:
        mnc = int(imsi[3:6])
    return mcc, mnc

def build_realm(mcc: Union[int,str], mnc: Union[int,str]) -> str:
    return 'ims.mnc%03d.mcc%03d.3gppnetwork.org' % (int(mnc), int(mcc))

class PyHssApi:
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}

    def __init__(self, base_url:str):
        self.base_url = base_url
        self.apn_internet_id = None
        self.apn_ims_id = None
        self.get_default_apn_ids()

    def perform_api(self, method:str, path:str, inp:Optional[dict] = None) -> dict:
        api_url = self.base_url + path
        response = requests.request(method, api_url, headers=self.headers, json=inp)
        if response.status_code != 200:
            raise ValueError('HTTP Status error: %s: %s' % (str(response), response.content))
        return response.json()

    def perform_api_get(self, path:str) -> dict:
        return self.perform_api('GET', path)

    def perform_api_delete(self, path:str) -> dict:
        return self.perform_api('DELETE', path)

    def perform_api_put(self, path:str, inp:dict) -> dict:
        return self.perform_api('PUT', path, inp)

    def get_apn_id(self, apn:str) -> Optional[int]:
        resp = self.perform_api_get('/apn/list')
        for r in resp:
            if 'apn' in r:
                if r['apn'] == apn:
                    return r['apn_id']
        return None

    def get_default_apn_ids(self):
        if not self.apn_internet_id:
            self.apn_internet_id = self.get_apn_id('internet')
        if not self.apn_ims_id:
            self.apn_ims_id = self.get_apn_id('ims')

    def create_subscriber(self, imsi:str, k:str, opc:str, msisdn:str):
        mcc, mnc = extract_plmn(imsi)
        realm = build_realm(mcc, mnc)

        self.get_default_apn_ids()

        print("Creating AUC record...")
        auc_data = {
            'ki': k,
            'opc': opc,
            'amf': '8000',
            'sqn': 0,
            'imsi': imsi,
        }
        resp = self.perform_api_put('/auc/', auc_data)
        auc_id = resp['auc_id']

        print("Creating EPS subscriber...")
        subscr_data = {
            'imsi': imsi,
            'enabled': True,
            'auc_id': auc_id,
            'default_apn': self.apn_internet_id,
            'apn_list': ",".join([str(self.apn_internet_id), str(self.apn_ims_id)]),
            'msisdn': msisdn,
            'ue_ambr_dl': 0,
            'ue_ambr_ul': 0,
        }
        self.perform_api_put('/subscriber/', subscr_data)

        print("Creating IMS subscriber...")
        ims_subscr_data = {
            'imsi': imsi,
            'msisdn': msisdn,
            'sh_profile': 'string',
            'scscf_peer': 'scscf.%s' % realm,
            'msisdn_list': [msisdn],
            'ifc_path': 'default_ifc.xml',
            'scscf': 'sip:' + 'sip:scscf.%s:6060' % realm,
            'scscf_realm': realm,
        }
        self.perform_api_put('/ims_subscriber/', ims_subscr_data)

    def delete_subscriber(self, imsi:str):
        try:
            resp = self.perform_api_get('/ims_subscriber/ims_subscriber_imsi/%s' % imsi)
        except ValueError:
            pass
        else:
            if resp:
                ims_subscriber_id = resp['ims_subscriber_id']
                print("Deleting IMS subscriber %u (IMSI: %s)" % (ims_subscriber_id, imsi))
                self.perform_api_delete('/ims_subscriber/%u' % ims_subscriber_id)

        resp = self.perform_api_get('/subscriber/imsi/%s' % imsi)
        if resp:
            subscriber_id = resp['subscriber_id']
            print("Deleting EPC subscriber %u (IMSI: %s)" % (subscriber_id, imsi))
            self.perform_api_delete('/subscriber/%s' % subscriber_id)

        resp = self.perform_api_get('/auc/imsi/%s' % imsi)
        if resp:
            auc_id = resp['auc_id']
            print("Deleting AUC record %u (IMSI: %s)" % (auc_id, imsi))
            resp2 = self.perform_api_delete('/auc/%u' % auc_id)


arg_parser = argparse.ArgumentParser(description="""
Small command-line utility program to talk to the PyHSS REST interface in order
to create and delete subscribers.  It only covers the most basic use case
where every subscriber is both an EPS and IMS subscriber, has access to both
the "internet" and "ims" APN (no others) and has a single MSISDN.""")

global_group = arg_parser.add_argument_group('General Options')
global_group.add_argument('-B', '--base-url', help='Base URL of the pyHSS API',
                          default='http://localhost:8080')

subparsers = arg_parser.add_subparsers(dest='operation', required=True)

parser_create = subparsers.add_parser('subscriber-create', help="Create a new subscriber")
parser_create.add_argument('--imsi', help="15-digit IMSI", required=True)
parser_create.add_argument('--msisdn', help="MSISDN (Subsciber Phone Number)", required=True)
parser_create.add_argument('--k', help="Private key 'K' in hex-string format", required=True)
parser_create.add_argument('--opc', help="Private constant 'OPc' in hex-string format", required=True)

parser_delete = subparsers.add_parser('subscriber-delete', help='Delete a subscriber')
parser_delete.add_argument('--imsi', help="15-digit IMSI", required=True)


if __name__ == '__main__':
    opts = arg_parser.parse_args()

    api = PyHssApi(opts.base_url)

    if opts.operation == 'create':
        api.create_subscriber(opts.imsi, opts.k, opts.opc, opts.msisdn)
    elif opts.operation == 'delete':
        api.delete_subscriber(opts.imsi)
