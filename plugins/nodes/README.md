* code: 0是正常，非0为错误
* error: 错误描述
* version: 版本号
* nodes : 节点信息数组
```cpp
{
    "nodes":[
        {
            "alias":"中文名称",
            "alias_en":"英文名称",
            "address":"节点地址",
            "logo":"节点logo",
            "description":"中文节点介绍",
            "description_en":"英文节点介绍",
            "staking_count":"质押人数:int",
            "staking_amount":"质押数量:double",
            "fee_rate":"节点收取的手续费:万分比double:1000=10%",
            "roi":"回报率"
        }
    ],
    "version":"版本号",
    "code": 0,
    "error":"错误描述"
}
```
