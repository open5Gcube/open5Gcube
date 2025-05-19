#!scripts/venv/bin/python3

import argparse, logging

import smpplib.gsm
import smpplib.client
import smpplib.consts


def send_message(client, src, dst, string):
    parts, encoding_flag, msg_type_flag = smpplib.gsm.make_parts(string)

    logging.info('Sending SMS "%s" from %s to %s' % (string, src, dst))
    for part in parts:
        pdu = client.send_message(
            source_addr_ton=smpplib.consts.SMPP_TON_INTL,
            source_addr_npi=smpplib.consts.SMPP_NPI_ISDN,
            source_addr=src,
            dest_addr_ton=smpplib.consts.SMPP_TON_INTL,
            dest_addr_npi=smpplib.consts.SMPP_NPI_ISDN,
            destination_addr=dst,
            short_message=part,
            data_coding=encoding_flag,
            #esm_class=msg_type_flag,
            esm_class=smpplib.consts.SMPP_MSGMODE_FORWARD,
            registered_delivery=False,
    )
    logging.debug('pdu.sequence: %d' % pdu.sequence)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--src', required=True)
    parser.add_argument('-d', '--dst', required=True)
    parser.add_argument('-H', '--host', default='osmo-msc')
    parser.add_argument('-p', '--port', type=int, default=2775)
    parser.add_argument('-t', '--text', required=True)
    parser.add_argument('-v', '--verbose', action='store_true')
    return parser.parse_args()


def main():
    args = parse_args()

    logging.basicConfig(level = args.verbose and logging.DEBUG or logging.INFO,
            format = "%(levelname)s %(message)s")

    client = smpplib.client.Client(args.host, args.port)
    client.set_message_sent_handler(
        lambda pdu: logging.info('sent {} {}\n'.format(pdu.sequence, pdu.message_id)))

    client.connect()
    client.bind_transmitter()

    send_message(client, args.src, args.dst, args.text)

    client.unbind()
    client.disconnect()


if __name__ == '__main__':
    main()
