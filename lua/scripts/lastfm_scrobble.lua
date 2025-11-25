local utils = require 'mp.utils'
-- Pure Lua MD5 implementation (based on LuaCrypto)
local function md5_sumhexa(str)
    local bit = require("bit32")
    local band, bor, bxor, bnot, rshift, lshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rshift, bit.lshift

    local function rotate_left(x, n)
        return band(lshift(x, n), 0xFFFFFFFF) + rshift(x, 32 - n)
    end

    local function to_bytes_le(n)
        local b = {}
        for i = 1, 4 do
            b[i] = band(n, 0xFF)
            n = rshift(n, 8)
        end
        return b
    end

    local function from_bytes_le(b, i)
        return b[i] + lshift(b[i + 1], 8) + lshift(b[i + 2], 16) + lshift(b[i + 3], 24)
    end

    local function md5_transform(buf, msg)
        local a, b, c, d = buf[1], buf[2], buf[3], buf[4]
        local s = {7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21}
        local k = {}
        for i = 1, 64 do
            k[i] = math.floor(math.abs(math.sin(i)) * 2^32)
        end
        local f, g
        for i = 0, 63 do
            if i < 16 then
                f = bor(band(b, c), band(bnot(b), d))
                g = i
            elseif i < 32 then
                f = bor(band(d, b), band(bnot(d), c))
                g = (5 * i + 1) % 16
            elseif i < 48 then
                f = bxor(b, bxor(c, d))
                g = (3 * i + 5) % 16
            else
                f = bxor(c, bor(b, bnot(d)))
                g = (7 * i) % 16
            end
            f = f + a + k[i + 1] + from_bytes_le(msg, 4 * g + 1)
            a, d, c, b = d, c, b, band(b + rotate_left(f, s[(i % 4) + 1 + math.floor(i / 16) * 4]), 0xFFFFFFFF)
        end
        buf[1] = band(buf[1] + a, 0xFFFFFFFF)
        buf[2] = band(buf[2] + b, 0xFFFFFFFF)
        buf[3] = band(buf[3] + c, 0xFFFFFFFF)
        buf[4] = band(buf[4] + d, 0xFFFFFFFF)
    end

    local function md5(str)
        local msg = {string.byte(str, 1, #str)}
        local orig_len = #msg
        table.insert(msg, 0x80)
        while (#msg % 64) ~= 56 do table.insert(msg, 0) end
        local bit_len = orig_len * 8
        for i = 1, 8 do
            table.insert(msg, band(bit_len, 0xFF))
            bit_len = rshift(bit_len, 8)
        end
        local buf = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476}
        for i = 1, #msg, 64 do
            local chunk = {}
            for j = i, i + 63 do table.insert(chunk, msg[j] or 0) end
            md5_transform(buf, chunk)
        end
        local result = {}
        for i = 1, 4 do
            for _, byte in ipairs(to_bytes_le(buf[i])) do
                table.insert(result, string.format("%02x", byte))
            end
        end
        return table.concat(result)
    end

    return md5(str)
end

-- 🔧 CONFIG AREA
local api_key = "b84ac71167590b9115ba387fffe29f20"
local api_secret = "6e626ce1ac1e024f048f8a1677b1dfe0"
local session_key = "ozHu8EbYo0MIBpE0ELsLPldcO-zvrPp3"

-- URL-encode function (basic but works)
local function urlencode(str)
    if str == nil then return "" end
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

-- Do the scrobble
local function scrobble(title, artist, album, timestamp)
    local sig_str = "album" .. album .. "api_key" .. api_key .. "artist" .. artist ..
                    "methodtrack.scrobble" ..
                    "sk" .. session_key ..
                    "timestamp" .. timestamp ..
                    "track" .. title ..
                    api_secret

    local api_sig = md5_sumhexa(sig_str)



    local post_data = string.format(
        "method=track.scrobble&track=%s&artist=%s&album=%s&timestamp=%s&api_key=%s&api_sig=%s&sk=%s&format=json",
        urlencode(title), urlencode(artist), urlencode(album),
        timestamp, api_key, api_sig, session_key
    )

    utils.subprocess({
        args = {
            "curl", "-s", "-X", "POST",
            "-d", post_data,
            "https://ws.audioscrobbler.com/2.0/"
        },
        cancellable = false
    })
end

local valid_to_scrobble = false
local scrobble_timer = nil

-- Custom logic: Scrobble only after 40% or 2 minutes (120 sec), whichever is shorter

-- Custom logic: Scrobble only after 40% or 2 minutes (120 sec), whichever is shorter
local function start_scrobble_timer(title, artist, album)
    local duration_str = mp.get_property("duration")

    -- Stream (no duration): scrobble immediately
    if not duration_str then
        print("[lastfm_scrobble] Streaming source: Scrobbling immediately.")
        local timestamp = tostring(os.time())
        scrobble(title, artist or "Unknown Artist", album or "Unknown Album", timestamp)
        return
    end

    local duration = tonumber(duration_str)
    if not duration or duration <= 30 then
        print("[lastfm_scrobble] Skipping scrobble: track too short or invalid duration")
        return
    end

    local delay = math.min(120, duration * 0.4)

    valid_to_scrobble = false

    if scrobble_timer then
        scrobble_timer:kill()
    end

    scrobble_timer = mp.add_timeout(delay, function()
        local timestamp = tostring(os.time())
        scrobble(title, artist or "Unknown Artist", album or "Unknown Album", timestamp)
        valid_to_scrobble = true
        print("[lastfm_scrobble] Scrobbled after delay: " .. artist .. " - " .. title)
    end)
end


    -- Unified stream + YouTube scrobbling
mp.observe_property("metadata", "native", function(name, metadata)
    local title = nil
    local artist = nil
    local album = nil

    if metadata then
        local icy_title = metadata["icy-title"]
        if icy_title then
            -- Try to split: "Artist - Title"
            artist, title = icy_title:match("^(.-)%s+%-%s+(.+)$")
            if not artist or not title then
                artist = "Unknown Artist"
                title = icy_title
            end
    
            -- ✅ Fix: Move this inside icy_title block
            -- Try to detect SomaFM stream name from filename or path
            local path = mp.get_property("path") or ""
            local stream_name = path:match("somafm%.com/([%w%-]+)")
            if stream_name then
                stream_name = stream_name:gsub("-%d+[^/]*", ""):gsub("^%l", string.upper)
                album = "SomaFM: " .. stream_name
            else
                album = "Internet Radio"
            end
        end

        -- Fallback for YouTube via force-media-title
        if not title then
            local yt_title = mp.get_property("force-media-title")
            if yt_title and yt_title ~= "" then
                artist, title = yt_title:match("^(.-)%s+%-%s+(.+)$")
                if not artist or not title then
                    artist = "YouTube"
                    title = yt_title
                end
    
                local path = mp.get_property("path") or ""
                local media_title = mp.get_property("force-media-title") or "YouTube Video"
    
                -- If it's a livestream, tag it as such
                if path:match("live") or media_title:lower():match("live") then
                    album = "YouTube Live: " .. media_title
                else
                    album = "YouTube: " .. media_title
                end
            end
        end
    

            -- Only scrobble if we got at least a title
            if title then
                start_scrobble_timer(title, artist or "Unknown Artist", album or "Unknown Album")
            end            
        end  -- ✅ Closes `if metadata then`
    end)     -- ✅ Closes the whole `mp.observe_property(...)`
    
    -- Fallback for local files
    mp.register_event("file-loaded", function()
        local title = mp.get_property("metadata/by-key/title") or mp.get_property("media-title") or "Unknown Title"
        local artist = mp.get_property("metadata/by-key/artist") or "Unknown Artist"
        local album = mp.get_property("metadata/by-key/album") or "Unknown Album"
    
        start_scrobble_timer(title, artist, album)
    end)
    