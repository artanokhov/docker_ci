# -*- coding: utf-8 -*-
# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
import argparse
import logging
import os
import sys


def load_whitelist(path):
    if not os.path.isfile(path):
        log.warning(f'Whitelist file {path} not found')
        return []
    with open(path) as file:
        return set(map(str.strip, file.readlines()))


def filter_gpl_packages_yum(packages_data, whitelist):
    gpl_packages = []
    for pkg in packages_data:
        if 'GPL' in pkg['license'] and pkg['name'] not in whitelist:
            log.info(f'Found GPl/LGPL package: {pkg["name"]}')
            gpl_packages.append(pkg['name'])
    return gpl_packages


def load_packages_table(path):
    with open(path) as file:
        pkg_licenses = []
        for line in file.readlines():
            data = list(map(str.strip, filter(None, line.split(' '))))
            pkg_licenses.append({'name': data[0], 'version': data[1], 'license': data[2]})
        return pkg_licenses


parser = argparse.ArgumentParser(prog=os.path.basename(__file__),
                                 description='This is GPl/LGPL licenses checker for Linux packages',
                                 add_help=True)

parser.add_argument(
    '-f',
    '--file',
    metavar='PATH',
    required=True,
    help='Packages list to check',
)
parser.add_argument(
    '-w',
    '--whitelist',
    metavar='PATH',
    required=False,
    nargs='+',
    help='File with packages to ignore',
)

parser.add_argument(
    '-l',
    '--logs',
    metavar='PATH',
    required=False,
    default='gpl_packages.txt',
    help='Found GPL packages list',
)

logging.basicConfig(level='INFO')
log = logging.getLogger(__name__)
args = parser.parse_args()

whitelist = set()
for w in args.whitelist or ():
    log.info(f'Loading whitelist file: {w}')
    data = load_whitelist(w)
    log.info(f'{len(data)} packages will be ignored')
    whitelist.update(data)

log.info('Start searching GPl/LGPL licenses in the yum packages ...')
packages = load_packages_table(args.file)
gpl_packages = sorted(filter_gpl_packages_yum(packages, whitelist))

with open(args.logs, 'w') as gpl_licenses_file:
    gpl_licenses_file.write('\n'.join(gpl_packages))
log.info(f'See GPL/LGPL packages in the log: {args.logs}')

if gpl_packages:
    log.info('FAILED')
else:
    log.info('PASSED')

exit_code = 0 if len(gpl_packages) else 1
sys.exit(exit_code)