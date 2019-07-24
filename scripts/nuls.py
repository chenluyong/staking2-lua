#!/usr/bin/env python3

import requests
import json


class NulsRpc:
    nodeApi = "http://127.0.0.1:12591"
    def getConsensus(self):
        res = self.__get("/api/consensus")
        if (res["success"] == True): return res["data"]
        return None


    def getNodes(self):
        nodes = []
        page = 1
        pageTotal = 2

        while page <= pageTotal:
            res = self.__get("/api/consensus/agent/list?pageNumber=%d&pageSize=100" % page)
            if res["success"] == True:
                page = page + 1
                pageTotal = res["data"]["pages"]
                nodes = nodes + res["data"]["list"]
            else:
                print("ERR: can not request nodes(page: %d)" % page)
                break

        return nodes


    def __get(self, uri, params = None):
        url = self.nodeApi+uri
        res = requests.get(url=url, params=params).text
        return json.loads(res)


class NodesInfo(NulsRpc):
    def getNodesCount(self):
        return self.__CONSENSUS["agentCount"]


    def getTotalDeposit(self):
        res = super().getConsensus()
        return res["totalDeposit"] / 100000000


    def getConsensus(self):
        return super().getConsensus()


    def getNodes(self):
        return super().getNodes()


    @property
    def PLEDGE_LIMIT(self):
        return self.__PLEDGE_LIMIT

    @property
    def ALL_ENTRUST(self):
        return self.__ALL_ENTRUST


    def __init__(self):
        self.__CONSENSUS = self.getConsensus()
        self.__NODESLIST = self.getNodes()
        self.__PLEDGE_LIMIT = 5000000
        self.__ALL_ENTRUST = self.__CONSENSUS["totalDeposit"] / 100000000
        self.__agent_hash = None


class NodesYield(NodesInfo):

    def __init__(self):
        super().__init__()


    def calcYield(self):
        nodes = {}
        for n in self.getNodes():
            if n["creditVal"] == None: print(n)
            userYield = n["creditVal"] * (1 - n["commissionRate"] * 0.01) * self.PLEDGE_LIMIT / self.ALL_ENTRUST
            nodes[n["agentId"]] = {**n, **{"userYield" : round(userYield, 4)}}
        return nodes

def main():
    reward = NodesYield()
    print(json.dumps(reward.calcYield()))


if __name__ == "__main__":
    main()
