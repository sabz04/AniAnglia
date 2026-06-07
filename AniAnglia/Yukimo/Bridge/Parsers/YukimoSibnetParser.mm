//
//  YukimoSibnetParser.mm
//

#import "YukimoSibnetParser.h"

#include <regex>
#include <string>
#include <unordered_map>
#include <cstdio>

namespace yukimo::parsers {

static constexpr const char* kSibnetOrigin = "https://video.sibnet.ru";

SibnetParser::SibnetParser() {
    _session.enable_redirects(true, 5);
    _session.set_timeout(15);
    _session.set_default_headers({
        "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language: ru-RU,ru;q=0.9,en;q=0.8",
        "Referer: https://video.sibnet.ru/",
    });
}

bool SibnetParser::can_handle(const std::string& url) {
    if (url.empty()) return false;
    return url.find("video.sibnet.ru") != std::string::npos
        || url.find("sibnet.ru/shell") != std::string::npos;
}

/// Make a fully-qualified Sibnet URL out of whatever the JS embedded
/// (relative `/v/...`, protocol-relative `//host/...`, or absolute).
static std::string absolutize(const std::string& path) {
    if (path.empty()) return path;
    if (path.rfind("http://", 0) == 0 || path.rfind("https://", 0) == 0) {
        return path;
    }
    if (path.rfind("//", 0) == 0) {
        return "https:" + path;
    }
    if (path.front() == '/') {
        return std::string(kSibnetOrigin) + path;
    }
    return std::string(kSibnetOrigin) + "/" + path;
}

std::unordered_map<std::string, std::string> SibnetParser::extract_info(const std::string& url) {
    std::unordered_map<std::string, std::string> out;

    std::string html;
    try {
        html = _session.get_request(url);
    } catch (const std::exception& e) {
        fprintf(stderr, "[Yukimo.sibnet] GET failed: %s\n", e.what());
        return out;
    } catch (...) {
        fprintf(stderr, "[Yukimo.sibnet] GET failed (unknown)\n");
        return out;
    }

    if (html.empty()) {
        fprintf(stderr, "[Yukimo.sibnet] empty response\n");
        return out;
    }

    // HLS — `player.src([{src: "/v/<hex>/<id>.m3u8", type: "application/x-mpegURL"}])`
    {
        std::regex re(R"REX([Ss]rc\s*:\s*"((?:/v/|//|https?://)[^"]+\.m3u8[^"]*)")REX");
        std::smatch m;
        if (std::regex_search(html, m, re)) {
            std::string abs = absolutize(m[1].str());
            if (!abs.empty()) {
                out["hls"] = abs;
            }
        }
    }

    // Direct MP4 fallback — older / mobile-fallback pages occasionally
    // ship a flat `.mp4` URL alongside the m3u8.
    {
        std::regex re(R"REX([Ss]rc\s*:\s*"((?:/v/|//|https?://)[^"]+\.mp4[^"]*)")REX");
        std::smatch m;
        if (std::regex_search(html, m, re)) {
            std::string abs = absolutize(m[1].str());
            if (!abs.empty()) {
                // Sibnet doesn't expose quality numbers for MP4 — bucket
                // it under "auto" so it stays distinguishable from `hls`.
                out["auto"] = abs;
            }
        }
    }

    fprintf(stderr, "[Yukimo.sibnet] extracted %zu streams from %zu-byte response\n",
            out.size(), html.size());
    return out;
}

} // namespace yukimo::parsers
