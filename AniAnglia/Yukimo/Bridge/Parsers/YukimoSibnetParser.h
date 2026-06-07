//
//  YukimoSibnetParser.h
//  Extracts HLS / MP4 URLs from Sibnet's `video.sibnet.ru/shell.php?videoid=…`
//  embed page. libanixart's `Parsers` registry doesn't currently include
//  Sibnet, so when a release's дубляж source is Sibnet (typical for
//  AniDUB) the registry returns 0 streams. We route Sibnet URLs to this
//  class instead.
//
//  Sibnet's player snippet looks like:
//      player.src([{src: "/v/<hex32>/<videoid>.m3u8", type: "application/x-mpegURL"}]);
//  The path is relative — we prefix `https://video.sibnet.ru`. The
//  resolved URL 302-redirects to a tokened CDN edge (dvNN.sibnet.ru);
//  AVPlayer follows redirects automatically.
//

#pragma once

#ifdef __cplusplus

#include <netsess/UrlSession.hpp>
#include <string>
#include <unordered_map>

namespace yukimo::parsers {

class SibnetParser {
public:
    SibnetParser();

    /// `true` if the URL targets Sibnet's embed player.
    static bool can_handle(const std::string& url);

    /// Returns `{ quality_key -> playable_url }`. Single `"hls"` entry
    /// in the common case; multiple `"<height>"` entries if the page
    /// embeds direct MP4 sources too.
    std::unordered_map<std::string, std::string> extract_info(const std::string& url);

private:
    network::UrlSession _session;
};

} // namespace yukimo::parsers

#endif /* __cplusplus */
