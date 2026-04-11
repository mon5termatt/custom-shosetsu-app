-- {"id":926040,"ver":"0.1.1","libVer":"1.0.0","author":"you","repo":"","dep":["dkjson>=1.0.0"]}

local json = Require("dkjson")

local id = 926040
local name = "Tasil (API)"

-- Settings keys
local SET_BASE_URL = 1
local SET_API_KEY = 2

local settings = {
	[SET_BASE_URL] = "https://tasil.mon5termatt.com",
	[SET_API_KEY] = ""
}

local settingsModel = {
	TextFilter(SET_BASE_URL, "Base URL (e.g. https://tasil.mon5termatt.com)"),
	TextFilter(SET_API_KEY, "API Key (X-API-Key)")
}

local chapterType = ChapterType.HTML

local function baseURL()
	return settings[SET_BASE_URL]
end

local function apiKey()
	local v = settings[SET_API_KEY]
	if v == nil then
		return ""
	end
	local s = tostring(v)
	local trimmed = s:match("^%s*(.-)%s*$")
	return trimmed or s
end

local function headers()
	return HeadersBuilder()
		:add("Accept", "application/json")
		:add("X-API-Key", apiKey())
		:build()
end

local function shrinkURL(url, type)
	return url:gsub("^https?://[^/]+", "")
end

local function expandURL(url, type)
	if url:match("^https?://") then
		return url
	end
	if url:sub(1, 1) ~= "/" then
		url = "/" .. url
	end
	return baseURL() .. url
end

local function getJSON(url)
	local resp = RequestDocument(GET(url, headers(), nil))
	return json.decode(resp:text())
end

local function getListing()
	local data = getJSON(expandURL("/api/shosetsu/catalog", KEY_NOVEL_URL))
	local books = data and data.books or {}
	return map(books, function(b)
		return Novel {
			title = b.title,
			link = shrinkURL(b.chapters_url, KEY_NOVEL_URL),
			imageURL = b.coverimage
		}
	end)
end

local listings = {
	Listing("Catalog", false, function()
		return getListing()
	end)
}

local function parseNovel(novelURL)
	local url = expandURL(novelURL, KEY_NOVEL_URL)
	local data = getJSON(url)

	local novel = NovelInfo {
		title = data.title or "Unknown",
		description = data.description or "",
		imageURL = data.coverimage,
		status = NovelStatus.UNKNOWN,
		chapters = AsList(map(data.chapters or {}, function(c)
			return NovelChapter {
				order = c.number,
				title = "Chapter " .. tostring(c.number),
				link = shrinkURL(c.url, KEY_CHAPTER_URL)
			}
		end))
	}

	return novel
end

local function getPassage(chapterURL)
	local url = expandURL(chapterURL, KEY_CHAPTER_URL)
	local data = getJSON(url)
	return data.content or ""
end

local function normalizeSettingKey(key)
	if type(key) == "number" then
		return key
	end
	if type(key) == "string" then
		local n = tonumber(key)
		if n ~= nil then
			return n
		end
	end
	return key
end

local function updateSetting(key, value)
	settings[normalizeSettingKey(key)] = value
end

return {
	id = id,
	name = name,
	baseURL = baseURL(),
	listings = listings,

	chapterType = chapterType,
	settings = settingsModel,
	updateSetting = updateSetting,

	getPassage = getPassage,
	parseNovel = parseNovel,
	shrinkURL = shrinkURL,
	expandURL = expandURL,

	hasSearch = false,
}

