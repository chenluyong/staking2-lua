local time = "2019-10-10T10:42:04.522Z"

--local strDate = "2019-06-27T19:48:57"
local _, _, y, m, d, _hour, _min, _sec = string.find(time, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)");

local timestamp = os.time({year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec});
print(os.time())
print(timestamp)
print(y);
print(m);
print(d);
print(_hour);
print(_min);
print(_sec);

