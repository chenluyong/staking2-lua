#!/usr/bin/env python3

import sys
import requests
import json

def find_PCX(params):
    for item in params:
        if item["token"] == "PCX":
            return item
    else:
        return None


def main():
    RET = {}
    try:
        r = requests.get(sys.argv[1], headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36'})
        r = find_PCX(r.json())

        if r is not None:
            RET["balance"] = (r["Free"] + r["ReservedStaking"]) / 100000000
            RET["balanceLocking"] = r["ReservedStaking"] / 100000000
            RET["balanceUsable"] = r["Free"] / 100000000
        else:
            RET["balance"] = 0
            RET["balanceLocking"] = 0 
            RET["balanceUsable"] = 0
    except Exception as e:
        RET = {"status": "1", "error": e}
    finally:
        RET["status"] = 0
        RET["balanceTotal"] = RET["balance"]
        RET["account"] = sys.argv[2]
        if RET["balanceLocking"] > 0:
            RET["pledged"] = True
        else:
            RET["pledged"] = False

        print(json.dumps(RET))

if __name__ == "__main__":
    main()
