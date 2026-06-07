//
//  Yukimo-Bridging-Header.h
//  Yukimo (SwiftUI redesign on top of AniAnglia/libanixart)
//
//  Imports listed here become visible to Swift.
//  Rule: ONLY pure Obj-C facades may live here. Never include
//  C++ headers, C++ namespaces, or Obj-C headers that transitively
//  pull in libanixart C++ types — Swift's clang importer cannot
//  parse them and the whole module breaks.
//

#ifndef Yukimo_Bridging_Header_h
#define Yukimo_Bridging_Header_h

#import "YukimoAuthBridge.h"
#import "YukimoSessionBridge.h"
#import "YukimoSettingsBridge.h"
#import "YukimoReleaseDTO.h"
#import "YukimoProfileDTO.h"
#import "YukimoEpisodeDTO.h"
#import "YukimoListStatus.h"
#import "YukimoHomeBridge.h"
#import "YukimoProfileBridge.h"
#import "YukimoReleaseDetailBridge.h"
#import "YukimoSearchFilter.h"
#import "YukimoSearchBridge.h"
#import "YukimoLibraryBridge.h"
#import "YukimoStreamDTO.h"
#import "YukimoPlayerBridge.h"

#endif /* Yukimo_Bridging_Header_h */
