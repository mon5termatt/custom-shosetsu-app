-- {"id":926040,"ver":"0.1.0","libVer":"1.0.0","author":"you","repo":"https://github.com/mon5termatt/custom-shosetsu-app","dep":["dkjson>=1.0.1"]}

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
	PasswordFilter(SET_API_KEY, "API Key (X-API-Key)")
}

local chapterType = ChapterType.HTML

local function baseURL()
	return settings[SET_BASE_URL]
end

local function apiKey()
	return settings[SET_API_KEY]
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
	-- Prefer dkjson's Shosetsu helpers which decode based on Content-Type.
	-- This avoids returning nil when the server responds with HTML/error pages.
	local ok, res = pcall(function()
		return json.GET(url, headers(), nil)
	end)
	if not ok then
		Log("TasilAPI", "json.GET failed: " .. tostring(res))
		return {}
	end
	if type(res) ~= "table" then
		Log("TasilAPI", "Non-JSON response for url=" .. tostring(url))
		return {}
	end
	return res
end

local listings = {
	Listing("Catalog", false, function()
		local data = getJSON(expandURL("/api/shosetsu/catalog", KEY_NOVEL_URL))
		local books = data and data.books or {}
		return map(books, function(b)
			return Novel {
				title = b.title,
				link = shrinkURL(b.chapters_url, KEY_NOVEL_URL),
				imageURL = b.coverimage
			}
		end)
	end)
}

local function parseNovel(novelURL)
	local url = expandURL(novelURL, KEY_NOVEL_URL)
	local data = getJSON(url)

	return NovelInfo {
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
end

local function getPassage(chapterURL)
	local url = expandURL(chapterURL, KEY_CHAPTER_URL)
	local data = getJSON(url)
	if type(data) ~= "table" then
		return ""
	end
	-- API may return {error=...}
	local html = data.content or ""
	if type(html) ~= "string" or html == "" then
		return ""
	end

	-- Shosetsu's HTML renderer tends to be more consistent when we return a
	-- "page" extracted from a Document instead of a raw HTML string.
	-- Also normalize breaks to improve paragraph separation.
	html = html:gsub("<br%s*/?>%s*<br%s*/?>", "<br/><br/><br/>")
	return pageOfElem(Document(html), true)
end

local function updateSetting(key, value)
	settings[key] = value
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

