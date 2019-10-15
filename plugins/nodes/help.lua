
local _M = {}


function _M.main()
return
--local a = 
{
	nodes={
	{ 
   	            alias="币派",
		    alias_en="BEPAL",
		    description="简介",
		    description_en="简介",
		    statement= "拉票陈述宣言",
		    statement_en="拉票陈述宣言",
		    location="中国",
		    location_en="China",
		    pub_key="1bec3a35842 公钥",
		    total_vote=2190129506200000, -- 总投票数量
		    node_type="producer", -- 节点类型[生产者/见证者/其它]
		    voters=132, -- 投票总人数
		    roi="4.2941",  -- 年化回报率
		    commission_fee= "10.00|string|节点报酬手续费",
		    vote_percent = "1.2312|string|票数占全网比例",
		    ipv4="52.194.83.44:56656",
		    rank = 1, --排名
	    }
	},
	version="1.1.992",
	code=0,
    error="错误描述"
}
end

return _M
