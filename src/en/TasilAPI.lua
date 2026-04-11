-- {"id":926042,"ver":"0.1.11","libVer":"1.0.0","author":"MON5TERMATT","repo":"https://github.com/mon5termatt/custom-shosetsu-app","dep":["dkjson>=1.0.1"]}

local json = Require("dkjson")

local id = 926042
local name = "Matts Ebook Reader (API)"

-- Settings keys
local SET_BASE_URL = 1
local SET_API_KEY = 2

local settings = {
	[SET_BASE_URL] = "https://tasil.mon5termatt.com",
	[SET_API_KEY] = ""
}

-- TextFilter (not PasswordFilter): some Shosetsu builds re-sync password fields as
-- blank on open/background, which calls updateSetting with "" and wipes the stored key.
local settingsModel = {
	TextFilter(SET_BASE_URL, "Base URL (e.g. https://tasil.mon5termatt.com)"),
	TextFilter(SET_API_KEY, "API Key (X-API-Key)")
}

-- Use STRING so Shosetsu's spacing settings apply consistently.
local chapterType = ChapterType.STRING

-- Reserved paths (shrunk URLs) for in-app help when the API key is missing or rejected.
local DUMMY_PREFIX = "/_tasil_ext/"
local DUMMY_README_CHAPTER = DUMMY_PREFIX .. "readme"
-- Extra line for parseNovel / listing (e.g. raw server error code).
local catalog_help_extra = ""
-- Last opened dummy help novel (used for the single "readme" chapter passage).
local last_help_reason = "missing_key"

local function dummyReasonFromNovelURL(novelURL)
	if type(novelURL) ~= "string" then
		return nil
	end
	return novelURL:match("^/_tasil_ext/([%w_]+)$")
end

local function dummyCatalogNovel(title, reasonKey, extra)
	catalog_help_extra = extra or ""
	return Novel {
		title = title,
		link = DUMMY_PREFIX .. reasonKey,
		imageURL = nil,
	}
end

local function helpNovelDescription(reasonKey)
	local base = baseURL()
	local extra = catalog_help_extra
	local extraLine = ""
	if type(extra) == "string" and extra ~= "" then
		extraLine = "\n\nDetail: " .. extra
	end
	if reasonKey == "missing_key" then
		return "No API key is set in this extension.\n\n"
			.. "In Shosetsu: open this source's settings and paste your key into \"API Key (X-API-Key)\". "
			.. "Create one on your site under /admin/api-keys if you need it.\n\n"
			.. "Base URL should be your site root (example: " .. tostring(base) .. ")."
			.. extraLine
	end
	if reasonKey == "missing_api_key" then
		return "The server responded with missing_api_key (no usable X-API-Key).\n\n"
			.. "Open this source's settings, set \"API Key (X-API-Key)\", save, then pull to refresh the catalog."
			.. extraLine
	end
	if reasonKey == "invalid_api_key" then
		return "The server rejected your API key (invalid_api_key).\n\n"
			.. "Generate a new key under /admin/api-keys on your site, update it in Shosetsu, and refresh."
			.. extraLine
	end
	if reasonKey == "fetch_failed" then
		return "The catalog request did not return usable JSON.\n\n"
			.. "Check Base URL (must match your site, including https). Check network and server logs."
			.. extraLine
	end
	if reasonKey == "api_error" then
		return "The catalog endpoint returned an error.\n\n"
			.. "Fix the issue on the server or in extension settings, then refresh."
			.. extraLine
	end
	return "Something went wrong loading the catalog.\n\nRefresh after fixing settings or connectivity." .. extraLine
end

local function helpNovelTitle(reasonKey)
	if reasonKey == "missing_key" then
		return "Tasil: set API key"
	end
	if reasonKey == "missing_api_key" then
		return "Tasil: API key missing"
	end
	if reasonKey == "invalid_api_key" then
		return "Tasil: invalid API key"
	end
	if reasonKey == "fetch_failed" then
		return "Tasil: catalog unreachable"
	end
	if reasonKey == "api_error" then
		return "Tasil: catalog error"
	end
	return "Tasil: help"
end

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
	if apiKey() == "" then
		Log("TasilAPI", "Missing API key in settings")
	end
	local hb = HeadersBuilder()
	hb:add("Accept", "application/json")
	hb:add("X-API-Key", apiKey())
	return hb:build()
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
		local preview = tostring(res)
		if #preview > 180 then preview = preview:sub(1, 180) .. "..." end
		Log("TasilAPI", "Non-JSON response for url=" .. tostring(url) .. " body=" .. preview)
		return {}
	end
	return res
end

