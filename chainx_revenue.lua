
local total_age = 1055203952660000 + 774.6942 * (2776165 - 2775702)
--local total_age = 1691929777302300 + 4036 * (2771047 - 2767828)
--local total_age = 1445659718480000 + 767.3742 * (43200)
print(string.format("total_age %f",total_age))
local user_age = 0 + 100 * (2776165 - 2775702)
--local user_age =  39940402300 + 100 * (2771047 - 2767828)
--local user_age = 277104700 + 100 * (43200)
print(string.format("user_age %f",user_age))
local user_rev = user_age / total_age * 1.59962051
--local user_rev = user_age / total_age * 5.23768299
print(string.format("rev: %f", user_rev))
print(string.format("rev day: %f", user_rev * (60/5) * 24))
print(string.format("rev year: %f", user_rev * (60/5) * 24 * 365))

-- daily PCX total
print(6480 * (674/664629))
