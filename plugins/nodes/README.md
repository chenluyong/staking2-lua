* code: 0是正常，非0为错误
* error: 错误描述
* version: 版本号
* nodes : 节点信息数组
```cpp
{
	"nodes":[
		{
			"alias":"火币矿池",
		    "alias_en":"Huobi Pool",
		    "description":"简介",
		    "description_en":"简介",
		    "statement" : "拉票陈述宣言",
		    "statement_en":"拉票陈述宣言",
		    "location":"中国",
		    "location_en":"China",
		    "pub_key":"1bec3a35842 公钥",
		    "total_vote":2190129506200000, // 总投票数量
		    "node_type":"producer", // 节点类型[生产者/见证者/其它]
		    "voters":132, // 投票总人数
		    "roi":"4.2941",  // 年化回报率
		    "commission_fee": "10.00", // 节点报酬手续费
		    "vote_percent" : "1.2312", // 票数占全网比例
		    "node_type",
		    "ipv4":"52.194.83.44:56656",
		    "rank" : 1, // 排名
	    }
	]
	"version":"1.1.992",
	"code":0,
    "error":"错误描述"
}

```