local listings = {
	Listing("Catalog", false, function()
		catalog_help_extra = ""
		if apiKey() == "" then
			Log("TasilAPI", "Catalog: empty API key, showing helper entry")
			return {
				dummyCatalogNovel("Tasil — tap here: set API key", "missing_key", ""),
			}
		end
		local data = getJSON(expandURL("/api/shosetsu/catalog", KEY_NOVEL_URL))
		if type(data) ~= "table" then
			Log("TasilAPI", "Catalog: non-table response")
			return {
				dummyCatalogNovel("Tasil — tap here: catalog unreachable", "fetch_failed", tostring(data)),
			}
		end
		if data.error ~= nil then
			local err = tostring(data.error)
			Log("TasilAPI", "Catalog error=" .. err)
			if err == "missing_api_key" then
				return { dummyCatalogNovel("Tasil — tap here: API key missing", "missing_api_key", "") }
			end
			if err == "invalid_api_key" then
				return { dummyCatalogNovel("Tasil — tap here: invalid API key", "invalid_api_key", "") }
			end
			return { dummyCatalogNovel("Tasil — tap here: server error", "api_error", err) }
		end
		local books = (type(data.books) == "table" and data.books) or {}
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
	Log("TasilAPI", "parseNovel v0.1.11 url=" .. tostring(novelURL))
	local reasonKey = dummyReasonFromNovelURL(novelURL)
	if reasonKey ~= nil and reasonKey ~= "readme" then
		last_help_reason = reasonKey
		return NovelInfo {
			title = helpNovelTitle(reasonKey),
			description = helpNovelDescription(reasonKey),
			imageURL = nil,
			status = NovelStatus.UNKNOWN,
			genres = { "Tasil" },
			chapters = AsList({
				NovelChapter {
					order = 1,
					title = "Instructions",
					link = DUMMY_README_CHAPTER,
				},
			}),
		}
	end
	local url = expandURL(novelURL, KEY_NOVEL_URL)
	local data = getJSON(url)

	local chapters_out = {}
	local chapters_in = {}
	if type(data) == "table" and type(data.chapters) == "table" then
		chapters_in = data.chapters
	end

	for _, c in ipairs(chapters_in) do
		if type(c) == "table" then
			local num = c.number or c.chapternum or c.chapter or c.id
			local link = c.url or c.link
			if num ~= nil and type(link) == "string" then
				chapters_out[#chapters_out + 1] = NovelChapter {
					order = num,
					title = "Chapter " .. tostring(num),
					link = shrinkURL(link, KEY_CHAPTER_URL)
				}
			end
		end
	end

	local st = NovelStatus.UNKNOWN
	local raw_status = (type(data) == "table" and data.status) or ""
	if type(raw_status) == "string" then
		local s = raw_status:lower()
		if s == "completed" then
			st = NovelStatus.COMPLETED
		elseif s == "ongoing" then
			st = NovelStatus.PUBLISHING
		end
	end

	local genres = {}
	if type(data) == "table" and type(data.genres) == "table" then
		genres = data.genres
	elseif type(data) == "table" and type(data.category) == "string" then
		genres = { data.category }
	end

	return NovelInfo {
		title = (type(data) == "table" and data.title) or "Unknown",
		description = (type(data) == "table" and data.description) or "",
		imageURL = (type(data) == "table" and data.coverimage) or nil,
		status = st,
		genres = genres,
		chapters = AsList(chapters_out)
	}
end

local function getPassage(chapterURL)
	if type(chapterURL) == "string" and chapterURL == DUMMY_README_CHAPTER then
		return helpNovelDescription(last_help_reason)
	end
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

	-- Convert our simple HTML into readable plain text:
	-- - treat </div><div> boundaries as paragraph breaks
	-- - convert <br> to newlines
	-- - strip remaining tags
	local text = html
	text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	text = text:gsub("<%s*/%s*div%s*>%s*<%s*div%s*>", "\n\n")
	text = text:gsub("<br%s*/?>", "\n")
	text = text:gsub("<[^>]+>", "")

	-- Minimal HTML entity decoding for common entities
	text = text:gsub("&nbsp;", " ")
	text = text:gsub("&amp;", "&")
	text = text:gsub("&lt;", "<")
	text = text:gsub("&gt;", ">")
	text = text:gsub("&quot;", "\"")
	text = text:gsub("&#39;", "'")

	-- Normalize whitespace
	text = text:gsub("[ \t]+\n", "\n")
	text = text:gsub("\n[ \t]+", "\n")
	text = text:gsub("\n\n\n+", "\n\n")
	return text
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
	local k = normalizeSettingKey(key)
	-- Shosetsu may call updateSetting before/after extension reload in an order where
	-- the API key is briefly nil while the value is still saved in app storage; do not
	-- wipe an already-applied key. (Catalog can also run before persisted settings replay.)
	if k == SET_API_KEY then
		-- Host sometimes passes nil while the key is still on disk; do not drop a key
		-- we already received in this Lua session (common right after an extension update).
		if value == nil and apiKey() ~= "" then
			return
		end
		if value == nil then
			settings[k] = ""
			return
		end
		settings[k] = tostring(value)
		return
	end
	settings[k] = value
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

