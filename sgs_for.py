##!/usr/bin/env python3
# Filename: sgs_for.py
# Description : generate lists of IP ranges for potential Amazon endpoints to
#               to comprise security groups to allow outbound access to them
#
import requests
import sys

#########  Global variables  ###############
aws_record_url = 'https://ip-ranges.amazonaws.com/ip-ranges.json'
max_ranges_per_sg = 60   # Amazon has a published limit of 62
max_tries = 3  # number of time to retry a URL get
default_region = 'us-east-1'
debug = True


######### Functions          ###############
def get_prefixes (url, region):
    tries=0
    data = None
    while (tries < max_tries):
        tries += 1
        r = requests.get(aws_record_url)
        if r is not None and str(r.status_code)[0] == '2':
            data = r.json()
            break
        elif debug:
            print("Request to %s returned %s" % (aws_record_url,r.status_code))

    prefixes = []
    seen = {}
    for record in data['prefixes']:
        if record['region'] == region:
            prefix = record['ip_prefix']
            if prefix not in seen:
                seen[prefix] = True
                prefixes.append(prefix)
    return sorted(prefixes)

def print_prefix_lists(prefixes, max):
    i = 0
    for prefix in sorted(prefixes):
        if i >= max:
            print("\n" + prefix, end='')
            i = 1
        elif i == 0:
            print(prefix, end='')
            i = 1
        else:
            print("," + prefix, end='')
            i += 1


########### Main script body #################
if len(sys.argv) > 1:
    region = sys.argv[1]
else:
    region = default_region

prefixes = get_prefixes(aws_record_url, region)
print_prefix_lists(prefixes,max_ranges_per_sg)
