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
        r = requests.get(sys.argv[1])
        r = find_PCX(r.json())

        if r is not None:
            RET["balance"] = (r["Free"] + r["ReservedStaking"]) / 100000000
            RET["balanceTotal"] = RET["balance"]
            RET["balanceLocking"] = r["ReservedStaking"] / 100000000
            RET["balanceUsable"] = r["Free"] / 100000000
            RET["status"] = 0
            RET["account"] = sys.argv[2]
            if RET["balanceLocking"] > 0:
                RET["pledged"] = True
            else:
                RET["pledged"] = False
        else:
            RET = {"status": "1", "error": "account not find"}
    except Exception as e:
        RET = {"status": "1", "error": e}
    finally:
        print(json.dumps(RET))

if __name__ == "__main__":
    main()
