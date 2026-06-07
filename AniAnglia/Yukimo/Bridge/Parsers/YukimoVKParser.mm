//
//  YukimoVKParser.mm
//  Parses VK Player embed pages for playable stream URLs.
//
//  How: GET the embed page with iPhone-Safari headers, then scan the
//  returned HTML/JS for `"hls":"…"` (preferred, master playlist that
//  AVPlayer auto-adapts) and `"url<NNN>":"…"` direct MP4s (fallback).
//  All matched URLs are stripped of `\\/` JSON escapes before being
//  returned.
//

#import "YukimoVKParser.h"

#include <regex>
#include <string>
#include <unordered_map>
#include <cstdio>

namespace yukimo::parsers {

VKParser::VKParser() {
    // Talk to VK like a mobile Safari — they sometimes serve a stripped
    // template to unknown UAs that omits the player config block.
    _session.enable_redirects(true, 5);
    _session.set_timeout(15);
    _session.set_default_headers({
        "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language: ru-RU,ru;q=0.9,en;q=0.8",
        "Referer: https://vk.com/",
    });
}

bool VKParser::can_handle(const std::string& url) {
    if (url.empty()) return false;
    return url.find("://vk.com/") != std::string::npos
        || url.find("://m.vk.com/") != std::string::npos
        || url.find("://vk.ru/")  != std::string::npos
        || url.find("video_ext.php") != std::string::npos;
}

// Decode the small set of JSON-style escapes we actually see inside
// `"hls":"…"` / `"urlNNN":"…"` fields. Anything more exotic is left
// untouched — AVPlayer ignores fragments it doesn't understand.
static std::string json_unescape(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        char c = s[i];
        if (c != '\\' || i + 1 >= s.size()) { out += c; continue; }
        char next = s[i + 1];
        switch (next) {
            case '/': out += '/'; i++; break;
            case '\\': out += '\\'; i++; break;
            case '"': out += '"'; i++; break;
            case 'n': out += '\n'; i++; break;
            case 't': out += '\t'; i++; break;
            case 'u': {
                if (i + 5 < s.size()) {
                    std::string hex = s.substr(i + 2, 4);
                    try {
                        int cp = std::stoi(hex, nullptr, 16);
                        if (cp < 0x80) {
                            out += static_cast<char>(cp);
                        } else if (cp < 0x800) {
                            out += static_cast<char>(0xC0 | (cp >> 6));
                            out += static_cast<char>(0x80 | (cp & 0x3F));
                        } else {
                            out += static_cast<char>(0xE0 | (cp >> 12));
                            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
                            out += static_cast<char>(0x80 | (cp & 0x3F));
                        }
                    } catch (...) {}
                    i += 5;
                } else {
                    out += c;
                }
                break;
            }
            default: out += c; break;
        }
    }
    return out;
}

std::unordered_map<std::string, std::string> VKParser::extract_info(const std::string& url) {
    std::unordered_map<std::string, std::string> out;

    std::string html;
    try {
        html = _session.get_request(url);
    } catch (const std::exception& e) {
        fprintf(stderr, "[Yukimo.vk] GET failed: %s\n", e.what());
        return out;
    } catch (...) {
        fprintf(stderr, "[Yukimo.vk] GET failed (unknown)\n");
        return out;
    }

    if (html.empty()) {
        fprintf(stderr, "[Yukimo.vk] empty response\n");
        return out;
    }

    // Preferred: HLS master playlist — AVPlayer adapts quality on its own.
    {
        std::regex re(R"REX("hls"\s*:\s*"(https?:[^"]+)")REX");
        std::smatch m;
        if (std::regex_search(html, m, re)) {
            std::string clean = json_unescape(m[1].str());
            if (!clean.empty()) {
                out["hls"] = clean;
            }
        }
    }

    // Direct MP4 variants (older VK layout) — captured even when HLS is
    // present so the user can still pick a specific quality.
    {
        std::regex re(R"REX("url(\d+)"\s*:\s*"(https?:[^"]+)")REX");
        auto begin = std::sregex_iterator(html.begin(), html.end(), re);
        auto end   = std::sregex_iterator();
        for (auto it = begin; it != end; ++it) {
            std::string quality = (*it)[1].str();
            std::string clean   = json_unescape((*it)[2].str());
            if (!quality.empty() && !clean.empty()) {
                out[quality] = clean;
            }
        }
    }

    // Older `cache<NNN>` layout — VK sometimes serves this on embed pages
    // for users in regions without HLS edge servers. Only used if we got
    // nothing above.
    if (out.empty()) {
        std::regex re(R"REX("cache(\d+)"\s*:\s*"(https?:[^"]+)")REX");
        auto begin = std::sregex_iterator(html.begin(), html.end(), re);
        auto end   = std::sregex_iterator();
        for (auto it = begin; it != end; ++it) {
            std::string quality = (*it)[1].str();
            std::string clean   = json_unescape((*it)[2].str());
            if (!quality.empty() && !clean.empty()) {
                out[quality] = clean;
            }
        }
    }

    fprintf(stderr, "[Yukimo.vk] extracted %zu streams from %zu-byte response\n",
            out.size(), html.size());
    return out;
}

} // namespace yukimo::parsers
