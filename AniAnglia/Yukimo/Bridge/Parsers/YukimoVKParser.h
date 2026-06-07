//
//  YukimoVKParser.h
//  Standalone HLS/url extractor for VK Player embed pages
//  (`vk.com/video_ext.php?...`). libanixart's `Parsers::extract_info`
//  doesn't currently handle VK — when the user picks a дубляж whose
//  source is Sibnet/AniDUB, the embed comes from VK and the registry
//  returns an empty map. We route VK URLs to this class instead.
//
//  Pure C++ class (header is C++-only, included from .mm bridges).
//

#pragma once

#ifdef __cplusplus

#include <netsess/UrlSession.hpp>
#include <string>
#include <unordered_map>

namespace yukimo::parsers {

class VKParser {
public:
    VKParser();

    /// `true` if the URL targets VK Player and should be routed here
    /// instead of libanixart's parser registry.
    static bool can_handle(const std::string& url);

    /// Returns `{ quality_key -> playable_url }` — same shape as
    /// `anixart::parsers::Parsers::extract_info`. Empty map on failure.
    std::unordered_map<std::string, std::string> extract_info(const std::string& url);

private:
    network::UrlSession _session;
};

} // namespace yukimo::parsers

#endif /* __cplusplus */
