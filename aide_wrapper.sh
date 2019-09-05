#!/usr/bin/env python
#Filename: aide_wrapper
#Description: Run AIDE check as root and update database if necessary
#
import os
import subprocess
import sys
import time
from os import path

###### Variables ######
aide = '/usr/sbin/aide'
new_db = '/var/lib/aide/aide.db.new.gz'
prod_db = '/var/lib/aide/aide.db.gz'
replace_db = False
debug = False
success  = 0
failure = 1

###### Helper functions ######
def abort(msg="", rval=failure) :
    print("ERROR: %s" % msg)
    exit(rval)

def dprint(msg=""):
    if debug:
        print("DEBUG: %s" % msg)

def run_cmd(cmd) :
    before = time.time()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    (stdout, stderr) = proc.communicate()
    elapsed = time.time() - before
    dprint("---\nDEBUG: rc=%i, elapse=%.1f, stdout=%s\n---\n" % (proc.returncode, elapsed,stdout))
    return (proc.returncode, stdout, stderr, elapsed)

def init_db():
    cmd = [ aide, "--init" ]
    (rval, init_output, init_errors, init_elapsed) = run_cmd(cmd)
    if rval == 0 :
        cmd = [ "/bin/cp", "-f", new_db, prod_db ]
        (rval, cp_output, cp_errors, cp_elapsed) = run_cmd(cmd)
        if rval == 0:
            print("AIDE ran for %.1f seconds to catalog files" % init_elapsed)
        else:
            if cp_errors is None:
                cp_errors="(unspecified)"
            abort("AIDE file catalog was not installed due to errors %s" % cp_errors)
    else:
        abort("AIDE ran for %.1f seconds to catalog files, but returned errors %s" % (init_elapsed, init_errors))
    

###### Main Script Body ######

dprint("getting started")

if os.getuid() != 0:
    abort("This script requires root privileges to checksum files, please rerun as root")

# Create a database if one didn't already exist
if not path.exists(prod_db):
    dprint("Database doesn't exist; will try to create it")
    init_db()
    # NOTE: There's no value in checking as the reference data was just collected
else:
    dprint("running check")
    cmd = [ aide, "--check" ]
    (rval, diff, errors, elapsed) = run_cmd(cmd)
    if rval == 0 :
        print("AIDE ran for %.1f seconds and reported no changes" % elapsed)
    else:
        if errors is not None:
            abort("AIDE ran for %.1f seconds, but returned errors %s" % (elapsed, errors))
        else:
            print("AIDE ran for %.1f seconds and reported the following changes\n%s" % (elapsed,diff))
            if replace_db:
                init_db()
